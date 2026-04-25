package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net"
	"os"
	"sync"
	"sync/atomic"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/models"
	pb "quiz-battle/proto"
)

// ---------------------------------------------------------------------------
// Question document (matches MongoDB schema from section 3.1)
// ---------------------------------------------------------------------------

type Question struct {
	ID                string   `bson:"_id,omitempty"`
	Text              string   `bson:"text"`
	Options           []string `bson:"options"`
	CorrectIndex      int      `bson:"correctIndex"`
	Difficulty        string   `bson:"difficulty"`
	Topic             string   `bson:"topic"`
	AvgResponseTimeMs int      `bson:"avgResponseTimeMs"`
}

// ---------------------------------------------------------------------------
// Server struct
// ---------------------------------------------------------------------------

type quizServer struct {
	pb.UnimplementedQuizServiceServer
	rdb           *redis.Client
	amqpConn      *amqp.Connection
	amqpCh        *amqp.Channel // for publishing only
	amqpMu        sync.Mutex    // AMQP channels are not thread-safe
	mongoDB       *mongo.Database
	jwtSecret     string
	gameStreams   sync.Map // "roomId:userId" -> chan *pb.GameEvent
	roomTimers    sync.Map // roomId -> *time.Timer (for round close)
	seqCounters   sync.Map // roomId -> *atomic.Int64
	roomDeadlines sync.Map // roomId -> int64 (current round deadline_unix)
	roomQuestions sync.Map // roomId -> []Question
}

// publish sends a message to the topic exchange with mutex protection.
func (s *quizServer) publish(ctx context.Context, routingKey string, body []byte) error {
	s.amqpMu.Lock()
	defer s.amqpMu.Unlock()
	return s.amqpCh.PublishWithContext(ctx, "sx", routingKey, false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        body,
	})
}

// newChannel creates a dedicated AMQP channel per consumer (channels are not thread-safe).
func (s *quizServer) newChannel() (*amqp.Channel, error) {
	return s.amqpConn.Channel()
}

func (s *quizServer) getSeqCounter(roomID string) *atomic.Int64 {
	val, _ := s.seqCounters.LoadOrStore(roomID, &atomic.Int64{})
	return val.(*atomic.Int64)
}

// freeTopics is the subset of question topics available to free-tier users.
// Premium users get all topics (no filter applied).
var freeTopics = []string{"science", "history", "geography"}

// ---------------------------------------------------------------------------
// 42. selectQuestions — weighted random pick from MongoDB
// ---------------------------------------------------------------------------

func (s *quizServer) selectQuestions(ctx context.Context, allowedTopics []string) ([]Question, error) {
	coll := s.mongoDB.Collection("questions")

	// Weighted distribution: ~30% easy (1), ~50% medium (3), ~20% hard (1) = 5 questions
	counts := map[string]int{"easy": 1, "medium": 3, "hard": 1}

	var selected []Question
	var lastTopic string

	for _, diff := range []string{"easy", "medium", "hard"} {
		count := counts[diff]

		// Build filter: match difficulty, exclude last topic to prevent adjacent repeats
		filter := bson.M{"difficulty": diff}
		if len(allowedTopics) > 0 {
			if lastTopic != "" {
				// Intersect: allowed topics minus lastTopic
				filtered := make([]string, 0, len(allowedTopics))
				for _, t := range allowedTopics {
					if t != lastTopic {
						filtered = append(filtered, t)
					}
				}
				filter["topic"] = bson.M{"$in": filtered}
			} else {
				filter["topic"] = bson.M{"$in": allowedTopics}
			}
		} else if lastTopic != "" {
			filter["topic"] = bson.M{"$ne": lastTopic}
		}

		// Use aggregation $sample for random selection
		pipeline := mongo.Pipeline{
			{{Key: "$match", Value: filter}},
			{{Key: "$sample", Value: bson.M{"size": count}}},
		}

		cursor, err := coll.Aggregate(ctx, pipeline)
		if err != nil {
			return nil, fmt.Errorf("aggregate %s: %w", diff, err)
		}

		var questions []Question
		if err := cursor.All(ctx, &questions); err != nil {
			return nil, fmt.Errorf("decode %s: %w", diff, err)
		}

		selected = append(selected, questions...)
		if len(questions) > 0 {
			lastTopic = questions[len(questions)-1].Topic
		}
	}

	// Shuffle to interleave difficulties
	rand.Shuffle(len(selected), func(i, j int) {
		selected[i], selected[j] = selected[j], selected[i]
	})

	// Final pass: ensure no adjacent topics repeat
	for i := 1; i < len(selected); i++ {
		if selected[i].Topic == selected[i-1].Topic {
			// Find a non-adjacent swap candidate
			for j := i + 1; j < len(selected); j++ {
				if selected[j].Topic != selected[i-1].Topic {
					selected[i], selected[j] = selected[j], selected[i]
					break
				}
			}
		}
	}

	return selected, nil
}

// ---------------------------------------------------------------------------
// 41. RabbitMQ consumer for match.created
// ---------------------------------------------------------------------------

