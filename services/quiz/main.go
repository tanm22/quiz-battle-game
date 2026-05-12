package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math/rand"
	"net"
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
	"quiz-battle/pkg/coins"
	"quiz-battle/pkg/config"
	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/lifecycle"
	"quiz-battle/pkg/log"
	"quiz-battle/pkg/metrics"
	"quiz-battle/pkg/models"
	"quiz-battle/pkg/ratelimit"
	"quiz-battle/pkg/validate"
	pb "quiz-battle/proto"
)

// matchWinCoinReward is the flat coin payout for taking 1st place in a
// regular match. See ADR-0002 for calibration. Tournaments have their own
// per-rank prize pool wired through the existing tournament_payouts work-list.
const matchWinCoinReward int64 = 100

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
	gameStreams   sync.Map         // "roomId:userId" -> chan *pb.GameEvent
	roomTimers    sync.Map         // roomId -> *time.Timer (for round close)
	seqCounters   sync.Map         // roomId -> *atomic.Int64
	roomDeadlines sync.Map         // roomId -> int64 (current round deadline_unix)
	roomQuestions sync.Map         // roomId -> []Question
	metrics       *metrics.Metrics // nil in tests; non-nil in main()
	// §4.7 PR-B1: per-user gate on SubmitAnswer to soak up flooded
	// clients (a misbehaving Flutter build firing answer events in a
	// loop, or a script trying to game scoring). 60/min per user is
	// well above the realistic ceiling of one answer per round at ~10
	// rounds per match — the cap kicks in at obvious abuse, not
	// legitimate play.
	answerLimiter *ratelimit.Limiter
}

// publish sends a message to the topic exchange with mutex protection.
func (s *quizServer) publish(ctx context.Context, routingKey string, body []byte) error {
	s.amqpMu.Lock()
	defer s.amqpMu.Unlock()
	err := log.PublishWithContext(ctx, s.amqpCh, "sx", routingKey, false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        body,
	})
	if s.metrics != nil {
		s.metrics.RecordPublish(routingKey, err)
	}
	return err
}

// newChannel creates a dedicated AMQP channel per consumer (channels are not thread-safe).
func (s *quizServer) newChannel() (*amqp.Channel, error) {
	return s.amqpConn.Channel()
}

