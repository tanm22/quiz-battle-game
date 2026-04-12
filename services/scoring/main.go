package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net"
	"os"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/keys"
	pb "quiz-battle/proto"
)

// ---------------------------------------------------------------------------
// Question document (for looking up correct answers)
// ---------------------------------------------------------------------------

type Question struct {
	ID           string   `bson:"_id,omitempty"`
	Text         string   `bson:"text"`
	Options      []string `bson:"options"`
	CorrectIndex int      `bson:"correctIndex"`
	Topic        string   `bson:"topic"`
}

// ---------------------------------------------------------------------------
// Server struct
// ---------------------------------------------------------------------------

type scoringServer struct {
	pb.UnimplementedScoringServiceServer
	rdb          *redis.Client
	amqpConn     *amqp.Connection
	amqpCh       *amqp.Channel // for publishing only
	mongoDB      *mongo.Database
	jwtSecret    string
	selfClient   pb.ScoringServiceClient // gRPC loopback client for CalculateScore
}

// newChannel creates a dedicated AMQP channel per consumer (channels are not thread-safe).
func (s *scoringServer) newChannel() (*amqp.Channel, error) {
	return s.amqpConn.Channel()
}

// ---------------------------------------------------------------------------
// 47. CalculateScore gRPC
// ---------------------------------------------------------------------------

func (s *scoringServer) CalculateScore(ctx context.Context, req *pb.CalculateScoreRequest) (*pb.CalculateScoreResponse, error) {
	// Look up correct answer from MongoDB
	correct, err := s.isCorrect(ctx, req.RoomId, int(req.Round), int(req.OptionIndex))
	if err != nil {
		return nil, fmt.Errorf("failed to check answer: %w", err)
	}

	// basePoints = 100 * (1 if correct, 0 if wrong)
	var basePoints float64
	if correct {
		basePoints = 100
	}

	// speedMultiplier: <5000ms → 1.5, >13000ms → 0.8, else 1.0
	speedMultiplier := 1.0
	if req.AnswerTimeMs < 5000 {
		speedMultiplier = 1.5
	} else if req.AnswerTimeMs > 13000 {
		speedMultiplier = 0.8
	}

	score := basePoints * speedMultiplier

	return &pb.CalculateScoreResponse{
		Score:           score,
		Correct:         correct,
		SpeedMultiplier: speedMultiplier,
	}, nil
}

// isCorrect looks up the question for a given room+round and checks the answer.
func (s *scoringServer) isCorrect(ctx context.Context, roomID string, round, optionIndex int) (bool, error) {
	// Get question ID from Redis list (0-indexed, round is 1-indexed)
	questionIDs, err := keys.GetQuestions(ctx, s.rdb, roomID)
	if err != nil || round < 1 || round > len(questionIDs) {
		return false, fmt.Errorf("question lookup failed: %w", err)
	}

	qID := questionIDs[round-1]

	// Look up correct index from MongoDB
	var q Question
	err = s.mongoDB.Collection("questions").FindOne(ctx, bson.M{"_id": qID}).Decode(&q)
	if err != nil {
		// Fallback: try with ObjectID
		objID, parseErr := bson.ObjectIDFromHex(qID)
		if parseErr != nil {
			return false, fmt.Errorf("invalid question ID %s: %w", qID, err)
		}
		err = s.mongoDB.Collection("questions").FindOne(ctx, bson.M{"_id": objID}).Decode(&q)
		if err != nil {
			return false, fmt.Errorf("question not found %s: %w", qID, err)
		}
	}

	return optionIndex == q.CorrectIndex, nil
}

// ---------------------------------------------------------------------------
// 51. GetLeaderboard gRPC — ZREVRANGE room:{id}:leaderboard 0 -1 WITHSCORES
// ---------------------------------------------------------------------------

func (s *scoringServer) GetLeaderboard(ctx context.Context, req *pb.GetLeaderboardRequest) (*pb.GetLeaderboardResponse, error) {
	entries, err := keys.GetLeaderboardEntries(ctx, s.rdb, req.RoomId)
	if err != nil {
		return nil, fmt.Errorf("leaderboard fetch failed: %w", err)
	}

	pbEntries := make([]*pb.LeaderboardEntry, len(entries))
	for i, e := range entries {
		userID := e.Member.(string)
		// Resolve real username from Redis player info
		username := userID
		if playerJSON, err := keys.GetPlayer(ctx, s.rdb, req.RoomId, userID); err == nil {
			var info struct {
				Username string `json:"username"`
			}
			if json.Unmarshal([]byte(playerJSON), &info) == nil && info.Username != "" {
				username = info.Username
			}
		}
		pbEntries[i] = &pb.LeaderboardEntry{
			UserId:   userID,
			Username: username,
			Score:    e.Score,
			Rank:     int32(i + 1),
		}
	}

	return &pb.GetLeaderboardResponse{Entries: pbEntries}, nil
}