func (s *quizServer) consumeMatchCreated(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[quiz] failed to open channel for match-created: %v", err)
	}
	defer ch.Close()

	// Declare the exchange, queue, and binding ourselves so startup doesn't
	// race with matchmaking. All three calls are idempotent — if matchmaking
	// already declared them we just no-op. Without this, a RabbitMQ volume
	// wipe followed by quiz starting before matchmaking causes a 404 on the
	// Consume below and the service exits 1.
	if err := ch.ExchangeDeclare("sx", "topic", true, false, false, false, nil); err != nil {
		log.Fatalf("[quiz] failed to declare sx exchange: %v", err)
	}
	if _, err := ch.QueueDeclare("match-created-queue", true, false, false, false, nil); err != nil {
		log.Fatalf("[quiz] failed to declare match-created-queue: %v", err)
	}
	if err := ch.QueueBind("match-created-queue", "match.created", "sx", false, nil); err != nil {
		log.Fatalf("[quiz] failed to bind match-created-queue: %v", err)
	}

	msgs, err := ch.Consume("match-created-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[quiz] failed to consume match-created-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}

			var event struct {
				RoomID    string   `json:"roomId"`
				PlayerIDs []string `json:"playerIds"`
			}
			if err := json.Unmarshal(msg.Body, &event); err != nil {
				log.Printf("[quiz] bad match.created payload: %v", err)
				msg.Nack(false, false)
				continue
			}

			log.Printf("[quiz] match.created for room %s with players %v", event.RoomID, event.PlayerIDs)

			// Determine allowed topics based on player plans.
			// If any player is free, restrict to free topics for fairness.
			var allowedTopics []string
			allPremium := true
			for _, pid := range event.PlayerIDs {
				p, _ := keys.GetPlan(ctx, s.rdb, pid)
				if p == "" {
					var doc bson.M
					if s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": pid}).Decode(&doc) == nil {
						if pl, ok := doc["plan"].(string); ok {
							p = pl
						}
					}
				}
				if p != "premium" {
					allPremium = false
					break
				}
			}
			if !allPremium {
				allowedTopics = freeTopics
			}

			// Select questions and store in Redis
			questions, err := s.selectQuestions(ctx, allowedTopics)
			if err != nil {
				log.Printf("[quiz] selectQuestions error: %v", err)
				msg.Nack(false, true) // requeue
				continue
			}

			// Write question IDs to room:{id}:questions list
			questionIDs := make([]string, len(questions))
			for i, q := range questions {
				questionIDs[i] = q.ID
			}
			if err := keys.SetQuestions(ctx, s.rdb, event.RoomID, questionIDs); err != nil {
				log.Printf("[quiz] failed to store questions: %v", err)
				msg.Nack(false, true)
				continue
			}

			// Store full question data in memory for broadcasting
			s.storeRoomQuestions(event.RoomID, questions)

			// Set round to 1 and start
			keys.SetRoomRound(ctx, s.rdb, event.RoomID, 1)

			msg.Ack(false)

			// Start first round after a brief delay for clients to connect
			go func(roomID string) {
				time.Sleep(2 * time.Second)
				s.startRound(ctx, roomID, 1)
			}(event.RoomID)
		}
	}
}

func (s *quizServer) storeRoomQuestions(roomID string, questions []Question) {
	s.roomQuestions.Store(roomID, questions)
}

func (s *quizServer) getRoomQuestions(roomID string) ([]Question, bool) {
	val, ok := s.roomQuestions.Load(roomID)
	if !ok {
		return nil, false
	}
	return val.([]Question), true
}

// ---------------------------------------------------------------------------
// 43. startRound — broadcast QuestionBroadcast with absolute Unix deadline
// ---------------------------------------------------------------------------

func (s *quizServer) startRound(ctx context.Context, roomID string, round int) {
	// Section 7.2: abort if no players connected
	if s.connectedPlayersInRoom(roomID) == 0 {
		log.Printf("[quiz] room %s skipping round %d — no connected players", roomID, round)
		return
	}

	questions, ok := s.getRoomQuestions(roomID)
	if !ok || round > len(questions) {
		// All rounds complete — publish match.finished
		s.finishMatch(ctx, roomID, len(questions))
		return
	}

	q := questions[round-1]
	deadlineUnix := time.Now().Add(15 * time.Second).Unix()

	log.Printf("[quiz] room %s starting round %d — question: %s", roomID, round, q.Text)

	// Store deadline for reconnection snapshots and TimerSync
	s.roomDeadlines.Store(roomID, deadlineUnix)

	// Update round in Redis
	keys.SetRoomRound(ctx, s.rdb, roomID, round)

	// Broadcast QuestionBroadcast GameEvent to all clients
	seq := s.getSeqCounter(roomID).Add(1)
	event := &pb.GameEvent{
		SequenceNumber: seq,
		Event: &pb.GameEvent_Question{
			Question: &pb.QuestionBroadcast{
				QuestionId:   q.ID,
				Text:         q.Text,
				Options:      q.Options,
				DeadlineUnix: deadlineUnix,
				Round:        int32(round),
			},
		},
	}
	s.broadcastToRoom(roomID, event)

	// Start 15s timer — fires closeRound regardless of how many answers arrived
	timer := time.AfterFunc(15*time.Second, func() {
		s.closeRound(ctx, roomID, round)
	})
	s.roomTimers.Store(roomID, timer)

	// Periodic TimerSync — broadcast every 3 seconds until round ends
	go func() {
		ticker := time.NewTicker(3 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			dl, ok := s.roomDeadlines.Load(roomID)
			if !ok {
				return
			}
			deadline := dl.(int64)
			if time.Now().Unix() >= deadline {
				return // round has ended
			}
			syncSeq := s.getSeqCounter(roomID).Add(1)
			s.broadcastToRoom(roomID, &pb.GameEvent{
				SequenceNumber: syncSeq,
				Event: &pb.GameEvent_TimerSync{
					TimerSync: &pb.TimerSync{
						DeadlineUnix: deadline,
					},
				},
			})
		}
	}()
}

// ---------------------------------------------------------------------------
// 44. closeRound — SETNX guard, broadcast RoundResult, advance or finish
// ---------------------------------------------------------------------------

func (s *quizServer) closeRound(ctx context.Context, roomID string, round int) {
	// SETNX guard: only one goroutine closes the round
	won, err := keys.TryCloseRound(ctx, s.rdb, roomID, round)
	if err != nil || !won {
		return // another goroutine already closed this round
	}

	questions, ok := s.getRoomQuestions(roomID)
	if !ok || round > len(questions) {
		return
	}

	q := questions[round-1]

	log.Printf("[quiz] room %s round %d closed — correct answer: %d", roomID, round, q.CorrectIndex)

	// Broadcast RoundResult GameEvent
	seq := s.getSeqCounter(roomID).Add(1)
	event := &pb.GameEvent{
		SequenceNumber: seq,
		Event: &pb.GameEvent_RoundResult{
			RoundResult: &pb.RoundResult{
				Round:        int32(round),
				CorrectIndex: int32(q.CorrectIndex),
			},
		},
	}
	s.broadcastToRoom(roomID, event)

	// Publish round.completed to RabbitMQ
	roundEvent, err := json.Marshal(map[string]interface{}{
		"roomId": roomID,
		"round":  round,
	})
	if err != nil {
		log.Printf("[quiz] failed to marshal round.completed: %v", err)
		return
	}
	if err := s.publish(ctx, "round.completed", roundEvent); err != nil {
		log.Printf("[quiz] failed to publish round.completed: %v", err)
	}

	// Round advancement is handled by consumeRoundCompleted via RabbitMQ
}

// ---------------------------------------------------------------------------
// Match finish — publish match.finished, broadcast MatchEnd
// ---------------------------------------------------------------------------