// recordConsume increments amqp_consumes_total{queue, status} when the
// service has a non-nil metrics registry. Nil-safe so test instances
// without metrics still call this without crashing.
func (s *quizServer) recordConsume(queue, status string) {
	if s.metrics != nil {
		s.metrics.RecordConsume(queue, status)
	}
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
// computeAllowedTopics — resolve the topic allow-list for a match.
// ---------------------------------------------------------------------------

// computeAllowedTopics returns the topic allow-list for a match given its
// participants. Returns nil to mean "no filter" (all topics allowed).
//
// Algorithm:
//  1. Plan ceiling: if any player is free, ceiling = freeTopics; if all
//     players are premium, ceiling = nil (no plan filtering).
//  2. Preference union: collect the union of every player's preferredTopics.
//  3. Intersect: keep only union members that are within the ceiling.
//  4. Fallback: if the resulting set is empty (e.g. nobody has prefs, or no
//     pref overlaps the free-tier ceiling), fall back to the plan ceiling so
//     un-onboarded users keep working.
//
// Plan is read from Redis first (keys.GetPlan fast-path), then Mongo.
// preferredTopics is read from Mongo only — it is not cached. Both fields
// come from the same user document with one FindOne per player.
func (s *quizServer) computeAllowedTopics(ctx context.Context, playerIDs []string) ([]string, error) {
	// Plan ceiling: nil = "no filter, all topics allowed". A set form keeps
	// the intersection step O(1) per topic without re-allocating.
	var ceiling map[string]struct{} // nil means no filter

	// Preference union across all players.
	prefUnion := make(map[string]struct{})

	for _, pid := range playerIDs {
		// Try Redis fast-path for plan first. Skip when rdb is nil so the
		// helper is unit-testable without a Redis instance — Mongo lookup
		// below covers the same field.
		var plan string
		if s.rdb != nil {
			plan, _ = keys.GetPlan(ctx, s.rdb, pid)
		}

		// Always fetch the user doc — preferredTopics is not cached anywhere,
		// so we'd hit Mongo regardless. Pull plan from the same doc on cache
		// miss to avoid a second roundtrip.
		var doc bson.M
		err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": pid}).Decode(&doc)
		if err != nil && !errors.Is(err, mongo.ErrNoDocuments) {
			return nil, fmt.Errorf("lookup user %s: %w", pid, err)
		}

		if err == nil {
			if plan == "" {
				if pl, ok := doc["plan"].(string); ok {
					plan = pl
				}
			}
			// preferredTopics is stored as a BSON array of strings.
			if raw, ok := doc["preferredTopics"].(bson.A); ok {
				for _, t := range raw {
					if topic, ok := t.(string); ok && topic != "" {
						prefUnion[topic] = struct{}{}
					}
				}
			}
		}

		// Any non-premium player tightens the ceiling to freeTopics. We
		// don't break early — we still need to gather everyone's prefs.
		if plan != "premium" && ceiling == nil {
			ceiling = make(map[string]struct{}, len(freeTopics))
			for _, t := range freeTopics {
				ceiling[t] = struct{}{}
			}
		}
	}

	// Intersect union with ceiling.
	var filtered []string
	if ceiling == nil {
		// All premium: union is unrestricted.
		filtered = make([]string, 0, len(prefUnion))
		for t := range prefUnion {
			filtered = append(filtered, t)
		}
	} else {
		filtered = make([]string, 0, len(prefUnion))
		for t := range prefUnion {
			if _, ok := ceiling[t]; ok {
				filtered = append(filtered, t)
			}
		}
	}

	// Fallback: nothing usable from preferences — return the plan ceiling so
	// pre-onboarding users still get questions.
	if len(filtered) == 0 {
		if ceiling == nil {
			return nil, nil // all topics
		}
		fallback := make([]string, 0, len(ceiling))
		for t := range ceiling {
			fallback = append(fallback, t)
		}
		return fallback, nil
	}

	return filtered, nil
}

// ---------------------------------------------------------------------------
// 41. RabbitMQ consumer for match.created
// ---------------------------------------------------------------------------

func (s *quizServer) consumeMatchCreated(ctx context.Context) {
	ctx = log.ContextWithAttrs(ctx, "consumer", "match_created")
	ch, err := s.newChannel()
	if err != nil {
		log.Fatal(ctx, "open channel failed", "err", err)
	}
	defer ch.Close()

	// Declare the exchange, queue, and binding ourselves so startup doesn't
	// race with matchmaking. All three calls are idempotent — if matchmaking
	// already declared them we just no-op. Without this, a RabbitMQ volume
	// wipe followed by quiz starting before matchmaking causes a 404 on the
	// Consume below and the service exits 1.
	if err := ch.ExchangeDeclare("sx", "topic", true, false, false, false, nil); err != nil {
		log.Fatal(ctx, "declare sx exchange failed", "err", err)
	}
	if _, err := ch.QueueDeclare("match-created-queue", true, false, false, false, nil); err != nil {
		log.Fatal(ctx, "declare match-created-queue failed", "err", err)
	}
	if err := ch.QueueBind("match-created-queue", "match.created", "sx", false, nil); err != nil {
		log.Fatal(ctx, "bind match-created-queue failed", "err", err)
	}

	// prefetch=16 — bounds in-flight match starts so a flush of stale
	// match.created events can't queue more selectQuestions calls than
	// Mongo can absorb. Matches the chosen ceiling on other consumers.
	if err := ch.Qos(16, 0, false); err != nil {
		log.Fatal(ctx, "qos failed", "queue", "match-created-queue", "err", err)
	}

	msgs, err := ch.Consume("match-created-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatal(ctx, "consume failed", "queue", "match-created-queue", "err", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			msgCtx := log.ContextFromDelivery(ctx, msg)

			var event struct {
				RoomID    string   `json:"roomId"`
				PlayerIDs []string `json:"playerIds"`
			}
			if err := json.Unmarshal(msg.Body, &event); err != nil {
				log.FromContext(msgCtx).Warn("bad payload", "err", err)
				msg.Nack(false, false)
				s.recordConsume("match-created-queue", metrics.StatusNackDrop)
				continue
			}

			log.FromContext(msgCtx).Info("match.created received", "room_id", event.RoomID, "player_ids", event.PlayerIDs)

			// Resolve allowed-topics list: plan ceiling intersected with the
			// union of players' preferredTopics, with fallback to ceiling
			// when nobody's preferences apply. See computeAllowedTopics.
			allowedTopics, err := s.computeAllowedTopics(msgCtx, event.PlayerIDs)
			if err != nil {
				log.FromContext(msgCtx).Error("computeAllowedTopics failed", "err", err)
				msg.Nack(false, true) // requeue — transient Mongo failure
				s.recordConsume("match-created-queue", metrics.StatusNackRequeue)
				continue
			}

			// Select questions and store in Redis
			questions, err := s.selectQuestions(msgCtx, allowedTopics)
			if err != nil {
				log.FromContext(msgCtx).Error("selectQuestions failed", "err", err)
				msg.Nack(false, true) // requeue
				s.recordConsume("match-created-queue", metrics.StatusNackRequeue)
				continue
			}

			// Write question IDs to room:{id}:questions list
			questionIDs := make([]string, len(questions))
			for i, q := range questions {
				questionIDs[i] = q.ID
			}
			if err := keys.SetQuestions(msgCtx, s.rdb, event.RoomID, questionIDs); err != nil {
				log.FromContext(msgCtx).Error("store questions failed", "err", err)
				msg.Nack(false, true)
				s.recordConsume("match-created-queue", metrics.StatusNackRequeue)
				continue
			}

			// Store full question data in memory for broadcasting
			s.storeRoomQuestions(event.RoomID, questions)

			// Set round to 1 and start
			keys.SetRoomRound(msgCtx, s.rdb, event.RoomID, 1)

			msg.Ack(false)
			s.recordConsume("match-created-queue", metrics.StatusAck)

			// Start first round after a brief delay for clients to connect.
			// Detach msgCtx so the goroutine carries the request_id but is
			// not bound to the consumer's lifecycle (msg has been Acked).
			go func(roomID string, parentCtx context.Context) {
				time.Sleep(2 * time.Second)
				s.startRound(parentCtx, roomID, 1)
			}(event.RoomID, log.DetachContext(msgCtx))
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
		log.FromContext(ctx).Info("skipping round; no connected players", "room_id", roomID, "round", round)
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

	log.FromContext(ctx).Info("starting round", "room_id", roomID, "round", round, "question", q.Text)

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

	log.FromContext(ctx).Info("round closed", "room_id", roomID, "round", round, "correct_index", q.CorrectIndex)

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
		log.FromContext(ctx).Error("marshal round.completed failed", "err", err)
		return
	}
	if err := s.publish(ctx, "round.completed", roundEvent); err != nil {
		log.FromContext(ctx).Error("publish round.completed failed", "err", err)
	}

	// Round advancement is handled by consumeRoundCompleted via RabbitMQ
}

// ---------------------------------------------------------------------------
// Match finish — publish match.finished, broadcast MatchEnd
// ---------------------------------------------------------------------------

func (s *quizServer) finishMatch(ctx context.Context, roomID string, totalRounds int) {
	log.FromContext(ctx).Info("match finished", "room_id", roomID, "rounds", totalRounds)

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
	ranked := make([]rankedPlayer, 0, len(allPlayers))
	scored := make(map[string]bool, len(entries))

	// First pass: leaderboard-ranked players (by score desc).
	for i, e := range entries {
		userID := e.Member.(string)
		scored[userID] = true
		if i == 0 {
			winner = userID
		}
		username, pPlan := resolveInfo(userID)
		ranked = append(ranked, rankedPlayer{
			UserID:         userID,
			Username:       username,
			FinalScore:     e.Score,
			Rank:           int32(i + 1),
			AnswersCorrect: tallyCorrect(userID),
			AvgRespMs:      tallyAvgMs(userID),
			Plan:           pPlan,
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
		ranked = append(ranked, rankedPlayer{
			UserID:         userID,
			Username:       username,
			FinalScore:     0,
			Rank:           nextRank,
			AnswersCorrect: tallyCorrect(userID),
			AvgRespMs:      tallyAvgMs(userID),
			Plan:           pPlan,
		})
		nextRank++
	}

	playerResults := buildPlayerResults(ranked)

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
		log.FromContext(ctx).Error("marshal match.finished failed", "err", err)
	} else if err := s.publish(ctx, "match.finished", finishEvent); err != nil {
		log.FromContext(ctx).Error("publish match.finished failed", "err", err)
	}

	// §4.3: award match-win coins to the leaderboard winner via the earn
	// pipeline. RefID = "match:<roomId>:user:<winner>" — combined with
	// the (userId, refId, reason) unique index in coin_ledger, a redelivered
	// match.finished can't double-credit even if this branch fires twice.
	// `winner == ""` happens when nobody scored (both abandoned before
	// answering); skip silently in that case.
	if winner != "" {
		earnRouting := coins.EarnRoutingKey(coins.EarnSourceMatchWin)
		earnBody, mErr := json.Marshal(coins.EarnEvent{
			Event:    earnRouting,
			UserID:   winner,
			Amount:   matchWinCoinReward,
			Reason:   coins.ReasonMatchWin,
			RefID:    fmt.Sprintf("match:%s:user:%s", roomID, winner),
			Metadata: map[string]string{"roomId": roomID},
		})
		if mErr != nil {
			log.FromContext(ctx).Error("marshal earn event failed", "event", earnRouting, "err", mErr)
		} else if err := s.publish(ctx, earnRouting, earnBody); err != nil {
			log.FromContext(ctx).Error("publish earn event failed", "event", earnRouting, "err", err)
		}
	}

	// Cleanup in-memory state
	s.roomQuestions.Delete(roomID)
	s.seqCounters.Delete(roomID)
	s.roomTimers.Delete(roomID)
}

// rankedPlayer is the per-player snapshot the finalizer builds before
// emitting MatchEnd. Keeping it as a plain struct (rather than building
// pb.PlayerResult inline) lets buildPlayerResults stay a pure function we
// can unit-test without spinning up Redis/Mongo/RabbitMQ.
type rankedPlayer struct {
	UserID         string
	Username       string
	FinalScore     float64
	Rank           int32
	AnswersCorrect int32
	AvgRespMs      float64
	Plan           string
}

// buildPlayerResults transforms ranked players into pb.PlayerResult slices,
// populating CoinsAwarded so the client can show "+100 coins" without
// guessing. Server-authoritative per §4.3 — the number here is what the
// match-win event payload carries.
func buildPlayerResults(ranked []rankedPlayer) []*pb.PlayerResult {
	out := make([]*pb.PlayerResult, 0, len(ranked))
	for _, p := range ranked {
		var awarded int64
		if p.Rank == 1 {
			awarded = matchWinCoinReward
		}
		out = append(out, &pb.PlayerResult{
			UserId:            p.UserID,
			Username:          p.Username,
			FinalScore:        p.FinalScore,
			Rank:              p.Rank,
			AnswersCorrect:    p.AnswersCorrect,
			AvgResponseTimeMs: p.AvgRespMs,
			Plan:              p.Plan,
			CoinsAwarded:      awarded,
		})
	}
	return out
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
				slog.Warn("stream buffer full", "stream_key", k)
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

// requireRoomMember rejects callers who aren't registered in roomID's
// player hash. Without this gate, any authenticated user who learns or
// guesses a roomID can stream another match's events, submit answers
// into it, or fetch its question bank — see the room-scoping audit for
// the threat model. Fails closed on Redis errors so a transient blip
// can't open the door.
//
// op identifies the calling RPC (stream / submit / questions) and is
// emitted on every warn line so ops can grep / alert per-RPC instead
// of having to disambiguate by message text alone.
func (s *quizServer) requireRoomMember(ctx context.Context, roomID, userID, op string) error {
	ok, err := keys.IsPlayerInRoom(ctx, s.rdb, roomID, userID)
	if err != nil {
		log.FromContext(ctx).Warn("room membership check failed; denying",
			"op", op, "room_id", roomID, "user_id", userID, "err", err)
		return status.Error(codes.Internal, "room membership check failed")
	}
	if !ok {
		log.FromContext(ctx).Warn("non-member attempted room access",
			"op", op, "room_id", roomID, "user_id", userID)
		return status.Error(codes.PermissionDenied, "not a member of this room")
	}
	return nil
}

func (s *quizServer) StreamGameEvents(req *pb.StreamGameEventsRequest, stream pb.QuizService_StreamGameEventsServer) error {
	userID, err := auth.UserIDFromContext(stream.Context())
	if err != nil {
		return status.Error(codes.Unauthenticated, "not authenticated")
	}

	if err := s.requireRoomMember(stream.Context(), req.RoomId, userID, "stream"); err != nil {
		return err
	}

	streamKey := req.RoomId + ":" + userID
	ch := make(chan *pb.GameEvent, 20)
	s.gameStreams.Store(streamKey, ch)
	defer func() {
		s.gameStreams.Delete(streamKey)
		close(ch)

		// Section 7.2: handle player disconnect.
		// stream.Context() is cancelled the moment the player disconnects,
		// so we use log.DetachContext to inherit the request_id (and any
		// ctx attrs) for log correlation while running cleanup on a fresh
		// background lifecycle that survives the cancellation.
		remaining := s.connectedPlayersInRoom(req.RoomId)
		bgCtx := log.DetachContext(stream.Context())

		if remaining == 0 {
			log.FromContext(bgCtx).Info("zero connected players; ending match", "room_id", req.RoomId)
			s.cancelRoomTimer(req.RoomId)
			if _, ok := s.getRoomQuestions(req.RoomId); ok {
				s.finishMatch(bgCtx, req.RoomId, 0)
			}
		} else if remaining == 1 {
			log.FromContext(bgCtx).Info("opponent left; ending match", "room_id", req.RoomId)
			s.cancelRoomTimer(req.RoomId)
			if _, ok := s.getRoomQuestions(req.RoomId); ok {
				s.finishMatch(bgCtx, req.RoomId, -1) // -1 signals opponent abandoned
			}
		} else {
			log.FromContext(bgCtx).Info("player disconnected",
				"room_id", req.RoomId, "user_id", userID, "remaining", remaining)
		}
	}()

	log.FromContext(stream.Context()).Info("player streaming game events", "room_id", req.RoomId, "user_id", userID)

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
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if err := s.requireRoomMember(ctx, req.RoomId, userID, "questions"); err != nil {
		return nil, err
	}

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

	// §4.7 PR-B2: input validation. Each field has a tight expected
	// shape — reject obviously bad values at the handler boundary so
	// they never hit Redis lookup / scoring math.
	//
	// roomId is generated by matchmaking / friends.ChallengeFriend as a
	// UUID, but the test bed and integration harnesses use shorter
	// labels ("r1", "test-room"); bound the length rather than enforce
	// a strict UUID shape so the gate stays meaningful for production
	// while not breaking the test surface.
	if req.RoomId == "" {
		return nil, status.Error(codes.InvalidArgument, "roomId required")
	}
	if err := validate.MaxLen(req.RoomId, 128); err != nil {
		return nil, status.Error(codes.InvalidArgument, "roomId is too long")
	}
	if req.Round < 1 || req.Round > 100 {
		// Tournaments cap at 10 rounds; the upper bound is a sanity
		// fence so a forged round=999_999 doesn't reach the per-round
		// Redis key path with a pathological size argument.
		return nil, status.Error(codes.InvalidArgument, "round must be between 1 and 100")
	}
	if req.OptionIndex < 0 || req.OptionIndex > 3 {
		// All questions are 4-option multiple choice. A negative or
		// out-of-range index would write to a non-existent answer slot;
		// rejecting here keeps Redis state clean.
		return nil, status.Error(codes.InvalidArgument, "optionIndex must be between 0 and 3")
	}

	// §4.7 PR-B1: anti-flood gate. Subject is userID — per-user, not
	// per-room — so a script that opens many rooms can't multiply its
	// answer rate by spawning more matches. The downstream
	// answer.submitted event publish is cheap individually, but a
	// torrent of them swamps the answer-processing-queue and Redis.
	if !s.answerLimiter.AllowWithLog(ctx, userID) {
		return nil, status.Error(codes.ResourceExhausted, "too many answer submissions; slow down")
	}

	// Room-scoping gate: reject answers from anyone not in this room's
	// player hash. Without this, an authenticated user who learned a
	// roomID could feed answers into someone else's match — the scoring
	// service would publish leaderboard.updated with their score, and
	// the legitimate players would see a third "ghost" entry.
	if err := s.requireRoomMember(ctx, req.RoomId, userID, "submit"); err != nil {
		return nil, err
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

	log.FromContext(ctx).Info("answer submitted", "user_id", userID, "room_id", req.RoomId, "round", req.Round, "option_index", req.OptionIndex)
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
	ctx = log.ContextWithAttrs(ctx, "worker", "tournament_reminder")
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
				log.FromContext(ctx).Info("tournament reminder sent", "tournament_id", tourID, "participants", len(userIDs))
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
	ctx = log.ContextWithAttrs(ctx, "worker", "tournament_finalize")
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
		log.FromContext(ctx).Error("promote upcoming→active failed", "err", err)
		return
	}
	if res.ModifiedCount > 0 {
		log.FromContext(ctx).Info("promoted tournaments to active", "count", res.ModifiedCount)
	}
}

func (s *quizServer) finalizeExpiredTournaments(ctx context.Context, now time.Time) {
	cursor, err := s.mongoDB.Collection("tournaments").Find(ctx, bson.M{
		"status":         bson.M{"$in": []string{"upcoming", "active"}},
		"endTime":        bson.M{"$lte": now},
		"winnersAwarded": false,
	})
	if err != nil {
		log.FromContext(ctx).Error("tournament lookup failed", "err", err)
		return
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var t models.Tournament
		if err := cursor.Decode(&t); err != nil {
			log.FromContext(ctx).Error("tournament decode failed", "err", err)
			continue
		}

		// Three-phase finalize, ordered specifically so any partial failure
		// leaves the tournament eligible for a clean retry on the next tick:
		//
		//   Phase 1 — persist payouts. $setOnInsert on (tournamentId, userId)
		//             is idempotent both for re-runs after a crash and for
		//             two parallel finalizers racing on the same tournament.
		//             Any error here aborts BEFORE the flip, so the
		//             tournament keeps winnersAwarded=false and the next
		//             tick re-enters from scratch.
		//
		//   Phase 2 — atomic claim flip. The race guard between parallel
		//             finalizers — both finished phase 1 (idempotently),
		//             only one wins this UpdateOne and proceeds to publish.
		//             The loser sees ModifiedCount=0 and skips: its phase 1
		//             work was the same upserts the winner just did, so no
		//             harm done.
		//
		//   Phase 3 — immediate publish from the in-memory list built in
		//             phase 1. Failures here leave individual rows in
		//             status="pending"; the drain worker (1-min tick) keeps
		//             re-publishing them until they succeed.
		//
		// Earlier ordering (flip → standings query → write+publish) had a
		// durability gap: a Mongo error between the flip and the payout
		// write would strand the tournament with winnersAwarded=true and
		// zero payout rows, invisible to both the next finalize tick (filter
		// excludes it) and the drain worker (no rows to find).

		// Build winner cap. When prizePool is empty we still emit a
		// finished event for every participant with zero coins so they get
		// the closing notification. If neither is populated (admin error or
		// fully unattended tournament), there's nothing to publish — skip.
		topN := len(t.PrizePool)
		if topN == 0 {
			topN = len(t.Participants)
		}
		if topN == 0 {
			// Nothing to pay out. Still flip so the row drops out of the
			// finalize filter — otherwise we'd re-cursor it every minute.
			// Mongo errors are non-fatal: next tick re-attempts the flip,
			// the cost is just a noisy log line per tick until it succeeds.
			if _, err := s.mongoDB.Collection("tournaments").UpdateOne(ctx,
				bson.M{"_id": t.ID, "winnersAwarded": false},
				bson.M{"$set": bson.M{"winnersAwarded": true, "status": "completed"}},
			); err != nil {
				log.FromContext(ctx).Error("empty-payout flip failed", "tournament_id", t.ID, "err", err)
				continue
			}
			log.FromContext(ctx).Info("tournament closed; no participants and no prize pool", "tournament_id", t.ID)
			continue
		}

		// Phase 1: pull standings sorted by score desc, capped at topN, and
		// persist each as a pending payout. Build the in-memory list as we
		// go for phase 3.
		findOpts := options.Find().SetSort(bson.M{"score": -1}).SetLimit(int64(topN))
		standingsCursor, err := s.mongoDB.Collection("tournament_standings").Find(ctx,
			bson.M{"tournamentId": t.ID},
			findOpts,
		)
		if err != nil {
			log.FromContext(ctx).Error("standings lookup failed", "tournament_id", t.ID, "err", err)
			continue
		}

		payouts := make([]models.TournamentPayout, 0, topN)
		writeFailed := false
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

			payout := models.TournamentPayout{
				TournamentID:   t.ID,
				TournamentName: t.Name,
				UserID:         st.UserID,
				Username:       st.Username,
				Rank:           rank,
				CoinsAwarded:   coins,
				FinalScore:     st.Score,
				Status:         "pending",
				CreatedAt:      now,
			}
			if _, err := s.mongoDB.Collection("tournament_payouts").UpdateOne(ctx,
				bson.M{"tournamentId": t.ID, "userId": st.UserID},
				bson.M{"$setOnInsert": bson.M{
					"tournamentId":   payout.TournamentID,
					"tournamentName": payout.TournamentName,
					"userId":         payout.UserID,
					"username":       payout.Username,
					"rank":           payout.Rank,
					"coinsAwarded":   payout.CoinsAwarded,
					"finalScore":     payout.FinalScore,
					"status":         payout.Status,
					"createdAt":      payout.CreatedAt,
				}},
				options.UpdateOne().SetUpsert(true),
			); err != nil {
				// Fail loud and abort this tournament. winnersAwarded stays
				// false, so the next tick re-runs phase 1 from scratch —
				// $setOnInsert no-ops the rows that already landed and
				// inserts the missing ones.
				log.FromContext(ctx).Error("payout upsert failed; aborting (will retry next tick)",
					"tournament_id", t.ID, "user_id", st.UserID, "err", err)
				writeFailed = true
				break
			}
			payouts = append(payouts, payout)
		}
		standingsCursor.Close(ctx)

		if writeFailed {
			continue
		}

		// Phase 2: atomic claim flip. Loser of a parallel race sees
		// ModifiedCount=0; the winner is the publisher of record.
		res, err := s.mongoDB.Collection("tournaments").UpdateOne(ctx,
			bson.M{"_id": t.ID, "winnersAwarded": false},
			bson.M{"$set": bson.M{"winnersAwarded": true, "status": "completed"}},
		)
		if err != nil {
			log.FromContext(ctx).Error("claim flip failed; payouts persisted, will retry on next tick",
				"tournament_id", t.ID, "err", err)
			continue
		}
		if res.ModifiedCount == 0 {
			// Parallel finalizer already won the claim and is responsible
			// for publishing. Our phase 1 was idempotent so no inconsistency.
			continue
		}

		// Phase 3: publish from the persisted set.
		for _, p := range payouts {
			s.publishTournamentPayout(ctx, p)
		}

		log.FromContext(ctx).Info("finalized tournament",
			"tournament_id", t.ID, "tournament_name", t.Name, "payouts", rank)
	}
}

// publishTournamentPayout fires one tournament.finished event for a single
// payout row and flips its status from "pending" to "published" on
// successful publish. Used by both the immediate-publish path in
// finalizeExpiredTournaments and the drain worker's retry path.
//
// Idempotency on the consumer side is the scoring service's check-then-set
// transition (status:{$ne:"paid"} → "paid"). Re-publishing the same payout
// is therefore safe; this function leaves the row as "pending" if publish
// fails, ensuring the drain worker retries.
func (s *quizServer) publishTournamentPayout(ctx context.Context, p models.TournamentPayout) {
	payload, _ := json.Marshal(map[string]interface{}{
		"event":          "tournament.finished",
		"tournamentId":   p.TournamentID,
		"tournamentName": p.TournamentName,
		"userId":         p.UserID,
		"username":       p.Username,
		"rank":           p.Rank,
		"coinsAwarded":   p.CoinsAwarded,
		"finalScore":     p.FinalScore,
	})
	if err := s.publish(ctx, "tournament.finished", payload); err != nil {
		log.FromContext(ctx).Error("tournament.finished publish failed",
			"tournament_id", p.TournamentID, "user_id", p.UserID, "err", err)
		return
	}

	// Status flip is best-effort breadcrumb for the drain worker. The
	// consumer-side transition on tournament_payouts.status is what
	// actually drives coin grants, so even if this UpdateOne fails the
	// pipeline still works — at worst the drain worker re-publishes a
	// message the consumer already handled, which is a no-op due to
	// the {$ne:"paid"} guard.
	publishedAt := time.Now()
	if _, err := s.mongoDB.Collection("tournament_payouts").UpdateOne(ctx,
		bson.M{"tournamentId": p.TournamentID, "userId": p.UserID, "status": "pending"},
		bson.M{"$set": bson.M{"status": "published", "publishedAt": publishedAt}},
	); err != nil {
		log.FromContext(ctx).Warn("payout publish-flag update failed",
			"tournament_id", p.TournamentID, "user_id", p.UserID, "err", err)
	}
}

// tournamentPayoutDrainWorker re-publishes any payout still in "pending"
// state. Drives the at-least-once delivery guarantee for tournament.finished
// events: if the immediate publish from finalizeExpiredTournaments failed
// (RabbitMQ blip, channel drop, broker overload), this worker keeps trying
// every minute until the row transitions to "published".
func (s *quizServer) tournamentPayoutDrainWorker(ctx context.Context) {
	ctx = log.ContextWithAttrs(ctx, "worker", "tournament_drain")
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.drainPendingPayouts(ctx)
		}
	}
}