// ---------------------------------------------------------------------------
// GetMatchHistory — returns past matches for the authenticated user
// ---------------------------------------------------------------------------

func (s *scoringServer) GetMatchHistory(ctx context.Context, req *pb.GetMatchHistoryRequest) (*pb.GetMatchHistoryResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, fmt.Errorf("auth: %w", err)
	}

	limit := int64(req.Limit)
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	skip := int64(req.Offset)
	if skip < 0 {
		skip = 0
	}

	coll := s.mongoDB.Collection("match_history")
	cursor, err := coll.Find(ctx,
		bson.M{"players.userId": userID},
		options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}}).SetLimit(limit).SetSkip(skip),
	)
	if err != nil {
		return nil, fmt.Errorf("query match_history: %w", err)
	}
	defer cursor.Close(ctx)

	var matches []*pb.MatchHistoryEntry
	for cursor.Next(ctx) {
		var doc struct {
			RoomID    string    `bson:"roomId"`
			Winner    string    `bson:"winner"`
			Rounds    int32     `bson:"rounds"`
			Duration  int64     `bson:"duration"`
			CreatedAt time.Time `bson:"createdAt"`
			Players   []struct {
				UserID            string  `bson:"userId"`
				Username          string  `bson:"username"`
				FinalScore        float64 `bson:"finalScore"`
				Rank              int32   `bson:"rank"`
				AnswersCorrect    int32   `bson:"answersCorrect"`
				AvgResponseTimeMs float64 `bson:"avgResponseTimeMs"`
			} `bson:"players"`
		}
		if err := cursor.Decode(&doc); err != nil {
			continue
		}

		players := make([]*pb.PlayerResult, len(doc.Players))
		for i, p := range doc.Players {
			players[i] = &pb.PlayerResult{
				UserId:            p.UserID,
				Username:          p.Username,
				FinalScore:        p.FinalScore,
				Rank:              p.Rank,
				AnswersCorrect:    p.AnswersCorrect,
				AvgResponseTimeMs: p.AvgResponseTimeMs,
			}
		}

		matches = append(matches, &pb.MatchHistoryEntry{
			RoomId:    doc.RoomID,
			Winner:    doc.Winner,
			Players:   players,
			Rounds:    doc.Rounds,
			Duration:  doc.Duration,
			CreatedAt: doc.CreatedAt.Unix(),
		})
	}

	return &pb.GetMatchHistoryResponse{Matches: matches}, nil
}

// ---------------------------------------------------------------------------
// 48. RabbitMQ consumer for answer-processing-queue
// ---------------------------------------------------------------------------

type answerMessage struct {
	RoomID          string `json:"roomId"`
	UserID          string `json:"userId"`
	Round           int    `json:"round"`
	OptionIndex     int    `json:"optionIndex"`
	ClientTimestamp int64  `json:"clientTimestamp"`
	ServerTimestamp int64  `json:"serverTimestamp"`
}

func (s *scoringServer) consumeAnswers(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[scoring] failed to open channel: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("answer-processing-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[scoring] failed to consume answer-processing-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			s.processAnswer(ctx, msg)
		}
	}
}

