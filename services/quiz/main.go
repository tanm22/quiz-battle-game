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
	rdb          *redis.Client
	amqpConn     *amqp.Connection
	amqpCh       *amqp.Channel // for publishing only
	mongoDB      *mongo.Database
	jwtSecret    string
	gameStreams  sync.Map // "roomId:userId" -> chan *pb.GameEvent
	roomTimers  sync.Map // roomId -> *time.Timer (for round close)
	seqCounters sync.Map // roomId -> *atomic.Int64
	roomDeadlines  sync.Map // roomId -> int64 (current round deadline_unix)
	roomQuestions  sync.Map // roomId -> []Question
}

// newChannel creates a dedicated AMQP channel per consumer (channels are not thread-safe).
func (s *quizServer) newChannel() (*amqp.Channel, error) {
	return s.amqpConn.Channel()
}

func (s *quizServer) getSeqCounter(roomID string) *atomic.Int64 {
	val, _ := s.seqCounters.LoadOrStore(roomID, &atomic.Int64{})
	return val.(*atomic.Int64)
}

// ---------------------------------------------------------------------------
// 42. selectQuestions — weighted random pick from MongoDB
// ---------------------------------------------------------------------------

func (s *quizServer) selectQuestions(ctx context.Context) ([]Question, error) {
	coll := s.mongoDB.Collection("questions")

	// Weighted distribution: ~30% easy (1), ~50% medium (3), ~20% hard (1) = 5 questions
	counts := map[string]int{"easy": 1, "medium": 3, "hard": 1}

	var selected []Question
	var lastTopic string

	for _, diff := range []string{"easy", "medium", "hard"} {
		count := counts[diff]

		// Build filter: match difficulty, exclude last topic to prevent adjacent repeats
		filter := bson.M{"difficulty": diff}
		if lastTopic != "" {
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

			// Select questions and store in Redis
			questions, err := s.selectQuestions(ctx)
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
	if err := s.amqpCh.PublishWithContext(ctx, "sx", "round.completed", false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        roundEvent,
	}); err != nil {
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

	var winner string
	playerResults := make([]*pb.PlayerResult, 0, len(entries))
	for i, e := range entries {
		userID := e.Member.(string)
		if i == 0 {
			winner = userID
		}

		// Resolve real username from Redis player info or fall back to userId
		username := userID
		if playerJSON, err := keys.GetPlayer(ctx, s.rdb, roomID, userID); err == nil {
			var info struct {
				Username string `json:"username"`
			}
			if json.Unmarshal([]byte(playerJSON), &info) == nil && info.Username != "" {
				username = info.Username
			}
		}

		playerResults = append(playerResults, &pb.PlayerResult{
			UserId:     userID,
			Username:   username,
			FinalScore: e.Score,
			Rank:       int32(i + 1),
		})
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
		"roomId":    roomID,
		"winner":    winner,
		"rounds":    totalRounds,
		"players":   playerResults,
	})
	if err != nil {
		log.Printf("[quiz] failed to marshal match.finished: %v", err)
	} else if err := s.amqpCh.PublishWithContext(ctx, "sx", "match.finished", false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        finishEvent,
	}); err != nil {
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
			if playerJSON, err := keys.GetPlayer(ctx, s.rdb, roomID, userID); err == nil {
				var info struct {
					Username string `json:"username"`
				}
				if json.Unmarshal([]byte(playerJSON), &info) == nil && info.Username != "" {
					username = info.Username
				}
			}
			lbEntries = append(lbEntries, &pb.LeaderboardEntry{
				UserId:   userID,
				Username: username,
				Score:    e.Score,
				Rank:     int32(i + 1),
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
	if playerJSON, err := keys.GetPlayer(stream.Context(), s.rdb, req.RoomId, userID); err == nil {
		var info struct {
			Username string `json:"username"`
		}
		if json.Unmarshal([]byte(playerJSON), &info) == nil && info.Username != "" {
			username = info.Username
		}
	}
	seq := s.getSeqCounter(req.RoomId).Add(1)
	s.broadcastToRoom(req.RoomId, &pb.GameEvent{
		SequenceNumber: seq,
		Event: &pb.GameEvent_PlayerJoined{
			PlayerJoined: &pb.PlayerJoined{
				UserId:   userID,
				Username: username,
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

	if err := s.amqpCh.PublishWithContext(ctx, "sx", "answer.submitted", false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        eventPayload,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to publish answer: %v", err)
	}

	log.Printf("[quiz] answer from %s for room %s round %d option %d", userID, req.RoomId, req.Round, req.OptionIndex)
	return &pb.SubmitAnswerResponse{Accepted: true}, nil
}

// ---------------------------------------------------------------------------
// RabbitMQ setup — declare queues needed by downstream services
// ---------------------------------------------------------------------------

func setupRabbitMQ(ch *amqp.Channel) error {
	// Ensure sx exchange exists
	if err := ch.ExchangeDeclare("sx", "topic", true, false, false, false, nil); err != nil {
		return fmt.Errorf("exchange declare: %w", err)
	}

	// answer-processing-queue with DLQ (consumed by scoring service)
	_, err := ch.QueueDeclare("answer-processing-queue", true, false, false, false, amqp.Table{
		"x-dead-letter-exchange":  "",
		"x-dead-letter-routing-key": "answer-processing-dlq",
		"x-max-delivery-count":   3,
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

			// Build LeaderboardUpdate GameEvent with resolved usernames
			entries := make([]*pb.LeaderboardEntry, 0, len(event.Entries))
			for i, e := range event.Entries {
				userID := fmt.Sprintf("%v", e.Member)
				username := userID
				if playerJSON, err := keys.GetPlayer(ctx, s.rdb, event.RoomID, userID); err == nil {
					var info struct {
						Username string `json:"username"`
					}
					if json.Unmarshal([]byte(playerJSON), &info) == nil && info.Username != "" {
						username = info.Username
					}
				}
				entries = append(entries, &pb.LeaderboardEntry{
					UserId:   userID,
					Username: username,
					Score:    e.Score,
					Rank:     int32(i + 1),
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

	// Start RabbitMQ consumers
	go srv.consumeMatchCreated(ctx)
	go srv.consumeRoundCompleted(ctx)
	go srv.consumeLeaderboardUpdated(ctx)

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