func (s *quizServer) finishMatch(ctx context.Context, roomID string, totalRounds int) {
	log.Printf("[quiz] room %s match finished after %d rounds", roomID, totalRounds)

	// Get leaderboard from Redis for final results
	entries, _ := keys.GetLeaderboardEntries(ctx, s.rdb, roomID)

	// Authoritative participant list — the leaderboard ZSET only contains
	// players who answered at least once. Without pulling the full roster,
	// an opponent who abandoned before round 1 would be missing from the
	// MatchEnd event and match_history.
	allPlayers, _ := keys.GetAllPlayers(ctx, s.rdb, roomID)

	// Resolve how many rounds actually have answer records. `totalRounds` is a
	// status signal from the caller — it's -1 on opponent-abandon and 0 on
	// zero-connected — so it can't be used as the tally upper bound. The
	// authoritative source is room:{id}:round, which tracks the current round.
	roundsPlayed, err := keys.GetRoomRound(ctx, s.rdb, roomID)
	if err != nil {
		roundsPlayed = 0
	}

	// Helper: count correct answers for a userID across rounds 1..roundsPlayed.
	tallyCorrect := func(userID string) int32 {
		var n int32
		for round := 1; round <= roundsPlayed; round++ {
			answerJSON, err := s.rdb.HGet(ctx, keys.Answers(roomID, round), userID).Result()
			if err != nil {
				continue
			}
			var rec struct {
				Correct bool `json:"correct"`
			}
			if json.Unmarshal([]byte(answerJSON), &rec) == nil && rec.Correct {
				n++
			}
		}
		return n
	}

	// Helper: compute average response time (ms) for a userID across rounds.
	// Mirrors the persistence worker's logic so MatchEnd broadcast and
	// match_history agree on avg_response_time_ms.
	tallyAvgMs := func(userID string) float64 {
		var totalMs int64
		var answered int
		for round := 1; round <= roundsPlayed; round++ {
			answerJSON, err := s.rdb.HGet(ctx, keys.Answers(roomID, round), userID).Result()
			if err != nil {
				continue
			}
			var rec struct {
				Timestamp       int64 `json:"timestamp"`
				ClientTimestamp int64 `json:"clientTimestamp"`
			}
			if json.Unmarshal([]byte(answerJSON), &rec) == nil &&
				rec.Timestamp > 0 && rec.ClientTimestamp > 0 {
				totalMs += rec.Timestamp - rec.ClientTimestamp
				answered++
			}
		}
		if answered == 0 {
			return 0
		}
		return float64(totalMs) / float64(answered)
	}

	// Helper: resolve username + plan from the room players hash.
	resolveInfo := func(userID string) (string, string) {
		username := userID
		plan := "free"
		if raw, ok := allPlayers[userID]; ok {
			var info struct {
				Username string `json:"username"`
				Plan     string `json:"plan"`
			}
			if json.Unmarshal([]byte(raw), &info) == nil {
				if info.Username != "" {
					username = info.Username
				}
				if info.Plan != "" {
					plan = info.Plan
				}
			}
		}
		return username, plan
	}

	var winner string
	playerResults := make([]*pb.PlayerResult, 0, len(allPlayers))
	scored := make(map[string]bool, len(entries))

	// First pass: leaderboard-ranked players (by score desc).
	for i, e := range entries {
		userID := e.Member.(string)
		scored[userID] = true
		if i == 0 {
			winner = userID
		}
		username, pPlan := resolveInfo(userID)
		playerResults = append(playerResults, &pb.PlayerResult{
			UserId:            userID,
			Username:          username,
			FinalScore:        e.Score,
			Rank:              int32(i + 1),
			AnswersCorrect:    tallyCorrect(userID),
			AvgResponseTimeMs: tallyAvgMs(userID),
			Plan:              pPlan,
		})
	}

	// Second pass: participants who never scored — append with zero score so
	// both players are represented in the abandonment case.
	nextRank := int32(len(entries) + 1)
	for userID := range allPlayers {
		if scored[userID] {
			continue
		}
		username, pPlan := resolveInfo(userID)
		playerResults = append(playerResults, &pb.PlayerResult{
			UserId:            userID,
			Username:          username,
			FinalScore:        0,
			Rank:              nextRank,
			AnswersCorrect:    tallyCorrect(userID),
			AvgResponseTimeMs: tallyAvgMs(userID),
			Plan:              pPlan,
		})
		nextRank++
	}

	// Broadcast MatchEnd GameEvent
	seq := s.getSeqCounter(roomID).Add(1)
	event := &pb.GameEvent{
		SequenceNumber: seq,
		Event: &pb.GameEvent_MatchEnd{
			MatchEnd: &pb.MatchEnd{
				RoomId:  roomID,
				Winner:  winner,
				Players: playerResults,
				Rounds:  int32(totalRounds),
			},
		},
	}
	s.broadcastToRoom(roomID, event)

	// Publish match.finished to RabbitMQ (consumed by persistence worker + analytics)
	finishEvent, err := json.Marshal(map[string]interface{}{
		"roomId":  roomID,
		"winner":  winner,
		"rounds":  totalRounds,
		"players": playerResults,
	})
	if err != nil {
		log.Printf("[quiz] failed to marshal match.finished: %v", err)
	} else if err := s.publish(ctx, "match.finished", finishEvent); err != nil {
		log.Printf("[quiz] failed to publish match.finished: %v", err)
	}

	// Cleanup in-memory state
	s.roomQuestions.Delete(roomID)
	s.seqCounters.Delete(roomID)
	s.roomTimers.Delete(roomID)
}

// connectedPlayersInRoom returns the number of active game streams for a room.
func (s *quizServer) connectedPlayersInRoom(roomID string) int {
	prefix := roomID + ":"
	count := 0
	s.gameStreams.Range(func(key, _ interface{}) bool {
		k := key.(string)
		if len(k) > len(prefix) && k[:len(prefix)] == prefix {
			count++
		}
		return true
	})
	return count
}

// cancelRoomTimer stops the round timer for a room if one is running.
func (s *quizServer) cancelRoomTimer(roomID string) {
	if v, ok := s.roomTimers.LoadAndDelete(roomID); ok {
		v.(*time.Timer).Stop()
	}
}

// ---------------------------------------------------------------------------
// Broadcast helper — send GameEvent to all streams for a room
// ---------------------------------------------------------------------------