func (s *scoringServer) processAnswer(ctx context.Context, msg amqp.Delivery) {
	var answer answerMessage
	if err := json.Unmarshal(msg.Body, &answer); err != nil {
		log.Printf("[scoring] bad answer payload: %v", err)
		msg.Nack(false, false) // don't requeue malformed messages
		return
	}

	// Step 12/48: Idempotency check — HEXISTS room:{id}:answers:{round} {userId}
	exists, err := keys.HasAnswer(ctx, s.rdb, answer.RoomID, answer.Round, answer.UserID)
	if err != nil {
		log.Printf("[scoring] idempotency check error: %v", err)
		msg.Nack(false, true) // requeue for transient errors
		return
	}
	if exists {
		log.Printf("[scoring] duplicate answer from %s for room %s round %d — skipping", answer.UserID, answer.RoomID, answer.Round)
		msg.Ack(false) // ACK without processing
		return
	}

	// Call CalculateScore gRPC to compute the score (spec: must use gRPC, not in-process)
	answerTimeMs := answer.ServerTimestamp - answer.ClientTimestamp
	calcResp, err := s.selfClient.CalculateScore(ctx, &pb.CalculateScoreRequest{
		RoomId:      answer.RoomID,
		UserId:      answer.UserID,
		Round:       int32(answer.Round),
		OptionIndex: int32(answer.OptionIndex),
		AnswerTimeMs: answerTimeMs,
	})
	if err != nil {
		log.Printf("[scoring] CalculateScore gRPC error: %v", err)
		if getDeathCount(msg) >= 3 {
			msg.Nack(false, false)
		} else {
			msg.Nack(false, true)
		}
		return
	}

	correct := calcResp.Correct
	score := calcResp.Score

	// Record answer in Redis (for idempotency on future deliveries)
	answerJSON, err := json.Marshal(map[string]interface{}{
		"optionIndex":     answer.OptionIndex,
		"correct":         correct,
		"score":           score,
		"timestamp":       answer.ServerTimestamp,
		"clientTimestamp":  answer.ClientTimestamp,
	})
	if err != nil {
		log.Printf("[scoring] failed to marshal answer record: %v", err)
		msg.Nack(false, true)
		return
	}
	if err := keys.SetAnswer(ctx, s.rdb, answer.RoomID, answer.Round, answer.UserID, string(answerJSON)); err != nil {
		log.Printf("[scoring] failed to record answer: %v", err)
		msg.Nack(false, true)
		return
	}

	// Step 49: Update leaderboard via Lua script (atomic read-modify-write)
	entries, err := keys.UpdateLeaderboard(ctx, s.rdb, answer.RoomID, answer.UserID, score)
	if err != nil {
		log.Printf("[scoring] leaderboard update error: %v", err)
		msg.Nack(false, true)
		return
	}

	log.Printf("[scoring] %s scored %.0f in room %s round %d (correct=%v, speed=%.1fx)",
		answer.UserID, score, answer.RoomID, answer.Round, correct, calcResp.SpeedMultiplier)

	// Publish leaderboard.updated to RabbitMQ for real-time broadcast
	leaderboardEvent, _ := json.Marshal(map[string]interface{}{
		"roomId":  answer.RoomID,
		"entries": entries,
	})
	s.amqpCh.PublishWithContext(ctx, "sx", "leaderboard.updated", false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        leaderboardEvent,
	})

	msg.Ack(false)
}

// getDeathCount extracts the x-death count from message headers for DLQ routing.
func getDeathCount(msg amqp.Delivery) int {
	if msg.Headers == nil {
		return 0
	}
	xDeath, ok := msg.Headers["x-death"]
	if !ok {
		return 0
	}
	deaths, ok := xDeath.([]interface{})
	if !ok || len(deaths) == 0 {
		return 0
	}
	first, ok := deaths[0].(amqp.Table)
	if !ok {
		return 0
	}
	count, ok := first["count"]
	if !ok {
		return 0
	}
	switch v := count.(type) {
	case int64:
		return int(v)
	case int32:
		return int(v)
	default:
		return 0
	}
}

// ---------------------------------------------------------------------------
// 52-54. Persistence Worker — consumes match.finished, writes to MongoDB
// ---------------------------------------------------------------------------

type matchFinishedEvent struct {
	RoomID  string              `json:"roomId"`
	Winner  string              `json:"winner"`
	Rounds  int                 `json:"rounds"`
	Players []*pb.PlayerResult  `json:"players"`
}

func (s *scoringServer) consumeMatchFinished(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[persistence] failed to open channel: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("match-finished-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[persistence] failed to consume match-finished-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			s.persistMatch(ctx, msg)
		}
	}
}

