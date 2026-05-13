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
	"math/rand"
	"strconv"
	"sync"
	"testing"
	"time"

	pb "quiz-battle/proto"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
)

const (
	matchmakingAddr = "localhost:50051"
	quizAddr        = "localhost:50052"
	scoringAddr     = "localhost:50053"
	authAddr        = "localhost:50054"
	// directConnection=true bypasses replica-set discovery so the test
	// client doesn't try to dial the discovered member name (mongo:27017,
	// the docker-compose service alias) from the CI runner host, where
	// that DNS name doesn't resolve. replicaSet=rs0 keeps transaction
	// support available for any session-scoped reads. Matches the
	// MONGO_URI env the `go` CI job already uses.
	mongoURI = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true"
	dbName   = "quizbattle"

	totalRounds  = 5
	matchTimeout = 30 * time.Second
	eventTimeout = 20 * time.Second // 15s round + buffer
)

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func uniqueID() string {
	// pkg/validate caps usernames at 20 chars and restricts to letters,
	// digits, underscore. Decimal "e2e_<unixMillis>_<rand>" was 22+ chars
	// and tripped the validator. Base36 of the timestamp is ~8 chars and
	// of a 24-bit random int is ~5 chars; with the "e2e" prefix the
	// total lands at ~16, well under the cap, and stays alphanumeric.
	ts := strconv.FormatInt(time.Now().UnixMilli(), 36)
	tail := strconv.FormatInt(int64(rand.Intn(1<<24)), 36)
	return "e2e" + ts + tail
}

// registerUser creates a new user via the auth service and returns token + userId.
func registerUser(t *testing.T, ctx context.Context, authClient pb.AuthServiceClient, username string) (token, userID string) {
	t.Helper()
	resp, err := authClient.Register(ctx, &pb.RegisterRequest{
		Username: username,
		Password: "testpass123",
	})
	if err != nil {
		t.Fatalf("register %s: %v", username, err)
	}
	return resp.Token, resp.UserId
}