// drainBatchSize bounds how many pending payouts a single drain tick will
// attempt. Without it, a multi-day RabbitMQ outage that stranded thousands
// of rows would blast the whole backlog through one publish-mutex'd channel
// on a single tick — likely timing out and saturating the broker on
// recovery. 500 is an arbitrary safe number; subsequent ticks pick up
// whatever the previous one didn't reach. Real exponential backoff per row
// (lastAttemptedAt + nextAttemptAt) is a follow-up.
const drainBatchSize = 500

func (s *quizServer) drainPendingPayouts(ctx context.Context) {
	cursor, err := s.mongoDB.Collection("tournament_payouts").Find(ctx,
		bson.M{"status": "pending"},
		options.Find().SetLimit(drainBatchSize),
	)
	if err != nil {
		log.FromContext(ctx).Error("pending payout lookup failed", "err", err)
		return
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var p models.TournamentPayout
		if err := cursor.Decode(&p); err != nil {
			log.FromContext(ctx).Error("payout decode failed", "err", err)
			continue
		}
		s.publishTournamentPayout(ctx, p)
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
	ctx = log.ContextWithAttrs(ctx, "worker", "weekly_tournament")
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

	// Compute the initial status at write time. Without this, a quiz
	// service restart inside the active window (e.g. Sat 19:00 IST when
	// startTime was Sat 18:00 IST) would create a fresh tournament doc
	// with status="upcoming" — the standings updater filters on
	// status="active", so any matches played in the gap before
	// promoteUpcomingTournaments fires (~1 min later) would silently
	// fail to score against this tournament.
	initialStatus := "upcoming"
	if !startTime.After(istNow) && endTime.After(istNow) {
		initialStatus = "active"
	}

	doc := models.Tournament{
		Name:             fmt.Sprintf("Weekly Open — %s", weekKey),
		StartTime:        startTime,
		EndTime:          endTime,
		EntryDeadline:    startTime,
		Status:           initialStatus,
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
		log.FromContext(ctx).Error("weekly tournament upsert failed", "week_key", weekKey, "err", err)
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
	ctx = log.ContextWithAttrs(ctx, "consumer", "round_completed")
	ch, err := s.newChannel()
	if err != nil {
		log.Fatal(ctx, "open channel failed", "err", err)
	}
	defer ch.Close()

	if err := ch.Qos(16, 0, false); err != nil {
		log.Fatal(ctx, "qos failed", "queue", "round-completed-queue", "err", err)
	}

	msgs, err := ch.Consume("round-completed-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatal(ctx, "consume failed", "queue", "round-completed-queue", "err", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			msgCtx := log.ContextFromDelivery(ctx, msg)

			var event struct {
				RoomID string `json:"roomId"`
				Round  int    `json:"round"`
			}
			if err := json.Unmarshal(msg.Body, &event); err != nil {
				log.FromContext(msgCtx).Warn("bad payload", "err", err)
				msg.Nack(false, false)
				s.recordConsume("round-complete-queue", metrics.StatusNackDrop)
				continue
			}

			questions, ok := s.getRoomQuestions(event.RoomID)
			if !ok {
				log.FromContext(msgCtx).Info("unknown room; skipping", "room_id", event.RoomID)
				msg.Ack(false)
				s.recordConsume("round-complete-queue", metrics.StatusAck)
				continue
			}

			msg.Ack(false)
			s.recordConsume("round-complete-queue", metrics.StatusAck)

			if event.Round < len(questions) {
				// Advance to next round after a 2s pause. Detach so the
				// goroutine has its own lifecycle but keeps the rid.
				go func(roomID string, nextRound int, parentCtx context.Context) {
					time.Sleep(2 * time.Second)
					s.startRound(parentCtx, roomID, nextRound)
				}(event.RoomID, event.Round+1, log.DetachContext(msgCtx))
			} else {
				// All rounds complete — finish match
				s.finishMatch(msgCtx, event.RoomID, event.Round)
			}
		}
	}
}

// ---------------------------------------------------------------------------
// consumeLeaderboardUpdated — relay scoring leaderboard events to game streams
// ---------------------------------------------------------------------------

func (s *quizServer) consumeLeaderboardUpdated(ctx context.Context) {
	ctx = log.ContextWithAttrs(ctx, "consumer", "leaderboard_broadcast")
	ch, err := s.newChannel()
	if err != nil {
		log.Fatal(ctx, "open channel failed", "err", err)
	}
	defer ch.Close()

	if err := ch.Qos(16, 0, false); err != nil {
		log.Fatal(ctx, "qos failed", "queue", "leaderboard-broadcast-queue", "err", err)
	}

	msgs, err := ch.Consume("leaderboard-broadcast-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatal(ctx, "consume failed", "queue", "leaderboard-broadcast-queue", "err", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			msgCtx := log.ContextFromDelivery(ctx, msg)

			var event struct {
				RoomID  string `json:"roomId"`
				Entries []struct {
					Member interface{} `json:"Member"`
					Score  float64     `json:"Score"`
				} `json:"entries"`
			}
			if err := json.Unmarshal(msg.Body, &event); err != nil {
				log.FromContext(msgCtx).Warn("bad payload", "err", err)
				msg.Nack(false, false)
				s.recordConsume("leaderboard-broadcast-queue", metrics.StatusNackDrop)
				continue
			}

			// Build LeaderboardUpdate GameEvent with resolved usernames + plan
			entries := make([]*pb.LeaderboardEntry, 0, len(event.Entries))
			for i, e := range event.Entries {
				userID := fmt.Sprintf("%v", e.Member)
				username := userID
				entryPlan := "free"
				if playerJSON, err := keys.GetPlayer(msgCtx, s.rdb, event.RoomID, userID); err == nil {
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

			log.FromContext(msgCtx).Info("LeaderboardUpdate broadcast", "room_id", event.RoomID, "entries", len(entries))
			msg.Ack(false)
			s.recordConsume("leaderboard-broadcast-queue", metrics.StatusAck)
		}
	}
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

func main() {
	slog.SetDefault(log.Init("quiz"))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	cfg := config.MustCommon(ctx)

	// Redis
	rdb := redis.NewClient(&redis.Options{Addr: cfg.RedisAddr})
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatal(ctx, "redis connect failed", "err", err)
	}
	log.FromContext(ctx).Info("connected to Redis")

	// RabbitMQ
	conn, err := amqp.Dial(cfg.RabbitMQURL)
	if err != nil {
		log.Fatal(ctx, "rabbitmq connect failed", "err", err)
	}

	amqpCh, err := conn.Channel()
	if err != nil {
		log.Fatal(ctx, "rabbitmq channel failed", "err", err)
	}

	if err := setupRabbitMQ(amqpCh); err != nil {
		log.Fatal(ctx, "rabbitmq setup failed", "err", err)
	}
	log.FromContext(ctx).Info("connected to RabbitMQ")

	// MongoDB
	mongoClient, err := mongo.Connect(options.Client().ApplyURI(cfg.MongoURI).SetBSONOptions(&options.BSONOptions{
		ObjectIDAsHexString: true,
	}))
	if err != nil {
		log.Fatal(ctx, "mongodb connect failed", "err", err)
	}
	log.FromContext(ctx).Info("connected to MongoDB")

	jwtSecret := config.MustRequired(ctx, "JWT_SECRET")

	// gRPC server
	srv := &quizServer{
		rdb:           rdb,
		amqpConn:      conn,
		amqpCh:        amqpCh,
		mongoDB:       mongoClient.Database("quizbattle"),
		jwtSecret:     jwtSecret,
		answerLimiter: ratelimit.New(rdb, "submit_answer", 60, time.Minute),
	}

	// Start RabbitMQ consumers + tournament workers
	go srv.consumeMatchCreated(ctx)
	go srv.consumeRoundCompleted(ctx)
	go srv.consumeLeaderboardUpdated(ctx)
	go srv.tournamentReminderTicker(ctx)
	go srv.tournamentFinalizationWorker(ctx) // Phase 3 (4.2): close expired tournaments
	go srv.tournamentPayoutDrainWorker(ctx)  // Phase 3 (4.2): retry stuck pending payouts
	go srv.weeklyTournamentCron(ctx)         // Phase 3 (4.2): spawn weekly free tournament

	m := metrics.New("quiz")
	metricsSrv := m.Serve(ctx, ":2112")
	srv.metrics = m

	grpcServer := grpc.NewServer(
		grpc.ChainUnaryInterceptor(
			log.UnaryServerInterceptor(),
			m.UnaryServerInterceptor(),
			auth.UnaryInterceptor(jwtSecret, nil),
		),
		grpc.ChainStreamInterceptor(
			log.StreamServerInterceptor(),
			m.StreamServerInterceptor(),
			auth.StreamInterceptor(jwtSecret, nil),
		),
	)
	pb.RegisterQuizServiceServer(grpcServer, srv)

	lis, err := net.Listen("tcp", ":50052")
	if err != nil {
		log.Fatal(ctx, "listen failed", "addr", ":50052", "err", err)
	}

	go func() {
		log.FromContext(ctx).Info("gRPC serving", "addr", ":50052")
		if err := grpcServer.Serve(lis); err != nil {
			log.FromContext(ctx).Error("grpc serve exited", "err", err)
		}
	}()

	lifecycle.WaitForSignal(ctx)
	log.FromContext(ctx).Info("graceful shutdown starting")

	cancel()
	grpcServer.GracefulStop()

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := metricsSrv.Shutdown(shutdownCtx); err != nil {
		log.FromContext(ctx).Warn("metrics shutdown", "err", err)
	}
	if err := amqpCh.Close(); err != nil {
		log.FromContext(ctx).Warn("amqp channel close", "err", err)
	}
	if err := conn.Close(); err != nil {
		log.FromContext(ctx).Warn("amqp conn close", "err", err)
	}
	if err := mongoClient.Disconnect(shutdownCtx); err != nil {
		log.FromContext(ctx).Warn("mongo disconnect", "err", err)
	}
	log.FromContext(ctx).Info("graceful shutdown complete")
}