func (s *scoringServer) persistMatch(ctx context.Context, msg amqp.Delivery) {
	var event matchFinishedEvent
	if err := json.Unmarshal(msg.Body, &event); err != nil {
		log.Printf("[persistence] bad match.finished payload: %v", err)
		msg.Nack(false, false)
		return
	}

	log.Printf("[persistence] persisting match %s", event.RoomID)

	// Build match_history document from room:{id}:leaderboard and room metadata
	entries, _ := keys.GetLeaderboardEntries(ctx, s.rdb, event.RoomID)

	// Compute per-player stats from answer records in Redis
	players := make([]bson.M, 0, len(entries))
	var winner string
	for i, e := range entries {
		userID := e.Member.(string)
		if i == 0 {
			winner = userID
		}

		// Look up real username from MongoDB
		username := userID
		var userDoc bson.M
		if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&userDoc); err == nil {
			if u, ok := userDoc["username"].(string); ok && u != "" {
				username = u
			}
		}

		// Tally answersCorrect and avgResponseTimeMs from per-round answer records
		var answersCorrect int
		var totalResponseMs int64
		var answeredRounds int
		for round := 1; round <= event.Rounds; round++ {
			answerJSON, err := s.rdb.HGet(ctx, keys.Answers(event.RoomID, round), userID).Result()
			if err != nil {
				continue
			}
			var rec struct {
				Correct         bool  `json:"correct"`
				Timestamp       int64 `json:"timestamp"`
				ClientTimestamp int64  `json:"clientTimestamp"`
			}
			if json.Unmarshal([]byte(answerJSON), &rec) == nil {
				answeredRounds++
				if rec.Correct {
					answersCorrect++
				}
				// responseTime = serverTimestamp - clientTimestamp
				if rec.Timestamp > 0 && rec.ClientTimestamp > 0 {
					totalResponseMs += rec.Timestamp - rec.ClientTimestamp
				}
			}
		}

		var avgResponseTimeMs float64
		if answeredRounds > 0 {
			avgResponseTimeMs = float64(totalResponseMs) / float64(answeredRounds)
		}

		players = append(players, bson.M{
			"userId":            userID,
			"username":          username,
			"finalScore":        e.Score,
			"rank":              i + 1,
			"answersCorrect":    answersCorrect,
			"avgResponseTimeMs": avgResponseTimeMs,
		})
	}
	if winner == "" {
		winner = event.Winner
	}

	// Compute duration in milliseconds from room state createdAt
	var durationMs int64
	stateJSON, err := keys.GetRoomState(ctx, s.rdb, event.RoomID)
	if err == nil {
		var state struct {
			CreatedAt int64 `json:"createdAt"`
		}
		if json.Unmarshal([]byte(stateJSON), &state) == nil && state.CreatedAt > 0 {
			durationMs = (time.Now().Unix() - state.CreatedAt) * 1000
		}
	}

	matchDoc := bson.M{
		"roomId":    event.RoomID,
		"players":   players,
		"rounds":    event.Rounds,
		"winner":    winner,
		"createdAt": time.Now(),
		"duration":  durationMs,
	}

	// Step 53: Upsert with $setOnInsert to prevent double-writes
	_, err = s.mongoDB.Collection("match_history").UpdateOne(
		ctx,
		bson.M{"roomId": event.RoomID},
		bson.M{"$setOnInsert": matchDoc},
		options.UpdateOne().SetUpsert(true),
	)
	if err != nil {
		log.Printf("[persistence] match_history upsert failed: %v", err)
		msg.Nack(false, true)
		return
	}

	// Step 54: Update user stats and Elo ratings
	// Elo formula: K=32, expected = 1/(1+10^((Rb-Ra)/400))
	// Winner gets +K*(1-expected), loser gets -K*expected
	usersColl := s.mongoDB.Collection("users")

	// Look up current ratings for Elo calculation
	ratings := make(map[string]float64)
	for _, e := range entries {
		userID := e.Member.(string)
		var userDoc bson.M
		if err := usersColl.FindOne(ctx, bson.M{"_id": userID}).Decode(&userDoc); err == nil {
			if r, ok := userDoc["rating"].(int32); ok {
				ratings[userID] = float64(r)
			} else {
				ratings[userID] = 1200
			}
		} else {
			ratings[userID] = 1200
		}
	}

	const K = 32.0
	winnerID := ""
	if len(entries) > 0 {
		winnerID = entries[0].Member.(string)
	}

	for _, e := range entries {
		userID := e.Member.(string)
		ra := ratings[userID]
		isWinner := userID == winnerID

		// Compute average expected score against all other players
		var totalExpected float64
		opponents := 0
		for _, other := range entries {
			otherID := other.Member.(string)
			if otherID == userID {
				continue
			}
			rb := ratings[otherID]
			expected := 1.0 / (1.0 + math.Pow(10, (rb-ra)/400.0))
			totalExpected += expected
			opponents++
		}
		if opponents == 0 {
			continue
		}
		avgExpected := totalExpected / float64(opponents)

		var actual float64
		if isWinner {
			actual = 1.0
		}
		delta := int32(math.Round(K * (actual - avgExpected)))

		update := bson.M{"$inc": bson.M{"matchesPlayed": 1, "rating": delta}}
		if isWinner {
			update["$inc"].(bson.M)["wins"] = 1
		}
		_, err := usersColl.UpdateOne(ctx, bson.M{"_id": userID}, update, options.UpdateOne().SetUpsert(true))
		if err != nil {
			log.Printf("[persistence] user update failed for %s: %v", userID, err)
		}
	}

	log.Printf("[persistence] match %s persisted — winner: %s, %d players", event.RoomID, winner, len(entries))
	msg.Ack(false)
}

