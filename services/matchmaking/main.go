package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
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
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/lifecycle"
	"quiz-battle/pkg/log"
	"quiz-battle/pkg/metrics"
	"quiz-battle/pkg/models"
	pb "quiz-battle/proto"
)

// ---------------------------------------------------------------------------
// Server struct
// ---------------------------------------------------------------------------

type matchmakingServer struct {
	pb.UnimplementedMatchmakingServiceServer
	rdb         *redis.Client
	amqpCh      *amqp.Channel
	mongoDB     *mongo.Database
	jwtSecret   string
	subscribers sync.Map // userId -> chan *pb.MatchEvent
	seqCounter  atomic.Int64
	metrics     *metrics.Metrics // nil in tests; non-nil in main()
}

// ---------------------------------------------------------------------------
// 35. JoinMatchmaking
// ---------------------------------------------------------------------------

func (s *matchmakingServer) JoinMatchmaking(ctx context.Context, req *pb.JoinMatchmakingRequest) (*pb.JoinMatchmakingResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	// Lookup user from MongoDB (rating + plan)
	var userDoc bson.M
	err = s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&userDoc)
	rating := float64(1200)
	plan := "free"
	if err == nil {
		if r, ok := userDoc["rating"].(int32); ok {
			rating = float64(r)
		}
		if p, ok := userDoc["plan"].(string); ok && p != "" {
			plan = p
		}
	}

	// Phase 2: Daily quota gate — free users limited to 1 quiz/day
	if plan != "premium" {
		// Check Redis plan cache first, fall back to MongoDB value we already have
		cachedPlan, _ := keys.GetPlan(ctx, s.rdb, userID)
		if cachedPlan == "" {
			keys.SetPlan(ctx, s.rdb, userID, plan)
		} else {
			plan = cachedPlan
		}

		if plan != "premium" {
			allowed, err := keys.CheckQuota(ctx, s.rdb, userID, 1)
			if err != nil {
				return nil, status.Errorf(codes.Internal, "quota check failed: %v", err)
			}
			if !allowed {
				return nil, status.Error(codes.ResourceExhausted, "Daily quiz limit reached. Upgrade to Premium.")
			}
		}
	}

	// Duplicate check: ZSCORE returns the score if the member exists
	inPool, err := keys.IsInPool(ctx, s.rdb, userID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "redis error: %v", err)
	}
	if inPool {
		return &pb.JoinMatchmakingResponse{Status: pb.MatchmakingStatus_ALREADY_IN_QUEUE}, nil
	}

	// ZADD to matchmaking:pool with score = rating
	if err := keys.AddToPool(ctx, s.rdb, userID, rating); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to add to pool: %v", err)
	}

	// Fan out notif.match.invite to recent opponents (throttled per pair).
	// Runs asynchronously on a fresh ctx so the RPC can return immediately
	// and the Mongo/Rabbit work isn't cancelled when the caller disconnects.
	// A 10s deadline guards against a hung Mongo leaking the goroutine.
	inviterName := ""
	if u, ok := userDoc["username"].(string); ok {
		inviterName = u
	}
	go func(uid, uname string, r int64) {
		inviteCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		s.publishMatchInvite(inviteCtx, uid, uname, r)
	}(userID, inviterName, int64(rating))

	log.FromContext(ctx).Info("player joined pool", "user_id", userID, "rating", rating)
	return &pb.JoinMatchmakingResponse{Status: pb.MatchmakingStatus_QUEUED}, nil
}

