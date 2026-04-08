package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"google.golang.org/grpc"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/models"
	pb "quiz-battle/proto"
)

// ---------------------------------------------------------------------------
// Server struct
// ---------------------------------------------------------------------------

type matchmakingServer struct {
	pb.UnimplementedMatchmakingServiceServer
	rdb        *redis.Client
	amqpCh     *amqp.Channel
	mongoDB    *mongo.Database
	jwtSecret  string
	subscribers sync.Map // userId -> chan *pb.MatchEvent
	heartbeats  sync.Map // "roomId:userId" -> int64 (unix timestamp)
	seqCounter  atomic.Int64
}

// ---------------------------------------------------------------------------
// 35. JoinMatchmaking
// ---------------------------------------------------------------------------

func (s *matchmakingServer) JoinMatchmaking(ctx context.Context, req *pb.JoinMatchmakingRequest) (*pb.JoinMatchmakingResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, fmt.Errorf("auth: %w", err)
	}

	// Lookup rating from MongoDB
	var userDoc bson.M
	err = s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&userDoc)
	rating := float64(1200)
	if err == nil {
		if r, ok := userDoc["rating"].(int32); ok {
			rating = float64(r)
		}
	}

	// Duplicate check: ZSCORE returns the score if the member exists
	inPool, err := keys.IsInPool(ctx, s.rdb, userID)
	if err != nil {
		return nil, fmt.Errorf("redis error: %w", err)
	}
	if inPool {
		return &pb.JoinMatchmakingResponse{Status: pb.MatchmakingStatus_ALREADY_IN_QUEUE}, nil
	}

	// ZADD to matchmaking:pool with score = rating
	if err := keys.AddToPool(ctx, s.rdb, userID, rating); err != nil {
		return nil, fmt.Errorf("failed to add to pool: %w", err)
	}

	log.Printf("[matchmaking] player %s joined pool (rating=%.0f)", userID, rating)
	return &pb.JoinMatchmakingResponse{Status: pb.MatchmakingStatus_QUEUED}, nil
}

// ---------------------------------------------------------------------------
// 36. LeaveMatchmaking
// ---------------------------------------------------------------------------

func (s *matchmakingServer) LeaveMatchmaking(ctx context.Context, req *pb.LeaveMatchmakingRequest) (*pb.LeaveMatchmakingResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, fmt.Errorf("auth: %w", err)
	}

	if err := keys.RemoveFromPool(ctx, s.rdb, userID); err != nil {
		return nil, fmt.Errorf("failed to remove from pool: %w", err)
	}
	log.Printf("[matchmaking] player %s left pool", userID)
	return &pb.LeaveMatchmakingResponse{Removed: true}, nil
}

// ---------------------------------------------------------------------------
// 39. SubscribeToMatch — server-streaming RPC
// ---------------------------------------------------------------------------

func (s *matchmakingServer) SubscribeToMatch(req *pb.SubscribeToMatchRequest, stream pb.MatchmakingService_SubscribeToMatchServer) error {
	userID, err := auth.UserIDFromContext(stream.Context())
	if err != nil {
		return fmt.Errorf("auth: %w", err)
	}

	ch := make(chan *pb.MatchEvent, 10)
	// Close any existing subscription for this user (e.g. stale reconnect)
	if old, loaded := s.subscribers.LoadAndDelete(userID); loaded {
		close(old.(chan *pb.MatchEvent))
	}
	s.subscribers.Store(userID, ch)
	defer s.subscribers.Delete(userID)

	log.Printf("[matchmaking] player %s subscribed to match events", userID)

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
// 37. Background poller — runs every 500ms
// ---------------------------------------------------------------------------

func (s *matchmakingServer) startPoller(ctx context.Context) {
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.tryCreateRoom(ctx)
		}
	}
}