func (s *quizServer) broadcastToRoom(roomID string, event *pb.GameEvent) {
	prefix := roomID + ":"
	s.gameStreams.Range(func(key, value interface{}) bool {
		k := key.(string)
		if len(k) > len(prefix) && k[:len(prefix)] == prefix {
			ch := value.(chan *pb.GameEvent)
			select {
			case ch <- event:
			default:
				log.Printf("[quiz] stream buffer full for %s", k)
			}
		}
		return true
	})
}

// ---------------------------------------------------------------------------
// sendStateSnapshot — sends current match state to a newly connected stream
// Handles both reconnection (missed events) and late joiners
// ---------------------------------------------------------------------------

func (s *quizServer) sendStateSnapshot(ctx context.Context, roomID string, stream pb.QuizService_StreamGameEventsServer) {
	// Get current round
	round, err := keys.GetRoomRound(ctx, s.rdb, roomID)
	if err != nil || round < 1 {
		return // match hasn't started yet
	}

	questions, ok := s.getRoomQuestions(roomID)
	if !ok {
		return // match data not loaded
	}

	// Send current leaderboard state
	entries, err := keys.GetLeaderboardEntries(ctx, s.rdb, roomID)
	if err == nil && len(entries) > 0 {
		lbEntries := make([]*pb.LeaderboardEntry, 0, len(entries))
		for i, e := range entries {
			userID := e.Member.(string)
			username := userID
			ePlan := "free"
			if playerJSON, err := keys.GetPlayer(ctx, s.rdb, roomID, userID); err == nil {
				var info struct {
					Username string `json:"username"`
					Plan     string `json:"plan"`
				}
				if json.Unmarshal([]byte(playerJSON), &info) == nil {
					if info.Username != "" {
						username = info.Username
					}
					if info.Plan != "" {
						ePlan = info.Plan
					}
				}
			}
			lbEntries = append(lbEntries, &pb.LeaderboardEntry{
				UserId:   userID,
				Username: username,
				Score:    e.Score,
				Rank:     int32(i + 1),
				Plan:     ePlan,
			})
		}
		stream.Send(&pb.GameEvent{
			SequenceNumber: 0, // snapshot, not a sequenced event
			Event: &pb.GameEvent_Leaderboard{
				Leaderboard: &pb.LeaderboardUpdate{Entries: lbEntries},
			},
		})
	}

	// Send current question with remaining time if round is still active
	if round >= 1 && round <= len(questions) {
		q := questions[round-1]
		deadlineUnix := int64(0)
		if dl, ok := s.roomDeadlines.Load(roomID); ok {
			deadlineUnix = dl.(int64)
		}
		// Only send if the round hasn't expired
		if deadlineUnix > time.Now().Unix() {
			stream.Send(&pb.GameEvent{
				SequenceNumber: 0,
				Event: &pb.GameEvent_Question{
					Question: &pb.QuestionBroadcast{
						QuestionId:   q.ID,
						Text:         q.Text,
						Options:      q.Options,
						DeadlineUnix: deadlineUnix,
						Round:        int32(round),
					},
				},
			})
		}
	}
}

// ---------------------------------------------------------------------------
// StreamGameEvents — server-streaming RPC (section 4.1)
// ---------------------------------------------------------------------------

func (s *quizServer) StreamGameEvents(req *pb.StreamGameEventsRequest, stream pb.QuizService_StreamGameEventsServer) error {
	userID, err := auth.UserIDFromContext(stream.Context())
	if err != nil {
		return status.Error(codes.Unauthenticated, "not authenticated")
	}

	streamKey := req.RoomId + ":" + userID
	ch := make(chan *pb.GameEvent, 20)
	s.gameStreams.Store(streamKey, ch)
	defer func() {
		s.gameStreams.Delete(streamKey)
		close(ch)

		// Section 7.2: handle player disconnect
		remaining := s.connectedPlayersInRoom(req.RoomId)
		bgCtx := context.Background()

		if remaining == 0 {
			log.Printf("[quiz] room %s has zero connected players — ending match", req.RoomId)
			s.cancelRoomTimer(req.RoomId)
			if _, ok := s.getRoomQuestions(req.RoomId); ok {
				s.finishMatch(bgCtx, req.RoomId, 0)
			}
		} else if remaining == 1 {
			log.Printf("[quiz] room %s has one player left — opponent left, ending match", req.RoomId)
			s.cancelRoomTimer(req.RoomId)
			if _, ok := s.getRoomQuestions(req.RoomId); ok {
				s.finishMatch(bgCtx, req.RoomId, -1) // -1 signals opponent abandoned
			}
		} else {
			log.Printf("[quiz] player %s disconnected from room %s (%d remaining)",
				userID, req.RoomId, remaining)
		}
	}()

	log.Printf("[quiz] player %s streaming game events for room %s", userID, req.RoomId)

	// Broadcast PlayerJoined to existing players in the room
	username := userID
	playerPlan := "free"
	if playerJSON, err := keys.GetPlayer(stream.Context(), s.rdb, req.RoomId, userID); err == nil {
		var info struct {
			Username string `json:"username"`
			Plan     string `json:"plan"`
		}
		if json.Unmarshal([]byte(playerJSON), &info) == nil {
			if info.Username != "" {
				username = info.Username
			}
			if info.Plan != "" {
				playerPlan = info.Plan
			}
		}
	}
	seq := s.getSeqCounter(req.RoomId).Add(1)
	s.broadcastToRoom(req.RoomId, &pb.GameEvent{
		SequenceNumber: seq,
		Event: &pb.GameEvent_PlayerJoined{
			PlayerJoined: &pb.PlayerJoined{
				UserId:   userID,
				Username: username,
				Plan:     playerPlan,
			},
		},
	})

	// Send current state snapshot for late joiners and reconnections
	s.sendStateSnapshot(stream.Context(), req.RoomId, stream)

	for {
		select {
		case event, ok := <-ch:
			if !ok {
				return nil
			}
			if err := stream.Send(event); err != nil {
				return err
			}
		case <-stream.Context().Done():
			return stream.Context().Err()
		}
	}
}

// ---------------------------------------------------------------------------
// GetRoomQuestions — unary RPC
// ---------------------------------------------------------------------------