// publishMatchInvite finds the inviter's last 5 opponents in match_history,
// dedupes them, applies a 30-minute per-pair throttle, and publishes a
// `notif.match.invite` event per eligible opponent. Errors are logged only —
// the caller's RPC must not be blocked by notification delivery.
func (s *matchmakingServer) publishMatchInvite(ctx context.Context, fromUserID, fromUsername string, fromRating int64) {
	if fromUsername == "" {
		fromUsername = "A player"
	}

	// Query the 5 most recent matches this user participated in.
	cursor, err := s.mongoDB.Collection("match_history").Find(ctx,
		bson.M{"players.userId": fromUserID},
		options.Find().
			SetSort(bson.D{{Key: "createdAt", Value: -1}}).
			SetLimit(5).
			SetProjection(bson.M{"players.userId": 1}),
	)
	if err != nil {
		log.FromContext(ctx).Error("match_history query failed", "user_id", fromUserID, "err", err)
		return
	}
	defer cursor.Close(ctx)

	seen := make(map[string]struct{})
	for cursor.Next(ctx) {
		var doc struct {
			Players []struct {
				UserID string `bson:"userId"`
			} `bson:"players"`
		}
		if err := cursor.Decode(&doc); err != nil {
			continue
		}
		for _, p := range doc.Players {
			if p.UserID == "" || p.UserID == fromUserID {
				continue
			}
			seen[p.UserID] = struct{}{}
		}
	}
	if err := cursor.Err(); err != nil {
		log.FromContext(ctx).Error("match_history cursor failed", "user_id", fromUserID, "err", err)
	}
	if len(seen) == 0 {
		return
	}

	for opponentID := range seen {
		ok, err := keys.TrySetMatchInviteThrottle(ctx, s.rdb, fromUserID, opponentID)
		if err != nil {
			log.FromContext(ctx).Error("match invite throttle check failed", "from_id", fromUserID, "to_id", opponentID, "err", err)
			continue
		}
		if !ok {
			// Throttled — a previous invite from this inviter to this opponent
			// is still within the 30-minute cooldown.
			continue
		}

		payload, err := json.Marshal(map[string]interface{}{
			"event":         "notif.match.invite",
			"userId":        opponentID,
			"inviterId":     fromUserID,
			"inviterName":   fromUsername,
			"inviterRating": fromRating,
		})
		if err != nil {
			log.FromContext(ctx).Error("match invite marshal failed", "err", err)
			continue
		}

		err = log.PublishWithContext(ctx,
			s.amqpCh,
			"sx",
			"notif.match.invite",
			false,
			false,
			amqp.Publishing{ContentType: "application/json", Body: payload},
		)
		if s.metrics != nil {
			s.metrics.RecordPublish("notif.match.invite", err)
		}
		if err != nil {
			log.FromContext(ctx).Error("match invite publish failed", "from_id", fromUserID, "to_id", opponentID, "err", err)
			continue
		}
		log.FromContext(ctx).Info("match invite queued", "from_id", fromUserID, "to_id", opponentID)
	}
}

// ---------------------------------------------------------------------------
// 36. LeaveMatchmaking
// ---------------------------------------------------------------------------

func (s *matchmakingServer) LeaveMatchmaking(ctx context.Context, req *pb.LeaveMatchmakingRequest) (*pb.LeaveMatchmakingResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	removed, err := keys.RemoveFromPool(ctx, s.rdb, userID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to remove from pool: %v", err)
	}

	// If we actually pulled the user out of the pool (removed > 0), they
	// cancelled before the poller could match them — no quiz was played,
	// so refund the daily-quota INCR we did back in JoinMatchmaking.
	// `removed == 0` means the poller already popped them into a room;
	// in that case the quota was "spent" on a real match and must stay.
	// RefundQuota is guarded to be a no-op for premium users (whose
	// counter was never incremented) and for stale-key edge cases.
	if removed > 0 {
		if refunded, rerr := keys.RefundQuota(ctx, s.rdb, userID); rerr != nil {
			log.FromContext(ctx).Error("quota refund failed", "user_id", userID, "err", rerr)
		} else if refunded {
			log.FromContext(ctx).Info("refunded daily quota on cancel", "user_id", userID)
		}
	}

	log.FromContext(ctx).Info("player left pool", "user_id", userID, "removed", removed)
	return &pb.LeaveMatchmakingResponse{Removed: removed > 0}, nil
}

// ---------------------------------------------------------------------------
// 39. SubscribeToMatch — server-streaming RPC
// ---------------------------------------------------------------------------