// authCtx returns a context with the Bearer token in gRPC metadata.
func authCtx(ctx context.Context, token string) context.Context {
	return metadata.AppendToOutgoingContext(ctx, "authorization", "Bearer "+token)
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

// recvFirstQuestion pulls events from the stream until a
// QuestionBroadcast arrives, skipping past:
//
//   - PlayerJoined: the server emits one per subscriber at round-1
//     subscribe time. Without skipping, round-1 races against the
//     join-notification fanout and flakes.
//   - Leaderboard: scoring runs asynchronously over RabbitMQ, so a
//     "leaderboard.updated" event for round N can land on the stream
//     AFTER round N's RoundResult (the boundary collectUntilRoundEnd
//     stops on). On a fast CI runner the trailing leaderboard event
//     arrives just before round N+1's Question and the assertion
//     fires before it would have on a slower box.
//
// Any other event type (RoundResult, MatchEnd, TimerSync) is a hard
// fail — seeing one of those before the question frame would mean
// something genuinely wrong in the flow, not stream-ordering jitter.
func recvFirstQuestion(t *testing.T, stream pb.QuizService_StreamGameEventsClient, timeout time.Duration) *pb.GameEvent {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			t.Fatalf("timeout (%v) waiting for QuestionBroadcast", timeout)
		}
		ev := recvGameEvent(t, stream, remaining)
		if ev.GetQuestion() != nil {
			return ev
		}
		if ev.GetPlayerJoined() != nil || ev.GetLeaderboard() != nil {
			continue
		}
		t.Fatalf("expected QuestionBroadcast (or trailing PlayerJoined/Leaderboard), got %T", ev.Event)
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
	authConn, err := grpc.NewClient(authAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("dial auth: %v", err)
	}
	defer authConn.Close()

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

	authClient := pb.NewAuthServiceClient(authConn)
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

	// --- Register two test users ---
	p1Name := uniqueID()
	p2Name := uniqueID()
	token1, player1 := registerUser(t, ctx, authClient, p1Name)
	token2, player2 := registerUser(t, ctx, authClient, p2Name)
	t.Logf("Player 1: %s (%s)", p1Name, player1)
	t.Logf("Player 2: %s (%s)", p2Name, player2)

	// Authenticated contexts for each player
	ctx1 := authCtx(ctx, token1)
	ctx2 := authCtx(ctx, token2)

	// =====================================================================
	// CHECKLIST 1: Both join matchmaking → both receive match_found < 30s
	// =====================================================================
	t.Log("--- Checklist 1: Matchmaking ---")

	// Subscribe BEFORE joining so we don't miss the event
	matchStream1, err := matchClient.SubscribeToMatch(ctx1, &pb.SubscribeToMatchRequest{UserId: player1})
	if err != nil {
		t.Fatalf("subscribe player1: %v", err)
	}
	matchStream2, err := matchClient.SubscribeToMatch(ctx2, &pb.SubscribeToMatchRequest{UserId: player2})
	if err != nil {
		t.Fatalf("subscribe player2: %v", err)
	}

	// Join matchmaking
	resp1, err := matchClient.JoinMatchmaking(ctx1, &pb.JoinMatchmakingRequest{UserId: player1, Rating: 1200})
	if err != nil {
		t.Fatalf("join player1: %v", err)
	}
	if resp1.Status != pb.MatchmakingStatus_QUEUED {
		t.Fatalf("player1 expected QUEUED, got %v", resp1.Status)
	}

	resp2, err := matchClient.JoinMatchmaking(ctx2, &pb.JoinMatchmakingRequest{UserId: player2, Rating: 1100})
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
	gameStream1, err := quizClient.StreamGameEvents(ctx1, &pb.StreamGameEventsRequest{
		RoomId: roomID, UserId: player1,
	})
	if err != nil {
		t.Fatalf("stream game events player1: %v", err)
	}
	gameStream2, err := quizClient.StreamGameEvents(ctx2, &pb.StreamGameEventsRequest{
		RoomId: roomID, UserId: player2,
	})
	if err != nil {
		t.Fatalf("stream game events player2: %v", err)
	}

	leaderboardUpdatesReceived := 0

	for round := 1; round <= totalRounds; round++ {
		t.Logf("--- Round %d ---", round)

		// Receive QuestionBroadcast on both streams. recvFirstQuestion
		// skips over the PlayerJoined event the server emits at round-1
		// stream-subscribe time; for round 2+ there's no PlayerJoined
		// queued so it behaves like a plain recv.
		var q1, q2 *pb.GameEvent
		wg.Add(2)
		go func() {
			defer wg.Done()
			q1 = recvFirstQuestion(t, gameStream1, eventTimeout)
		}()
		go func() {
			defer wg.Done()
			q2 = recvFirstQuestion(t, gameStream2, eventTimeout)
		}()
		wg.Wait()

		qb1 := q1.GetQuestion()
		qb2 := q2.GetQuestion()

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
		_, err := quizClient.SubmitAnswer(ctx1, &pb.SubmitAnswerRequest{
			RoomId:          roomID,
			UserId:          player1,
			Round:           int32(round),
			OptionIndex:     0,
			ClientTimestamp: clientTs,
		})
		if err != nil {
			t.Fatalf("round %d: submit player1: %v", round, err)
		}

		_, err = quizClient.SubmitAnswer(ctx2, &pb.SubmitAnswerRequest{
			RoomId:          roomID,
			UserId:          player2,
			Round:           int32(round),
			OptionIndex:     1,
			ClientTimestamp: clientTs + 500, // slightly later
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
	// CHECKLIST 5: MatchEnd received after 5 rounds
	//
	// Drain any trailing Leaderboard events on the way to MatchEnd. Scoring
	// runs asynchronously over RabbitMQ, so leaderboard.updated for the
	// final round commonly arrives after round-5 RoundResult and just
	// before MatchEnd. Same ordering race PR #58 commit 65f5d4e3 patched
	// for recvFirstQuestion, but on the trailing edge of the match.
	// Drained events count toward the aggregate leaderboard check below.
	// =====================================================================
	t.Log("--- Checklist 5: MatchEnd ---")

	recvMatchEndDrainingLB := func(stream pb.QuizService_StreamGameEventsClient) (*pb.GameEvent, int) {
		drainedLB := 0
		for {
			ev := recvGameEvent(t, stream, eventTimeout)
			if ev.GetMatchEnd() != nil {
				return ev, drainedLB
			}
			if ev.GetLeaderboard() != nil {
				drainedLB++
				continue
			}
			t.Fatalf("expected MatchEnd (or trailing Leaderboard), got %T", ev.Event)
			return nil, drainedLB
		}
	}

	var end1, end2 *pb.GameEvent
	var drained1, drained2 int
	wg.Add(2)
	go func() {
		defer wg.Done()
		end1, drained1 = recvMatchEndDrainingLB(gameStream1)
	}()
	go func() {
		defer wg.Done()
		end2, drained2 = recvMatchEndDrainingLB(gameStream2)
	}()
	wg.Wait()
	leaderboardUpdatesReceived += drained1 + drained2

	// =====================================================================
	// CHECKLIST 3 (aggregate): LeaderboardUpdate broadcast check
	// Verified after MatchEnd drain so trailing events for the final round
	// — which are otherwise impossible to observe in the round loop — also
	// count.
	// =====================================================================
	if leaderboardUpdatesReceived > 0 {
		t.Logf("PASS: Received %d total LeaderboardUpdate events", leaderboardUpdatesReceived)
	} else {
		t.Error("FAIL: No LeaderboardUpdate events received — quiz service likely missing leaderboard.updated RabbitMQ consumer")
	}

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
	lbResp, err := scoreClient.GetLeaderboard(ctx1, &pb.GetLeaderboardRequest{RoomId: roomID})
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

	authConn2, err := grpc.NewClient(authAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("dial auth: %v", err)
	}
	defer authConn2.Close()

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

	authClient := pb.NewAuthServiceClient(authConn2)
	matchClient := pb.NewMatchmakingServiceClient(matchConn)
	quizClient := pb.NewQuizServiceClient(quizConn)

	// Register test users
	p1Name := uniqueID()
	p2Name := uniqueID()
	token1, player1 := registerUser(t, ctx, authClient, p1Name)
	token2, player2 := registerUser(t, ctx, authClient, p2Name)
	ctx1 := authCtx(ctx, token1)
	ctx2 := authCtx(ctx, token2)
	t.Logf("Players: %s, %s", p1Name, p2Name)

	// Match both players
	ms1, _ := matchClient.SubscribeToMatch(ctx1, &pb.SubscribeToMatchRequest{UserId: player1})
	ms2, _ := matchClient.SubscribeToMatch(ctx2, &pb.SubscribeToMatchRequest{UserId: player2})
	matchClient.JoinMatchmaking(ctx1, &pb.JoinMatchmakingRequest{UserId: player1, Rating: 1000})
	matchClient.JoinMatchmaking(ctx2, &pb.JoinMatchmakingRequest{UserId: player2, Rating: 1000})

	me1 := recvMatchEvent(t, ms1, matchTimeout)
	recvMatchEvent(t, ms2, matchTimeout)
	roomID := me1.RoomId
	t.Logf("Matched in room %s", roomID)

	// Player1 opens game stream
	gameCtx1, gameCancel1 := context.WithCancel(authCtx(ctx, token1))
	gs1, err := quizClient.StreamGameEvents(gameCtx1, &pb.StreamGameEventsRequest{
		RoomId: roomID, UserId: player1,
	})
	if err != nil {
		t.Fatalf("stream player1: %v", err)
	}

	// Player2 opens game stream (stays connected throughout)
	gs2, err := quizClient.StreamGameEvents(ctx2, &pb.StreamGameEventsRequest{
		RoomId: roomID, UserId: player2,
	})
	if err != nil {
		t.Fatalf("stream player2: %v", err)
	}

	// Wait for round 1 QuestionBroadcast on both streams. Same race
	// guard as TestFullMatchE2E — skip past the PlayerJoined fanout.
	q1 := recvFirstQuestion(t, gs1, eventTimeout)
	recvFirstQuestion(t, gs2, eventTimeout)
	lastSeq := q1.SequenceNumber
	t.Logf("Round 1 started, sequence_number=%d", lastSeq)

	// Simulate disconnect: cancel player1's stream context
	gameCancel1()
	t.Log("Player1 stream cancelled (simulating disconnect)")

	// Wait briefly then reconnect with last known sequence_number
	time.Sleep(1 * time.Second)

	gs1Reconnected, err := quizClient.StreamGameEvents(authCtx(ctx, token1), &pb.StreamGameEventsRequest{
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