// ---------------------------------------------------------------------------
// Analytics Worker — stub that logs match.finished payloads (section 9.6 note)
// ---------------------------------------------------------------------------

func (s *scoringServer) consumeAnalytics(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[analytics] failed to open channel: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("match-analytics-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[analytics] failed to consume match-analytics-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			log.Printf("[analytics] match.finished event: %s", string(msg.Body))
			msg.Ack(false)
		}
	}
}

// ---------------------------------------------------------------------------
// RabbitMQ setup
// ---------------------------------------------------------------------------

func setupRabbitMQ(ch *amqp.Channel) error {
	// Ensure sx exchange exists
	if err := ch.ExchangeDeclare("sx", "topic", true, false, false, false, nil); err != nil {
		return fmt.Errorf("exchange declare: %w", err)
	}

	// Bind leaderboard.updated for broadcasting (consumed by quiz service or directly)
	_, err := ch.QueueDeclare("leaderboard-updated-queue", true, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("leaderboard queue declare: %w", err)
	}
	if err := ch.QueueBind("leaderboard-updated-queue", "leaderboard.updated", "sx", false, nil); err != nil {
		return fmt.Errorf("leaderboard queue bind: %w", err)
	}

	// Phase 2: payment-success-queue (consumed by this service to upgrade plans)
	if _, err := ch.QueueDeclare("payment-success-queue", true, false, false, false, nil); err != nil {
		return fmt.Errorf("payment queue declare: %w", err)
	}
	if err := ch.QueueBind("payment-success-queue", "payment.*", "sx", false, nil); err != nil {
		return fmt.Errorf("payment queue bind: %w", err)
	}

	// Phase 2: referral-event-queue (consumed by this service to grant rewards)
	if _, err := ch.QueueDeclare("referral-event-queue", true, false, false, false, nil); err != nil {
		return fmt.Errorf("referral queue declare: %w", err)
	}
	if err := ch.QueueBind("referral-event-queue", "referral.*", "sx", false, nil); err != nil {
		return fmt.Errorf("referral queue bind: %w", err)
	}

	// Phase 2: push-notification-queue (this service publishes notif.* events)
	if _, err := ch.QueueDeclare("push-notification-queue", true, false, false, false, nil); err != nil {
		return fmt.Errorf("push-notification queue declare: %w", err)
	}
	if err := ch.QueueBind("push-notification-queue", "notif.#", "sx", false, nil); err != nil {
		return fmt.Errorf("push-notification queue bind: %w", err)
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
	log.Println("[scoring] connected to Redis")

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
	log.Println("[scoring] connected to RabbitMQ")

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
	log.Println("[scoring] connected to MongoDB")

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "quiz-battle-dev-secret"
	}

	srv := &scoringServer{
		rdb:       rdb,
		amqpConn:  conn,
		amqpCh:    amqpCh,
		mongoDB:   mongoClient.Database("quizbattle"),
		jwtSecret: jwtSecret,
	}

	// gRPC server
	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(auth.UnaryInterceptor(jwtSecret, nil)),
		grpc.StreamInterceptor(auth.StreamInterceptor(jwtSecret, nil)),
	)
	pb.RegisterScoringServiceServer(grpcServer, srv)

	lis, err := net.Listen("tcp", ":50053")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	// Start gRPC server in background, then set up self-client for CalculateScore
	go func() {
		log.Println("[scoring] serving on :50053")
		if err := grpcServer.Serve(lis); err != nil {
			log.Fatalf("failed to serve: %v", err)
		}
	}()

	// Create gRPC loopback client so the scoring worker calls CalculateScore via gRPC
	selfConn, err := grpc.NewClient("localhost:50053",
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		log.Fatalf("failed to create self-client: %v", err)
	}
	defer selfConn.Close()
	srv.selfClient = pb.NewScoringServiceClient(selfConn)

	// Start RabbitMQ consumers (3 goroutines)
	go srv.consumeAnswers(ctx)       // 9.5: answer scoring
	go srv.consumeMatchFinished(ctx) // 9.6: persistence worker
	go srv.consumeAnalytics(ctx)     // 9.6 note: analytics stub

	// Block forever (gRPC server runs in background goroutine)
	select {}
}
