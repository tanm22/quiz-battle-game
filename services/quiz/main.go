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
	amqpCh       *amqp.Channel
	mongoDB      *mongo.Database
	gameStreams  sync.Map // "roomId:userId" -> chan *pb.GameEvent
	roomTimers  sync.Map // roomId -> *time.Timer (for round close)
	seqCounters sync.Map // roomId -> *atomic.Int64
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

	// Weighted distribution: 30% easy (2), 50% medium (2), 20% hard (1) = 5 questions
	counts := map[string]int{"easy": 2, "medium": 2, "hard": 1}

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
	msgs, err := s.amqpCh.Consume("match-created-queue", "", false, false, false, false, nil)
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

// In-memory question cache per room
var roomQuestions sync.Map // roomId -> []Question

func (s *quizServer) storeRoomQuestions(roomID string, questions []Question) {
	roomQuestions.Store(roomID, questions)
}

func (s *quizServer) getRoomQuestions(roomID string) ([]Question, bool) {
	val, ok := roomQuestions.Load(roomID)
	if !ok {
		return nil, false
	}
	return val.([]Question), true
}

// ---------------------------------------------------------------------------
// 43. startRound — broadcast QuestionBroadcast with absolute Unix deadline
// ---------------------------------------------------------------------------

func (s *quizServer) startRound(ctx context.Context, roomID string, round int) {
	questions, ok := s.getRoomQuestions(roomID)
	if !ok || round > len(questions) {
		// All rounds complete — publish match.finished
		s.finishMatch(ctx, roomID, len(questions))
		return
	}

	q := questions[round-1]
	deadlineUnix := time.Now().Add(15 * time.Second).Unix()

	log.Printf("[quiz] room %s starting round %d — question: %s", roomID, round, q.Text)

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
	roundEvent, _ := json.Marshal(map[string]interface{}{
		"roomId": roomID,
		"round":  round,
	})
	s.amqpCh.PublishWithContext(ctx, "sx", "round.completed", false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        roundEvent,
	})

	// Advance to next round after 2s pause, or finish match
	if round < len(questions) {
		time.AfterFunc(2*time.Second, func() {
			s.startRound(ctx, roomID, round+1)
		})
	} else {
		s.finishMatch(ctx, roomID, round)
	}
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
		playerResults = append(playerResults, &pb.PlayerResult{
			UserId:     userID,
			Username:   userID,
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
	finishEvent, _ := json.Marshal(map[string]interface{}{
		"roomId":    roomID,
		"winner":    winner,
		"rounds":    totalRounds,
		"players":   playerResults,
	})
	s.amqpCh.PublishWithContext(ctx, "sx", "match.finished", false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        finishEvent,
	})

	// Cleanup in-memory state
	roomQuestions.Delete(roomID)
	s.seqCounters.Delete(roomID)
	s.roomTimers.Delete(roomID)
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
// StreamGameEvents — server-streaming RPC (section 4.1)
// ---------------------------------------------------------------------------

func (s *quizServer) StreamGameEvents(req *pb.StreamGameEventsRequest, stream pb.QuizService_StreamGameEventsServer) error {
	streamKey := req.RoomId + ":" + req.UserId
	ch := make(chan *pb.GameEvent, 20)
	s.gameStreams.Store(streamKey, ch)
	defer func() {
		s.gameStreams.Delete(streamKey)
		close(ch)
	}()

	log.Printf("[quiz] player %s streaming game events for room %s", req.UserId, req.RoomId)

	// Send current state snapshot for late joiners / reconnections
	if req.SequenceNumber > 0 {
		// Reconnection — replay from ring buffer would go here (section 6.3)
		log.Printf("[quiz] player %s reconnecting from seq %d", req.UserId, req.SequenceNumber)
	}

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
// 45. SubmitAnswer — publish to RabbitMQ, return ack immediately
// ---------------------------------------------------------------------------

func (s *quizServer) SubmitAnswer(ctx context.Context, req *pb.SubmitAnswerRequest) (*pb.SubmitAnswerResponse, error) {
	// Publish answer.submitted event to RabbitMQ — do not wait for scoring
	event, _ := json.Marshal(map[string]interface{}{
		"roomId":          req.RoomId,
		"userId":          req.UserId,
		"round":           req.Round,
		"optionIndex":     req.OptionIndex,
		"clientTimestamp": req.ClientTimestamp,
		"serverTimestamp": time.Now().UnixMilli(),
	})

	err := s.amqpCh.PublishWithContext(ctx, "sx", "answer.submitted", false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        event,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to publish answer: %w", err)
	}

	log.Printf("[quiz] answer from %s for room %s round %d option %d", req.UserId, req.RoomId, req.Round, req.OptionIndex)
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

	return nil
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
	mongoClient, err := mongo.Connect(options.Client().ApplyURI(mongoURI))
	if err != nil {
		log.Fatalf("mongodb connect failed: %v", err)
	}
	defer mongoClient.Disconnect(ctx)
	log.Println("[quiz] connected to MongoDB")

	// gRPC server
	srv := &quizServer{
		rdb:     rdb,
		amqpCh:  amqpCh,
		mongoDB: mongoClient.Database("quizbattle"),
	}

	// Start RabbitMQ consumer for match.created
	go srv.consumeMatchCreated(ctx)

	grpcServer := grpc.NewServer()
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
