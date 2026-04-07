//go:build integration

// Section 9.9 — Integration & End-to-End Test
//
// Requires all three Go services running on localhost:50051/50052/50053,
// plus Redis, RabbitMQ, and MongoDB (seeded with questions).
//
// Run: go test -tags integration -v -timeout 3m ./test/e2e/

package e2e

import (
	"context"
	"fmt"
	"math/rand"
	"sync"
	"testing"
	"time"

	pb "quiz-battle/proto"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

const (
	matchmakingAddr = "localhost:50051"
	quizAddr        = "localhost:50052"
	scoringAddr     = "localhost:50053"
	mongoURI        = "mongodb://localhost:27017"
	dbName          = "quizbattle"

	totalRounds  = 5
	matchTimeout = 30 * time.Second
	eventTimeout = 20 * time.Second // 15s round + buffer
)

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func uniqueID() string {
	return fmt.Sprintf("e2e-%d-%d", time.Now().UnixMilli(), rand.Intn(100000))
}

// recvGameEvent reads the next GameEvent with a timeout.
func recvGameEvent(t *testing.T, stream pb.QuizService_StreamGameEventsClient, timeout time.Duration) *pb.GameEvent {
	t.Helper()
	type result struct {
		ev  *pb.GameEvent
		err error
	}
	ch := make(chan result, 1)
	go func() {
		ev, err := stream.Recv()
		ch <- result{ev, err}
	}()
	select {
	case r := <-ch:
		if r.err != nil {
			t.Fatalf("game stream recv error: %v", r.err)
		}
		return r.ev
	case <-time.After(timeout):
		t.Fatalf("timeout (%v) waiting for game event", timeout)
		return nil
	}
}

// recvMatchEvent reads the next MatchEvent with a timeout.
func recvMatchEvent(t *testing.T, stream pb.MatchmakingService_SubscribeToMatchClient, timeout time.Duration) *pb.MatchEvent {
	t.Helper()
	type result struct {
		ev  *pb.MatchEvent
		err error
	}
	ch := make(chan result, 1)
	go func() {
		ev, err := stream.Recv()
		ch <- result{ev, err}
	}()
	select {
	case r := <-ch:
		if r.err != nil {
			t.Fatalf("match stream recv error: %v", r.err)
		}
		return r.ev
	case <-time.After(timeout):
		t.Fatalf("timeout (%v) waiting for match event", timeout)
		return nil
	}
}

// collectRoundEvents reads game events until it sees a RoundResult or MatchEnd.
// Returns all events collected (including the terminal one).
type roundEvents struct {
	questions    []*pb.QuestionBroadcast
	leaderboard  []*pb.LeaderboardUpdate
	roundResults []*pb.RoundResult
	matchEnd     *pb.MatchEnd
}

func collectUntilRoundEnd(t *testing.T, stream pb.QuizService_StreamGameEventsClient, timeout time.Duration) roundEvents {
	t.Helper()
	var collected roundEvents
	deadline := time.After(timeout)
	for {
		type result struct {
			ev  *pb.GameEvent
			err error
		}
		ch := make(chan result, 1)
		go func() {
			ev, err := stream.Recv()
			ch <- result{ev, err}
		}()

		select {
		case r := <-ch:
			if r.err != nil {
				t.Fatalf("stream error while collecting: %v", r.err)
			}
			switch r.ev.Event.(type) {
			case *pb.GameEvent_Question:
				collected.questions = append(collected.questions, r.ev.GetQuestion())
			case *pb.GameEvent_Leaderboard:
				collected.leaderboard = append(collected.leaderboard, r.ev.GetLeaderboard())
			case *pb.GameEvent_RoundResult:
				collected.roundResults = append(collected.roundResults, r.ev.GetRoundResult())
				return collected
			case *pb.GameEvent_MatchEnd:
				collected.matchEnd = r.ev.GetMatchEnd()
				return collected
			}
		case <-deadline:
			t.Fatalf("timeout collecting round events (got %d questions, %d leaderboard, %d results)",
				len(collected.questions), len(collected.leaderboard), len(collected.roundResults))
			return collected
		}
	}
}

// ---------------------------------------------------------------------------
// Main E2E test — Checklist items 1–6
// ---------------------------------------------------------------------------

func TestFullMatchE2E(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	// --- Connect to gRPC services ---
	matchConn, err := grpc.NewClient(matchmakingAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("dial matchmaking: %v", err)
	}
	defer matchConn.Close()

	quizConn, err := grpc.NewClient(quizAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("dial quiz: %v", err)
	}
	defer quizConn.Close()

	scoreConn, err := grpc.NewClient(scoringAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("dial scoring: %v", err)
	}
	defer scoreConn.Close()

	matchClient := pb.NewMatchmakingServiceClient(matchConn)
	quizClient := pb.NewQuizServiceClient(quizConn)
	scoreClient := pb.NewScoringServiceClient(scoreConn)

	// --- Connect to MongoDB for verification ---
	mongoClient, err := mongo.Connect(options.Client().ApplyURI(mongoURI))
	if err != nil {
		t.Fatalf("mongo connect: %v", err)
	}
	defer mongoClient.Disconnect(ctx)
	db := mongoClient.Database(dbName)

	player1 := uniqueID()
	player2 := uniqueID()
	t.Logf("Player 1: %s", player1)
	t.Logf("Player 2: %s", player2)

	// =====================================================================
	// CHECKLIST 1: Both join matchmaking → both receive match_found < 30s
	// =====================================================================
	t.Log("--- Checklist 1: Matchmaking ---")

	// Subscribe BEFORE joining so we don't miss the event
	matchStream1, err := matchClient.SubscribeToMatch(ctx, &pb.SubscribeToMatchRequest{UserId: player1})
	if err != nil {
		t.Fatalf("subscribe player1: %v", err)
	}
	matchStream2, err := matchClient.SubscribeToMatch(ctx, &pb.SubscribeToMatchRequest{UserId: player2})
	if err != nil {
		t.Fatalf("subscribe player2: %v", err)
	}

	// Join matchmaking
	resp1, err := matchClient.JoinMatchmaking(ctx, &pb.JoinMatchmakingRequest{UserId: player1, Rating: 1200})
	if err != nil {
		t.Fatalf("join player1: %v", err)
	}
	if resp1.Status != pb.MatchmakingStatus_QUEUED {
		t.Fatalf("player1 expected QUEUED, got %v", resp1.Status)
	}

	resp2, err := matchClient.JoinMatchmaking(ctx, &pb.JoinMatchmakingRequest{UserId: player2, Rating: 1100})
	if err != nil {
		t.Fatalf("join player2: %v", err)
	}
	if resp2.Status != pb.MatchmakingStatus_QUEUED {
		t.Fatalf("player2 expected QUEUED, got %v", resp2.Status)
	}

	// Wait for match_found on both streams
	matchStart := time.Now()
	var roomID string
	var wg sync.WaitGroup
	var me1, me2 *pb.MatchEvent
	wg.Add(2)
	go func() {
		defer wg.Done()
		me1 = recvMatchEvent(t, matchStream1, matchTimeout)
	}()
	go func() {
		defer wg.Done()
		me2 = recvMatchEvent(t, matchStream2, matchTimeout)
	}()
	wg.Wait()
	matchDuration := time.Since(matchStart)

	roomID = me1.RoomId
	if roomID == "" {
		t.Fatal("player1 got empty room_id")
	}
	if me2.RoomId != roomID {
		t.Fatalf("room_id mismatch: player1=%s player2=%s", roomID, me2.RoomId)
	}
	if matchDuration > matchTimeout {
		t.Fatalf("match took %v, exceeds 30s limit", matchDuration)
	}
	t.Logf("PASS: Both matched to room %s in %v", roomID, matchDuration.Round(time.Millisecond))

	// =====================================================================
	// CHECKLIST 2–5: Play 5 rounds
	// =====================================================================

	// Open game event streams
	gameStream1, err := quizClient.StreamGameEvents(ctx, &pb.StreamGameEventsRequest{
		RoomId: roomID, UserId: player1,
	})
	if err != nil {
		t.Fatalf("stream game events player1: %v", err)
	}
	gameStream2, err := quizClient.StreamGameEvents(ctx, &pb.StreamGameEventsRequest{
		RoomId: roomID, UserId: player2,
	})
	if err != nil {
		t.Fatalf("stream game events player2: %v", err)
	}

	leaderboardUpdatesReceived := 0

	for round := 1; round <= totalRounds; round++ {
		t.Logf("--- Round %d ---", round)

		// Receive QuestionBroadcast on both streams
		var q1, q2 *pb.GameEvent
		wg.Add(2)
		go func() {
			defer wg.Done()
			q1 = recvGameEvent(t, gameStream1, eventTimeout)
		}()
		go func() {
			defer wg.Done()
			q2 = recvGameEvent(t, gameStream2, eventTimeout)
		}()
		wg.Wait()

		qb1 := q1.GetQuestion()
		qb2 := q2.GetQuestion()
		if qb1 == nil {
			t.Fatalf("round %d: player1 expected QuestionBroadcast, got %T", round, q1.Event)
		}
		if qb2 == nil {
			t.Fatalf("round %d: player2 expected QuestionBroadcast, got %T", round, q2.Event)
		}

		// CHECKLIST 2: Identical deadline timestamp, absolute Unix time
		if qb1.DeadlineUnix != qb2.DeadlineUnix {
			t.Errorf("round %d: deadline mismatch: p1=%d p2=%d", round, qb1.DeadlineUnix, qb2.DeadlineUnix)
		}
		now := time.Now().Unix()
		if qb1.DeadlineUnix < now || qb1.DeadlineUnix > now+20 {
			t.Errorf("round %d: deadline %d not an absolute Unix timestamp near now (%d)", round, qb1.DeadlineUnix, now)
		}
		if qb1.Round != int32(round) {
			t.Errorf("round %d: expected round=%d in event, got %d", round, round, qb1.Round)
		}
		if len(qb1.Options) != 4 {
			t.Errorf("round %d: expected 4 options, got %d", round, len(qb1.Options))
		}
		t.Logf("PASS: Round %d QuestionBroadcast — deadline=%d, question=%q", round, qb1.DeadlineUnix, qb1.Text[:min(40, len(qb1.Text))])

		// Both players submit answers
		clientTs := time.Now().UnixMilli()
		_, err := quizClient.SubmitAnswer(ctx, &pb.SubmitAnswerRequest{
			RoomId:          roomID,
			UserId:          player1,
			Round:           int32(round),
			OptionIndex:     0,
			ClientTimestamp:  clientTs,
		})
		if err != nil {
			t.Fatalf("round %d: submit player1: %v", round, err)
		}

		_, err = quizClient.SubmitAnswer(ctx, &pb.SubmitAnswerRequest{
			RoomId:          roomID,
			UserId:          player2,
			Round:           int32(round),
			OptionIndex:     1,
			ClientTimestamp:  clientTs + 500, // slightly later
		})
		if err != nil {
			t.Fatalf("round %d: submit player2: %v", round, err)
		}

		// Collect events until RoundResult (may include LeaderboardUpdates)
		var re1, re2 roundEvents
		wg.Add(2)
		go func() {
			defer wg.Done()
			re1 = collectUntilRoundEnd(t, gameStream1, eventTimeout)
		}()
		go func() {
			defer wg.Done()
			re2 = collectUntilRoundEnd(t, gameStream2, eventTimeout)
		}()
		wg.Wait()

		// CHECKLIST 3: Track leaderboard updates
		leaderboardUpdatesReceived += len(re1.leaderboard)
		if len(re1.leaderboard) > 0 {
			t.Logf("  Received %d LeaderboardUpdate(s) on player1 stream", len(re1.leaderboard))
		}

		// CHECKLIST 4: RoundResult received with valid correct_index
		if len(re1.roundResults) == 0 {
			t.Fatalf("round %d: player1 never received RoundResult", round)
		}
		if len(re2.roundResults) == 0 {
			t.Fatalf("round %d: player2 never received RoundResult", round)
		}
		rr1 := re1.roundResults[0]
		rr2 := re2.roundResults[0]
		if rr1.Round != int32(round) {
			t.Errorf("round %d: RoundResult.round=%d for player1", round, rr1.Round)
		}
		if rr1.CorrectIndex != rr2.CorrectIndex {
			t.Errorf("round %d: correct_index mismatch: p1=%d p2=%d", round, rr1.CorrectIndex, rr2.CorrectIndex)
		}
		if rr1.CorrectIndex < 0 || rr1.CorrectIndex > 3 {
			t.Errorf("round %d: correct_index %d out of range [0,3]", round, rr1.CorrectIndex)
		}
		t.Logf("PASS: Round %d RoundResult — correct_index=%d", round, rr1.CorrectIndex)
	}

	// =====================================================================
	// CHECKLIST 3 (aggregate): LeaderboardUpdate broadcast check
	// =====================================================================
	if leaderboardUpdatesReceived > 0 {
		t.Logf("PASS: Received %d total LeaderboardUpdate events across all rounds", leaderboardUpdatesReceived)
	} else {
		t.Error("FAIL: No LeaderboardUpdate events received — quiz service likely missing leaderboard.updated RabbitMQ consumer")
	}

	// =====================================================================
	// CHECKLIST 5: MatchEnd received after 5 rounds
	// =====================================================================
	t.Log("--- Checklist 5: MatchEnd ---")

	var end1, end2 *pb.GameEvent
	wg.Add(2)
	go func() {
		defer wg.Done()
		end1 = recvGameEvent(t, gameStream1, eventTimeout)
	}()
	go func() {
		defer wg.Done()
		end2 = recvGameEvent(t, gameStream2, eventTimeout)
	}()
	wg.Wait()

	me1End := end1.GetMatchEnd()
	me2End := end2.GetMatchEnd()
	if me1End == nil {
		t.Fatalf("player1 expected MatchEnd, got %T", end1.Event)
	}
	if me2End == nil {
		t.Fatalf("player2 expected MatchEnd, got %T", end2.Event)
	}

	if me1End.RoomId != roomID {
		t.Errorf("MatchEnd room_id mismatch: expected %s got %s", roomID, me1End.RoomId)
	}
	if me1End.Winner == "" {
		t.Error("MatchEnd.winner is empty")
	}
	if len(me1End.Players) < 2 {
		t.Errorf("MatchEnd has %d players, expected >= 2", len(me1End.Players))
	}
	if me1End.Rounds != int32(totalRounds) {
		t.Errorf("MatchEnd.rounds=%d, expected %d", me1End.Rounds, totalRounds)
	}

	// Verify both players are in the results
	playerFound := map[string]bool{}
	for _, p := range me1End.Players {
		playerFound[p.UserId] = true
		t.Logf("  %s — score=%.0f rank=%d correct=%d avgMs=%.0f",
			p.UserId, p.FinalScore, p.Rank, p.AnswersCorrect, p.AvgResponseTimeMs)
	}
	if !playerFound[player1] || !playerFound[player2] {
		t.Errorf("MatchEnd missing player(s): p1=%v p2=%v", playerFound[player1], playerFound[player2])
	}

	t.Logf("PASS: MatchEnd received — winner=%s, rounds=%d", me1End.Winner, me1End.Rounds)

	// =====================================================================
	// CHECKLIST 6: match_history visible in MongoDB
	// =====================================================================
	t.Log("--- Checklist 6: MongoDB persistence ---")

	// Give persistence worker time to process
	time.Sleep(3 * time.Second)

	// Verify match_history document
	var matchDoc bson.M
	err = db.Collection("match_history").FindOne(ctx, bson.M{"roomId": roomID}).Decode(&matchDoc)
	if err != nil {
		t.Fatalf("match_history not found for room %s: %v", roomID, err)
	}

	players, ok := matchDoc["players"].(bson.A)
	if !ok || len(players) < 2 {
		t.Errorf("match_history.players missing or < 2 entries")
	} else {
		t.Logf("  match_history has %d players", len(players))
		for _, p := range players {
			if pm, ok := p.(bson.M); ok {
				t.Logf("    %v — score=%v rank=%v", pm["userId"], pm["finalScore"], pm["rank"])
			}
		}
	}

	if matchDoc["winner"] == nil || matchDoc["winner"] == "" {
		t.Error("match_history.winner is empty")
	}

	t.Logf("PASS: match_history persisted for room %s", roomID)

	// Verify user stats updated
	for _, pid := range []string{player1, player2} {
		var userDoc bson.M
		err := db.Collection("users").FindOne(ctx, bson.M{"_id": pid}).Decode(&userDoc)
		if err != nil {
			t.Errorf("users doc not found for %s: %v", pid, err)
			continue
		}
		mp, _ := userDoc["matchesPlayed"].(int32)
		if mp < 1 {
			t.Errorf("user %s matchesPlayed=%d, expected >= 1", pid, mp)
		}
	}
	t.Log("PASS: User stats updated in MongoDB")

	// =====================================================================
	// Verify GetLeaderboard gRPC (supplementary)
	// =====================================================================
	lbResp, err := scoreClient.GetLeaderboard(ctx, &pb.GetLeaderboardRequest{RoomId: roomID})
	if err != nil {
		t.Logf("WARN: GetLeaderboard returned error (room may have expired): %v", err)
	} else if len(lbResp.Entries) < 2 {
		t.Errorf("GetLeaderboard returned %d entries, expected >= 2", len(lbResp.Entries))
	} else {
		t.Logf("PASS: GetLeaderboard returned %d entries", len(lbResp.Entries))
	}
}

// ---------------------------------------------------------------------------
// CHECKLIST 7: Disconnect & reconnect test
// ---------------------------------------------------------------------------

func TestDisconnectReconnect(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	matchConn, err := grpc.NewClient(matchmakingAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("dial matchmaking: %v", err)
	}
	defer matchConn.Close()

	quizConn, err := grpc.NewClient(quizAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("dial quiz: %v", err)
	}
	defer quizConn.Close()

	matchClient := pb.NewMatchmakingServiceClient(matchConn)
	quizClient := pb.NewQuizServiceClient(quizConn)

	player1 := uniqueID()
	player2 := uniqueID()
	t.Logf("Players: %s, %s", player1, player2)

	// Match both players
	ms1, _ := matchClient.SubscribeToMatch(ctx, &pb.SubscribeToMatchRequest{UserId: player1})
	ms2, _ := matchClient.SubscribeToMatch(ctx, &pb.SubscribeToMatchRequest{UserId: player2})
	matchClient.JoinMatchmaking(ctx, &pb.JoinMatchmakingRequest{UserId: player1, Rating: 1000})
	matchClient.JoinMatchmaking(ctx, &pb.JoinMatchmakingRequest{UserId: player2, Rating: 1000})

	me1 := recvMatchEvent(t, ms1, matchTimeout)
	recvMatchEvent(t, ms2, matchTimeout)
	roomID := me1.RoomId
	t.Logf("Matched in room %s", roomID)

	// Player1 opens game stream
	gameCtx1, gameCancel1 := context.WithCancel(ctx)
	gs1, err := quizClient.StreamGameEvents(gameCtx1, &pb.StreamGameEventsRequest{
		RoomId: roomID, UserId: player1,
	})
	if err != nil {
		t.Fatalf("stream player1: %v", err)
	}

	// Player2 opens game stream (stays connected throughout)
	gs2, err := quizClient.StreamGameEvents(ctx, &pb.StreamGameEventsRequest{
		RoomId: roomID, UserId: player2,
	})
	if err != nil {
		t.Fatalf("stream player2: %v", err)
	}

	// Wait for round 1 QuestionBroadcast
	q1 := recvGameEvent(t, gs1, eventTimeout)
	recvGameEvent(t, gs2, eventTimeout)
	if q1.GetQuestion() == nil {
		t.Fatalf("expected QuestionBroadcast, got %T", q1.Event)
	}
	lastSeq := q1.SequenceNumber
	t.Logf("Round 1 started, sequence_number=%d", lastSeq)

	// Simulate disconnect: cancel player1's stream context
	gameCancel1()
	t.Log("Player1 stream cancelled (simulating disconnect)")

	// Wait briefly then reconnect with last known sequence_number
	time.Sleep(1 * time.Second)

	gs1Reconnected, err := quizClient.StreamGameEvents(ctx, &pb.StreamGameEventsRequest{
		RoomId:         roomID,
		UserId:         player1,
		SequenceNumber: lastSeq,
	})
	if err != nil {
		t.Fatalf("reconnect player1: %v", err)
	}
	t.Log("Player1 reconnected with sequence_number")

	// Verify player1 continues to receive events after reconnect
	ev := recvGameEvent(t, gs1Reconnected, eventTimeout)
	if ev == nil {
		t.Fatal("player1 received no events after reconnect")
	}
	t.Logf("PASS: Player1 received event after reconnect: %T (seq=%d)", ev.Event, ev.SequenceNumber)

	// Verify player2 is still receiving events (stream not disrupted)
	ev2 := recvGameEvent(t, gs2, eventTimeout)
	if ev2 == nil {
		t.Fatal("player2 stream disrupted during player1 disconnect")
	}
	t.Logf("PASS: Player2 stream unaffected during player1 disconnect: %T (seq=%d)", ev2.Event, ev2.SequenceNumber)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