func (s *matchmakingServer) tryCreateRoom(ctx context.Context) {
	// ZCARD check — need at least 2 players
	poolSize, err := keys.PoolSize(ctx, s.rdb)
	if err != nil {
		log.Printf("[matchmaking] pool size error: %v", err)
		return
	}
	if poolSize < 2 {
		return
	}

	// Pop 2-10 players from pool (lowest rating first for balanced matches)
	count := poolSize
	if count > 10 {
		count = 10
	}
	players, err := keys.PopPoolPlayers(ctx, s.rdb, count)
	if err != nil {
		log.Printf("[matchmaking] pop players error: %v", err)
		return
	}
	if len(players) < 2 {
		return
	}

	s.createRoom(ctx, players)
}

// ---------------------------------------------------------------------------
// 38. Room creation — distributed lock + MULTI/EXEC + publish match.created
// ---------------------------------------------------------------------------

func (s *matchmakingServer) createRoom(ctx context.Context, players []redis.Z) {
	roomID := uuid.New().String()

	// Acquire distributed lock to prevent race conditions
	locked, err := keys.AcquireRoomLock(ctx, s.rdb, roomID)
	if err != nil || !locked {
		// Put players back in pool if we can't lock
		for _, p := range players {
			s.rdb.ZAdd(ctx, keys.MatchmakingPool, p)
		}
		return
	}
	defer keys.ReleaseRoomLock(ctx, s.rdb, roomID)

	// Build player IDs and player info map
	playerIDs := make([]string, 0, len(players))
	for _, p := range players {
		playerIDs = append(playerIDs, p.Member.(string))
	}

	// Atomic MULTI/EXEC: write room:{id}:players, room:{id}:state, room:{id}:round
	pipe := s.rdb.TxPipeline()
	now := time.Now().Unix()

	// room:{id}:players hash
	for _, p := range players {
		userID := p.Member.(string)
		info := models.PlayerInfo{
			UserID:   userID,
			Username: userID, // username resolved later by client
			Rating:   int32(p.Score),
		}
		infoJSON, _ := json.Marshal(info)
		pipe.HSet(ctx, keys.Players(roomID), userID, string(infoJSON))
	}
	pipe.Expire(ctx, keys.Players(roomID), keys.RoomTTL)

	// room:{id}:state
	state := models.RoomState{
		RoomID:    roomID,
		PlayerIDs: playerIDs,
		Status:    "waiting",
		Round:     0,
		CreatedAt: now,
	}
	stateJSON, _ := json.Marshal(state)
	pipe.Set(ctx, keys.State(roomID), string(stateJSON), keys.RoomTTL)

	// room:{id}:round
	pipe.Set(ctx, keys.Round(roomID), 0, keys.RoomTTL)

	if _, err := pipe.Exec(ctx); err != nil {
		log.Printf("[matchmaking] failed to write room keys: %v", err)
		// Put players back in pool
		for _, p := range players {
			s.rdb.ZAdd(ctx, keys.MatchmakingPool, p)
		}
		return
	}

	// Publish match.created to RabbitMQ sx exchange
	event := map[string]interface{}{
		"roomId":    roomID,
		"playerIds": playerIDs,
		"createdAt": now,
	}
	eventJSON, _ := json.Marshal(event)

	err = s.amqpCh.PublishWithContext(ctx,
		"sx",            // exchange
		"match.created", // routing key
		false,           // mandatory
		false,           // immediate
		amqp.Publishing{
			ContentType: "application/json",
			Body:        eventJSON,
		},
	)
	if err != nil {
		log.Printf("[matchmaking] failed to publish match.created: %v", err)
	}

	log.Printf("[matchmaking] room %s created with players %v", roomID, playerIDs)

	// Notify waiting subscribers
	seq := s.seqCounter.Add(1)
	matchEvent := &pb.MatchEvent{
		RoomId:         roomID,
		Players:        playerIDs,
		SequenceNumber: seq,
	}

	for _, userID := range playerIDs {
		if ch, ok := s.subscribers.Load(userID); ok {
			select {
			case ch.(chan *pb.MatchEvent) <- matchEvent:
			default:
				log.Printf("[matchmaking] channel full for player %s", userID)
			}
		}
	}
}