func (s *quizServer) GetRoomQuestions(ctx context.Context, req *pb.GetRoomQuestionsRequest) (*pb.GetRoomQuestionsResponse, error) {
	questions, ok := s.getRoomQuestions(req.RoomId)
	if !ok {
		return &pb.GetRoomQuestionsResponse{}, nil
	}

	pbQuestions := make([]*pb.Question, len(questions))
	for i, q := range questions {
		pbQuestions[i] = &pb.Question{
			Id:         q.ID,
			Text:       q.Text,
			Options:    q.Options,
			Difficulty: q.Difficulty,
			Topic:      q.Topic,
		}
	}

	return &pb.GetRoomQuestionsResponse{Questions: pbQuestions}, nil
}

// ---------------------------------------------------------------------------
// Phase 2: Tournament RPCs
// ---------------------------------------------------------------------------

func (s *quizServer) GetTournamentList(ctx context.Context, _ *pb.GetTournamentListRequest) (*pb.GetTournamentListResponse, error) {
	cursor, err := s.mongoDB.Collection("tournaments").Find(ctx, bson.M{
		"status": bson.M{"$in": []string{"upcoming", "active"}},
	})
	if err != nil {
		return &pb.GetTournamentListResponse{}, nil
	}
	defer cursor.Close(ctx)

	var tournaments []*pb.TournamentInfo
	for cursor.Next(ctx) {
		var doc bson.M
		if err := cursor.Decode(&doc); err != nil {
			continue
		}
		t := &pb.TournamentInfo{
			Id:               fmt.Sprintf("%v", doc["_id"]),
			Name:             doc["name"].(string),
			Status:           doc["status"].(string),
			RequiredPlan:     doc["requiredPlan"].(string),
			PrizeDescription: doc["prizeDescription"].(string),
		}
		if st, ok := doc["startTime"].(time.Time); ok {
			t.StartTime = st.Unix()
		}
		if et, ok := doc["endTime"].(time.Time); ok {
			t.EndTime = et.Unix()
		}
		if p, ok := doc["participants"].(bson.A); ok {
			t.ParticipantCount = int32(len(p))
		}
		tournaments = append(tournaments, t)
	}

	return &pb.GetTournamentListResponse{Tournaments: tournaments}, nil
}

func (s *quizServer) JoinTournament(ctx context.Context, req *pb.JoinTournamentRequest) (*pb.JoinTournamentResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	// Server-side plan check — free users cannot join premium tournaments
	plan, _ := keys.GetPlan(ctx, s.rdb, userID)
	if plan == "" {
		var userDoc bson.M
		if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&userDoc); err == nil {
			if p, ok := userDoc["plan"].(string); ok {
				plan = p
			}
		}
		if plan == "" {
			plan = "free"
		}
		keys.SetPlan(ctx, s.rdb, userID, plan)
	}

	// Check tournament requirements
	var tournament bson.M
	if err := s.mongoDB.Collection("tournaments").FindOne(ctx, bson.M{"_id": req.TournamentId}).Decode(&tournament); err != nil {
		return nil, status.Error(codes.NotFound, "tournament not found")
	}

	requiredPlan, _ := tournament["requiredPlan"].(string)
	if requiredPlan == "premium" && plan != "premium" {
		return nil, status.Error(codes.PermissionDenied, "Tournaments require Premium.")
	}

	// Reject joins after the entry deadline has passed. Falls back to
	// startTime when entryDeadline is unset (zero) so legacy seed docs
	// without the field keep their previous behavior of "join until start".
	now := time.Now()
	deadline, _ := tournament["entryDeadline"].(time.Time)
	if deadline.IsZero() {
		if st, ok := tournament["startTime"].(time.Time); ok {
			deadline = st
		}
	}
	if !deadline.IsZero() && now.After(deadline) {
		return nil, status.Error(codes.FailedPrecondition, "Entry window has closed for this tournament.")
	}
	// Reject joins for tournaments that have already ended. status="completed"
	// alone isn't enough — a tournament can still be in active state past its
	// endTime if the finalization worker hasn't run yet, and we shouldn't let
	// stragglers slip in during that race.
	if et, ok := tournament["endTime"].(time.Time); ok && now.After(et) {
		return nil, status.Error(codes.FailedPrecondition, "Tournament has ended.")
	}
	if statusStr, _ := tournament["status"].(string); statusStr == "completed" {
		return nil, status.Error(codes.FailedPrecondition, "Tournament has ended.")
	}

	// Add user to participants
	s.mongoDB.Collection("tournaments").UpdateOne(ctx,
		bson.M{"_id": req.TournamentId},
		bson.M{"$addToSet": bson.M{"participants": userID}},
	)

	return &pb.JoinTournamentResponse{Success: true}, nil
}

// ---------------------------------------------------------------------------
// 45. SubmitAnswer — publish to RabbitMQ, return ack immediately
// ---------------------------------------------------------------------------

func (s *quizServer) SubmitAnswer(ctx context.Context, req *pb.SubmitAnswerRequest) (*pb.SubmitAnswerResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	// Publish answer.submitted event to RabbitMQ — do not wait for scoring
	eventPayload, err := json.Marshal(map[string]interface{}{
		"roomId":          req.RoomId,
		"userId":          userID,
		"round":           req.Round,
		"optionIndex":     req.OptionIndex,
		"clientTimestamp": req.ClientTimestamp,
		"serverTimestamp": time.Now().UnixMilli(),
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to marshal answer: %v", err)
	}

	if err := s.publish(ctx, "answer.submitted", eventPayload); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to publish answer: %v", err)
	}

	log.Printf("[quiz] answer from %s for room %s round %d option %d", userID, req.RoomId, req.Round, req.OptionIndex)
	return &pb.SubmitAnswerResponse{Accepted: true}, nil
}

// ---------------------------------------------------------------------------
// RabbitMQ setup — declare queues needed by downstream services
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Phase 2/3: Tournament workers
//   - reminder ticker  — fires "starting in 30 min" pushes
//   - finalization     — closes tournaments past endTime, awards prizes
//   - weekly creator   — auto-spawns one open tournament per ISO week
// ---------------------------------------------------------------------------