func (s *matchmakingServer) SubscribeToMatch(req *pb.SubscribeToMatchRequest, stream pb.MatchmakingService_SubscribeToMatchServer) error {
	userID, err := auth.UserIDFromContext(stream.Context())
	if err != nil {
		return status.Error(codes.Unauthenticated, "not authenticated")
	}

	ch := make(chan *pb.MatchEvent, 10)
	// Close any existing subscription for this user (e.g. stale reconnect)
	if old, loaded := s.subscribers.LoadAndDelete(userID); loaded {
		close(old.(chan *pb.MatchEvent))
	}
	s.subscribers.Store(userID, ch)
	defer s.subscribers.Delete(userID)

	log.FromContext(stream.Context()).Info("player subscribed to match events", "user_id", userID)

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
		log.FromContext(ctx).Error("pool size failed", "err", err)
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
		log.FromContext(ctx).Error("pop players failed", "err", err)
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

	// room:{id}:players hash — resolve real usernames from MongoDB
	for _, p := range players {
		userID := p.Member.(string)
		username := userID
		userPlan := "free"
		var userDoc bson.M
		if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&userDoc); err == nil {
			if u, ok := userDoc["username"].(string); ok && u != "" {
				username = u
			}
			if pl, ok := userDoc["plan"].(string); ok && pl != "" {
				userPlan = pl
			}
		}
		info := models.PlayerInfo{
			UserID:   userID,
			Username: username,
			Rating:   int32(p.Score),
			Plan:     userPlan,
		}
		infoJSON, err := json.Marshal(info)
		if err != nil {
			log.FromContext(ctx).Error("marshal player info failed", "err", err)
			continue
		}
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
	stateJSON, err := json.Marshal(state)
	if err != nil {
		log.FromContext(ctx).Error("marshal room state failed", "err", err)
		return
	}
	pipe.Set(ctx, keys.State(roomID), string(stateJSON), keys.RoomTTL)

	// room:{id}:round
	pipe.Set(ctx, keys.Round(roomID), 0, keys.RoomTTL)

	if _, err := pipe.Exec(ctx); err != nil {
		log.FromContext(ctx).Error("write room keys failed", "err", err)
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
	eventJSON, err := json.Marshal(event)
	if err != nil {
		log.FromContext(ctx).Error("marshal match.created event failed", "err", err)
		return
	}

	err = log.PublishWithContext(ctx,
		s.amqpCh,
		"sx",            // exchange
		"match.created", // routing key
		false,           // mandatory
		false,           // immediate
		amqp.Publishing{
			ContentType: "application/json",
			Body:        eventJSON,
		},
	)
	if s.metrics != nil {
		s.metrics.RecordPublish("match.created", err)
	}
	if err != nil {
		log.FromContext(ctx).Error("publish match.created failed", "err", err)
	}

	log.FromContext(ctx).Info("room created", "room_id", roomID, "player_ids", playerIDs)

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
				log.FromContext(ctx).Warn("channel full for player", "user_id", userID)
			}
		}
	}
}

// Note: Disconnect detection is handled by the quiz service via gRPC stream
// closure detection (defer block in StreamGameEvents). When all players
// disconnect, the match ends. When one player remains, they win by forfeit.

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
	slog.SetDefault(log.Init("matchmaking"))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Redis
	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: redisAddr})
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatal(ctx, "redis connect failed", "err", err)
	}
	log.FromContext(ctx).Info("connected to Redis")

	// RabbitMQ
	rabbitURL := os.Getenv("RABBITMQ_URL")
	if rabbitURL == "" {
		rabbitURL = "amqp://guest:guest@localhost:5672/"
	}
	conn, err := amqp.Dial(rabbitURL)
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
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017/quizbattle"
	}
	mongoClient, err := mongo.Connect(options.Client().ApplyURI(mongoURI).SetBSONOptions(&options.BSONOptions{
		ObjectIDAsHexString: true,
	}))
	if err != nil {
		log.Fatal(ctx, "mongodb connect failed", "err", err)
	}
	mongoDB := mongoClient.Database("quizbattle")
	log.FromContext(ctx).Info("connected to MongoDB")

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

	m := metrics.New("matchmaking")
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
	pb.RegisterMatchmakingServiceServer(grpcServer, srv)

	lis, err := net.Listen("tcp", ":50051")
	if err != nil {
		log.Fatal(ctx, "listen failed", "addr", ":50051", "err", err)
	}

	go func() {
		log.FromContext(ctx).Info("gRPC serving", "addr", ":50051")
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