// ---------------------------------------------------------------------------
// Heartbeat tracking (section 7.2)
// ---------------------------------------------------------------------------

func (s *matchmakingServer) RecordHeartbeat(roomID, userID string) {
	key := roomID + ":" + userID
	s.heartbeats.Store(key, time.Now().Unix())
}

func (s *matchmakingServer) startHeartbeatChecker(ctx context.Context) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			now := time.Now().Unix()
			s.heartbeats.Range(func(key, value interface{}) bool {
				lastBeat := value.(int64)
				if now-lastBeat > 15 {
					k := key.(string)
					s.heartbeats.Delete(key)

					// Parse roomId:userId
					var roomID, userID string
					for i := len(k) - 1; i >= 0; i-- {
						if k[i] == ':' {
							roomID = k[:i]
							userID = k[i+1:]
							break
						}
					}
					if roomID == "" || userID == "" {
						return true
					}

					log.Printf("[heartbeat] player %s disconnected from room %s", userID, roomID)

					// Mark player as disconnected in room:{id}:players hash
					playerJSON, err := keys.GetPlayer(ctx, s.rdb, roomID, userID)
					if err == nil && playerJSON != "" {
						var info models.PlayerInfo
						if json.Unmarshal([]byte(playerJSON), &info) == nil {
							info.Username = info.Username + " (disconnected)"
							updatedJSON, _ := json.Marshal(info)
							keys.SetPlayer(ctx, s.rdb, roomID, userID, string(updatedJSON))
						}
					}

					// Broadcast PlayerLeft GameEvent to remaining subscribers
					// (This will be consumed by StreamGameEvents in the quiz service)
				}
				return true
			})
		}
	}
}

// ---------------------------------------------------------------------------
// RabbitMQ setup — declare sx exchange and match-created-queue
// ---------------------------------------------------------------------------

func setupRabbitMQ(ch *amqp.Channel) error {
	// Declare topic exchange "sx"
	if err := ch.ExchangeDeclare("sx", "topic", true, false, false, false, nil); err != nil {
		return fmt.Errorf("exchange declare: %w", err)
	}

	// Declare match-created-queue bound to match.created
	_, err := ch.QueueDeclare("match-created-queue", true, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("queue declare: %w", err)
	}

	if err := ch.QueueBind("match-created-queue", "match.created", "sx", false, nil); err != nil {
		return fmt.Errorf("queue bind: %w", err)
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
	log.Println("[matchmaking] connected to Redis")

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
	log.Println("[matchmaking] connected to RabbitMQ")

	// MongoDB
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017/quizbattle"
	}
	mongoClient, err := mongo.Connect(options.Client().ApplyURI(mongoURI).SetBSONOptions(&options.BSONOptions{
		ObjectIDAsHexString: true,
	}))
	if err != nil {
		log.Fatalf("mongo connect failed: %v", err)
	}
	mongoDB := mongoClient.Database("quizbattle")
	log.Println("[matchmaking] connected to MongoDB")

	// JWT secret
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "quiz-battle-dev-secret"
	}

	// gRPC server
	srv := &matchmakingServer{
		rdb:       rdb,
		amqpCh:    amqpCh,
		mongoDB:   mongoDB,
		jwtSecret: jwtSecret,
	}

	// Start background goroutines
	go srv.startPoller(ctx)
	go srv.startHeartbeatChecker(ctx)

	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(auth.UnaryInterceptor(jwtSecret, nil)),
		grpc.StreamInterceptor(auth.StreamInterceptor(jwtSecret, nil)),
	)
	pb.RegisterMatchmakingServiceServer(grpcServer, srv)

	lis, err := net.Listen("tcp", ":50051")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	log.Println("[matchmaking] serving on :50051")
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