// tournamentReminderTicker fires every minute. The 30-min reminder is a
// 2-minute window [now+29m, now+31m] keyed off Tournament.ReminderSent.
//
// Earlier behavior used a 5-minute tick and a 10-minute window (now+25 to
// now+35), which silently missed any tournament whose startTime fell into
// the 5-minute gap between consecutive ticks (any T_start in
// [tick_n - 5m, tick_n + 0m) — half of all possible times). The 1-minute
// cadence narrows the slop to ~30 seconds and the tighter window means a
// reminder lands ~30 minutes ahead, not "somewhere in 25-35 minutes".
func (s *quizServer) tournamentReminderTicker(ctx context.Context) {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			now := time.Now()
			windowStart := now.Add(29 * time.Minute)
			windowEnd := now.Add(31 * time.Minute)

			cursor, err := s.mongoDB.Collection("tournaments").Find(ctx, bson.M{
				"startTime":    bson.M{"$gte": windowStart, "$lte": windowEnd},
				"reminderSent": false,
			})
			if err != nil {
				continue
			}

			for cursor.Next(ctx) {
				var doc bson.M
				if err := cursor.Decode(&doc); err != nil {
					continue
				}
				tourID := fmt.Sprintf("%v", doc["_id"])
				tourName, _ := doc["name"].(string)
				participants, _ := doc["participants"].(bson.A)

				userIDs := make([]string, 0, len(participants))
				for _, p := range participants {
					if id, ok := p.(string); ok {
						userIDs = append(userIDs, id)
					}
				}

				// Fan out: one message per participant. Keeps the notification
				// worker per-user (no implicit fan-out inside the consumer) and
				// keeps payloads uniform across all notif.* events.
				for _, uid := range userIDs {
					payload, _ := json.Marshal(map[string]interface{}{
						"event":           "notif.tournament.remind",
						"userId":          uid,
						"tournamentName":  tourName,
						"startsInMinutes": 30,
					})
					s.publish(ctx, "notif.tournament.remind", payload)
				}

				s.mongoDB.Collection("tournaments").UpdateOne(ctx,
					bson.M{"_id": doc["_id"]},
					bson.M{"$set": bson.M{"reminderSent": true}},
				)
				log.Printf("[quiz] tournament reminder sent for %s (%d participants)", tourID, len(userIDs))
			}
			cursor.Close(ctx)
		}
	}
}

// tournamentFinalizationWorker runs every minute and closes tournaments
// whose scoring window has ended. For each, it:
//  1. Reads the top-N entries from tournament_standings (N = len(prizePool)).
//  2. Publishes one `tournament.finished` event per winner with their rank
//     and coin reward — consumed by the scoring service which writes the
//     coin grant + emits notif.tournament.finished.
//  3. Flips the tournament to status="completed" with winnersAwarded=true.
//     Both flags are set in a single $set so the worker can re-poll safely:
//     the next poll won't see this row because the filter requires
//     winnersAwarded=false.
//
// Tournaments with empty prizePool still get marked completed, just without
// any payouts — a "for fun" leaderboard mode. The finishing event fans out
// to all participants in that case (zero coins) so they still see the FCM.
func (s *quizServer) tournamentFinalizationWorker(ctx context.Context) {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			now := time.Now()
			s.promoteUpcomingTournaments(ctx, now)
			s.finalizeExpiredTournaments(ctx, now)
		}
	}
}

// promoteUpcomingTournaments flips status="upcoming" → "active" for any
// tournament whose start time has arrived. Without this, the scoring
// service's standings updater (which filters on status="active") would
// silently ignore matches played during the scoring window.
func (s *quizServer) promoteUpcomingTournaments(ctx context.Context, now time.Time) {
	res, err := s.mongoDB.Collection("tournaments").UpdateMany(ctx,
		bson.M{
			"status":    "upcoming",
			"startTime": bson.M{"$lte": now},
			"endTime":   bson.M{"$gt": now},
		},
		bson.M{"$set": bson.M{"status": "active"}},
	)
	if err != nil {
		log.Printf("[quiz] promote upcoming→active failed: %v", err)
		return
	}
	if res.ModifiedCount > 0 {
		log.Printf("[quiz] promoted %d tournament(s) to active", res.ModifiedCount)
	}
}

func (s *quizServer) finalizeExpiredTournaments(ctx context.Context, now time.Time) {
	cursor, err := s.mongoDB.Collection("tournaments").Find(ctx, bson.M{
		"status":         bson.M{"$in": []string{"upcoming", "active"}},
		"endTime":        bson.M{"$lte": now},
		"winnersAwarded": false,
	})
	if err != nil {
		log.Printf("[quiz] finalize: tournament lookup failed: %v", err)
		return
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var t models.Tournament
		if err := cursor.Decode(&t); err != nil {
			log.Printf("[quiz] finalize: decode failed: %v", err)
			continue
		}

		// Race guard: flip winnersAwarded=true atomically with a $eq:false
		// filter. Two parallel quiz instances would both see the row in their
		// cursor; only one will land the update. The loser sees ModifiedCount=0
		// and skips this row, leaving payout to the winner. This is the same
		// pattern the auth service uses for streak claims.
		res, err := s.mongoDB.Collection("tournaments").UpdateOne(ctx,
			bson.M{"_id": t.ID, "winnersAwarded": false},
			bson.M{"$set": bson.M{"winnersAwarded": true, "status": "completed"}},
		)
		if err != nil || res.ModifiedCount == 0 {
			continue
		}

		// Build the winner list: top-N from standings sorted by score desc,
		// where N = len(prizePool). When prizePool is empty we still emit a
		// finished event for every participant with zero coins so they get
		// the closing notification. If neither is populated (admin error or
		// fully unattended tournament), there's nothing to publish — skip.
		topN := len(t.PrizePool)
		if topN == 0 {
			topN = len(t.Participants)
		}
		if topN == 0 {
			log.Printf("[quiz] finalize: tournament %s closed with no participants and no prize pool", t.ID)
			continue
		}

		// Pull standings sorted by score desc, capped at topN.
		findOpts := options.Find().SetSort(bson.M{"score": -1}).SetLimit(int64(topN))
		standingsCursor, err := s.mongoDB.Collection("tournament_standings").Find(ctx,
			bson.M{"tournamentId": t.ID},
			findOpts,
		)
		if err != nil {
			log.Printf("[quiz] finalize: standings lookup failed for %s: %v", t.ID, err)
			continue
		}

		rank := 0
		for standingsCursor.Next(ctx) {
			var st models.TournamentStanding
			if err := standingsCursor.Decode(&st); err != nil {
				continue
			}
			rank++

			var coins int64
			if rank-1 < len(t.PrizePool) {
				coins = t.PrizePool[rank-1]
			}

			payload, _ := json.Marshal(map[string]interface{}{
				"event":          "tournament.finished",
				"tournamentId":   t.ID,
				"tournamentName": t.Name,
				"userId":         st.UserID,
				"rank":           rank,
				"coinsAwarded":   coins,
				"finalScore":     st.Score,
			})
			if err := s.publish(ctx, "tournament.finished", payload); err != nil {
				log.Printf("[quiz] finalize: publish failed for tournament=%s user=%s: %v", t.ID, st.UserID, err)
			}
		}
		standingsCursor.Close(ctx)

		log.Printf("[quiz] finalized tournament %s (%s): %d winners published", t.ID, t.Name, rank)
	}
}

// weeklyTournamentCron ensures there is at least one open free-tier
// tournament running each ISO week. Runs hourly so a fresh deployment
// fills in the current week within an hour and recurring weeks roll over
// automatically. The weekly slot is keyed by ISO year+week to make the
// "already created this week" check trivial and timezone-stable.
//
// Schedule: Saturday 18:00 IST → Sunday 23:59 IST. Entry deadline is the
// start time (joins close when scoring opens), prize pool is fixed at
// [500, 300, 100] coins for top 3.
//
// Idempotency: the cron writes with bson.M{"weekKey": ...} as a unique
// natural key. The seed/main.go index ensures only one auto-generated
// tournament per weekKey can ever exist.
func (s *quizServer) weeklyTournamentCron(ctx context.Context) {
	// Tick once on startup so a fresh deployment doesn't wait an hour for
	// the first run; subsequent ticks happen hourly.
	s.ensureCurrentWeekTournament(ctx, time.Now())

	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.ensureCurrentWeekTournament(ctx, time.Now())
		}
	}
}

func (s *quizServer) ensureCurrentWeekTournament(ctx context.Context, now time.Time) {
	istLocation, err := time.LoadLocation("Asia/Kolkata")
	if err != nil {
		// Fallback: the host's local time. The scheduling math still works,
		// the tournament times will just be off by a TZ offset.
		istLocation = time.Local
	}
	istNow := now.In(istLocation)
	year, week := istNow.ISOWeek()
	weekKey := fmt.Sprintf("%d-W%02d", year, week)

	// Saturday 18:00 IST of the current ISO week.
	// ISO weeks start Monday — find the Monday at 00:00 IST, then add 5d18h.
	weekday := int(istNow.Weekday())
	if weekday == 0 {
		weekday = 7 // Sunday → 7 in ISO
	}
	monday := time.Date(istNow.Year(), istNow.Month(), istNow.Day(), 0, 0, 0, 0, istLocation).
		AddDate(0, 0, -(weekday - 1))
	startTime := monday.Add(5*24*time.Hour + 18*time.Hour) // Saturday 18:00 IST
	endTime := startTime.Add(30 * time.Hour)               // Sunday 23:59:59 IST-ish

	// Skip weeks where the slot has already passed — no point spawning a
	// tournament that's already over before anyone could join.
	if endTime.Before(istNow) {
		return
	}

	doc := models.Tournament{
		Name:             fmt.Sprintf("Weekly Open — %s", weekKey),
		StartTime:        startTime,
		EndTime:          endTime,
		EntryDeadline:    startTime,
		Status:           "upcoming",
		Participants:     []string{},
		RequiredPlan:     "free",
		PrizeDescription: "Top 3 win 500 / 300 / 100 coins",
		PrizePool:        []int64{500, 300, 100},
		AutoGenerated:    true,
		CreatedAt:        now,
	}

	// Upsert keyed by (autoGenerated, weekKey). The weekKey field is used
	// only for idempotency lookup — it never appears in client responses.
	_, err = s.mongoDB.Collection("tournaments").UpdateOne(ctx,
		bson.M{"autoGenerated": true, "weekKey": weekKey},
		bson.M{
			"$setOnInsert": bson.M{
				"name":             doc.Name,
				"startTime":        doc.StartTime,
				"endTime":          doc.EndTime,
				"entryDeadline":    doc.EntryDeadline,
				"status":           doc.Status,
				"participants":     doc.Participants,
				"requiredPlan":     doc.RequiredPlan,
				"prizeDescription": doc.PrizeDescription,
				"prizePool":        doc.PrizePool,
				"autoGenerated":    true,
				"weekKey":          weekKey,
				"createdAt":        doc.CreatedAt,
				"reminderSent":     false,
				"winnersAwarded":   false,
			},
		},
		options.UpdateOne().SetUpsert(true),
	)
	if err != nil {
		log.Printf("[quiz] weekly tournament upsert failed for %s: %v", weekKey, err)
		return
	}
}

func setupRabbitMQ(ch *amqp.Channel) error {
	// Ensure sx exchange exists
	if err := ch.ExchangeDeclare("sx", "topic", true, false, false, false, nil); err != nil {
		return fmt.Errorf("exchange declare: %w", err)
	}

	// answer-processing-queue with DLQ (consumed by scoring service)
	_, err := ch.QueueDeclare("answer-processing-queue", true, false, false, false, amqp.Table{
		"x-dead-letter-exchange":    "",
		"x-dead-letter-routing-key": "answer-processing-dlq",
		"x-max-delivery-count":      3,
	})
	if err != nil {
		return fmt.Errorf("answer queue declare: %w", err)
	}
	if err := ch.QueueBind("answer-processing-queue", "answer.submitted", "sx", false, nil); err != nil {
		return fmt.Errorf("answer queue bind: %w", err)
	}

	// Dead letter queue for failed answer processing
	_, err = ch.QueueDeclare("answer-processing-dlq", true, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("dlq declare: %w", err)
	}

	// round-completed-queue (consumed by quiz engine itself to advance rounds)
	_, err = ch.QueueDeclare("round-completed-queue", true, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("round queue declare: %w", err)
	}
	if err := ch.QueueBind("round-completed-queue", "round.completed", "sx", false, nil); err != nil {
		return fmt.Errorf("round queue bind: %w", err)
	}

	// match-finished-queue (consumed by persistence worker in scoring service)
	_, err = ch.QueueDeclare("match-finished-queue", true, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("match-finished queue declare: %w", err)
	}
	if err := ch.QueueBind("match-finished-queue", "match.finished", "sx", false, nil); err != nil {
		return fmt.Errorf("match-finished queue bind: %w", err)
	}

	// match-analytics-queue (consumed by analytics worker — stub for now)
	_, err = ch.QueueDeclare("match-analytics-queue", true, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("analytics queue declare: %w", err)
	}
	if err := ch.QueueBind("match-analytics-queue", "match.finished", "sx", false, nil); err != nil {
		return fmt.Errorf("analytics queue bind: %w", err)
	}

	// leaderboard-broadcast-queue (consumed by quiz service to broadcast updates to game streams)
	_, err = ch.QueueDeclare("leaderboard-broadcast-queue", true, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("leaderboard queue declare: %w", err)
	}
	if err := ch.QueueBind("leaderboard-broadcast-queue", "leaderboard.updated", "sx", false, nil); err != nil {
		return fmt.Errorf("leaderboard queue bind: %w", err)
	}

	return nil
}

// ---------------------------------------------------------------------------
// consumeRoundCompleted — advance to next round or finish match
// ---------------------------------------------------------------------------

func (s *quizServer) consumeRoundCompleted(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[quiz] failed to open channel for round-completed: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("round-completed-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[quiz] failed to consume round-completed-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}

			var event struct {
				RoomID string `json:"roomId"`
				Round  int    `json:"round"`
			}
			if err := json.Unmarshal(msg.Body, &event); err != nil {
				log.Printf("[quiz] bad round.completed payload: %v", err)
				msg.Nack(false, false)
				continue
			}

			questions, ok := s.getRoomQuestions(event.RoomID)
			if !ok {
				log.Printf("[quiz] round.completed for unknown room %s — skipping", event.RoomID)
				msg.Ack(false)
				continue
			}

			msg.Ack(false)

			if event.Round < len(questions) {
				// Advance to next round after a 2s pause
				go func(roomID string, nextRound int) {
					time.Sleep(2 * time.Second)
					s.startRound(ctx, roomID, nextRound)
				}(event.RoomID, event.Round+1)
			} else {
				// All rounds complete — finish match
				s.finishMatch(ctx, event.RoomID, event.Round)
			}
		}
	}
}

// ---------------------------------------------------------------------------
// consumeLeaderboardUpdated — relay scoring leaderboard events to game streams
// ---------------------------------------------------------------------------

func (s *quizServer) consumeLeaderboardUpdated(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[quiz] failed to open channel for leaderboard-broadcast: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("leaderboard-broadcast-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[quiz] failed to consume leaderboard-broadcast-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}

			var event struct {
				RoomID  string `json:"roomId"`
				Entries []struct {
					Member interface{} `json:"Member"`
					Score  float64     `json:"Score"`
				} `json:"entries"`
			}
			if err := json.Unmarshal(msg.Body, &event); err != nil {
				log.Printf("[quiz] bad leaderboard.updated payload: %v", err)
				msg.Nack(false, false)
				continue
			}

			// Build LeaderboardUpdate GameEvent with resolved usernames + plan
			entries := make([]*pb.LeaderboardEntry, 0, len(event.Entries))
			for i, e := range event.Entries {
				userID := fmt.Sprintf("%v", e.Member)
				username := userID
				entryPlan := "free"
				if playerJSON, err := keys.GetPlayer(ctx, s.rdb, event.RoomID, userID); err == nil {
					var info struct {
						Username string `json:"username"`
						Plan     string `json:"plan"`
					}
					if json.Unmarshal([]byte(playerJSON), &info) == nil {
						if info.Username != "" {
							username = info.Username
						}
						if info.Plan != "" {
							entryPlan = info.Plan
						}
					}
				}
				entries = append(entries, &pb.LeaderboardEntry{
					UserId:   userID,
					Username: username,
					Score:    e.Score,
					Rank:     int32(i + 1),
					Plan:     entryPlan,
				})
			}

			seq := s.getSeqCounter(event.RoomID).Add(1)
			gameEvent := &pb.GameEvent{
				SequenceNumber: seq,
				Event: &pb.GameEvent_Leaderboard{
					Leaderboard: &pb.LeaderboardUpdate{
						Entries: entries,
					},
				},
			}
			s.broadcastToRoom(event.RoomID, gameEvent)

			log.Printf("[quiz] broadcast LeaderboardUpdate for room %s (%d entries)", event.RoomID, len(entries))
			msg.Ack(false)
		}
	}
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Redis
	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: redisAddr})
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("redis connect failed: %v", err)
	}
	log.Println("[quiz] connected to Redis")

	// RabbitMQ
	rabbitURL := os.Getenv("RABBITMQ_URL")
	if rabbitURL == "" {
		rabbitURL = "amqp://guest:guest@localhost:5672/"
	}
	conn, err := amqp.Dial(rabbitURL)
	if err != nil {
		log.Fatalf("rabbitmq connect failed: %v", err)
	}
	defer conn.Close()

	amqpCh, err := conn.Channel()
	if err != nil {
		log.Fatalf("rabbitmq channel failed: %v", err)
	}
	defer amqpCh.Close()

	if err := setupRabbitMQ(amqpCh); err != nil {
		log.Fatalf("rabbitmq setup failed: %v", err)
	}
	log.Println("[quiz] connected to RabbitMQ")

	// MongoDB
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017/quizbattle"
	}
	mongoClient, err := mongo.Connect(options.Client().ApplyURI(mongoURI).SetBSONOptions(&options.BSONOptions{
		ObjectIDAsHexString: true,
	}))
	if err != nil {
		log.Fatalf("mongodb connect failed: %v", err)
	}
	defer mongoClient.Disconnect(ctx)
	log.Println("[quiz] connected to MongoDB")

	// JWT
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "quiz-battle-dev-secret"
	}

	// gRPC server
	srv := &quizServer{
		rdb:       rdb,
		amqpConn:  conn,
		amqpCh:    amqpCh,
		mongoDB:   mongoClient.Database("quizbattle"),
		jwtSecret: jwtSecret,
	}

	// Start RabbitMQ consumers + tournament workers
	go srv.consumeMatchCreated(ctx)
	go srv.consumeRoundCompleted(ctx)
	go srv.consumeLeaderboardUpdated(ctx)
	go srv.tournamentReminderTicker(ctx)
	go srv.tournamentFinalizationWorker(ctx) // Phase 3 (4.2): close expired tournaments
	go srv.weeklyTournamentCron(ctx)         // Phase 3 (4.2): spawn weekly free tournament

	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(auth.UnaryInterceptor(jwtSecret, nil)),
		grpc.StreamInterceptor(auth.StreamInterceptor(jwtSecret, nil)),
	)
	pb.RegisterQuizServiceServer(grpcServer, srv)

	lis, err := net.Listen("tcp", ":50052")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	log.Println("[quiz] serving on :50052")
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
