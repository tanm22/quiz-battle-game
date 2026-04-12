package main

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"log"
	"net"
	"net/http"
	"os"
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

type paymentServer struct {
	pb.UnimplementedPaymentServiceServer
	rdb            *redis.Client
	amqpCh         *amqp.Channel
	mongoDB        *mongo.Database
	jwtSecret      string
	razorpayKeyID  string
	razorpaySecret string
	webhookSecret  string
}

// ---------------------------------------------------------------------------
// gRPC: CreateOrder
// ---------------------------------------------------------------------------

func (s *paymentServer) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) (*pb.CreateOrderResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	amount := int64(29900) // monthly default, in paise
	if req.PlanDuration == "yearly" {
		amount = 299900
	}

	// TODO CP-5: HTTP POST to Razorpay API to create order
	// For now, generate a stub order ID
	orderID := "order_stub_" + userID[:8]

	// Insert payment document
	_, err = s.mongoDB.Collection("payments").InsertOne(ctx, bson.M{
		"userId":          userID,
		"razorpayOrderId": orderID,
		"amount":          amount,
		"currency":        "INR",
		"status":          "created",
		"planDuration":    req.PlanDuration,
		"createdAt":       time.Now(),
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to create payment: %v", err)
	}

	return &pb.CreateOrderResponse{
		OrderId:  orderID,
		KeyId:    s.razorpayKeyID,
		Amount:   amount,
		Currency: "INR",
	}, nil
}

// ---------------------------------------------------------------------------
// gRPC: GetPlanStatus — reads MongoDB directly, bypasses Redis cache
// ---------------------------------------------------------------------------

func (s *paymentServer) GetPlanStatus(ctx context.Context, req *pb.GetPlanStatusRequest) (*pb.GetPlanStatusResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	var user bson.M
	if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
		return nil, status.Errorf(codes.NotFound, "user not found")
	}

	plan := "free"
	if p, ok := user["plan"].(string); ok {
		plan = p
	}
	var expiresAt int64
	if t, ok := user["planExpiresAt"].(time.Time); ok {
		expiresAt = t.Unix()
	}

	return &pb.GetPlanStatusResponse{Plan: plan, ExpiresAt: expiresAt}, nil
}

// ---------------------------------------------------------------------------
// gRPC: GetPaymentHistory
// ---------------------------------------------------------------------------

func (s *paymentServer) GetPaymentHistory(ctx context.Context, req *pb.GetPaymentHistoryRequest) (*pb.GetPaymentHistoryResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	limit := int64(req.Limit)
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	skip := int64(req.Offset)

	cursor, err := s.mongoDB.Collection("payments").Find(ctx,
		bson.M{"userId": userID},
		options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}}).SetLimit(limit).SetSkip(skip),
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "query failed: %v", err)
	}
	defer cursor.Close(ctx)

	var payments []*pb.PaymentRecord
	for cursor.Next(ctx) {
		var doc bson.M
		if err := cursor.Decode(&doc); err != nil {
			continue
		}
		rec := &pb.PaymentRecord{
			OrderId:      doc["razorpayOrderId"].(string),
			Amount:       doc["amount"].(int64),
			Currency:     doc["currency"].(string),
			Status:       doc["status"].(string),
			PlanDuration: doc["planDuration"].(string),
		}
		if t, ok := doc["createdAt"].(time.Time); ok {
			rec.CreatedAt = t.Unix()
		}
		payments = append(payments, rec)
	}

	return &pb.GetPaymentHistoryResponse{Payments: payments}, nil
}

// ---------------------------------------------------------------------------
// HTTP: Razorpay webhook handler
// ---------------------------------------------------------------------------

func (s *paymentServer) handleWebhook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Step 1: Read raw body BEFORE any JSON parsing (HMAC needs raw bytes)
	rawBody, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "failed to read body", http.StatusBadRequest)
		return
	}

	// Step 2: Verify HMAC-SHA256 signature
	sig := r.Header.Get("X-Razorpay-Signature")
	if !verifyRazorpaySignature(rawBody, sig, s.webhookSecret) {
		http.Error(w, "invalid signature", http.StatusBadRequest)
		return
	}

	// Step 3: Parse payload
	var payload struct {
		Event   string `json:"event"`
		Payload struct {
			Payment struct {
				Entity struct {
					ID      string `json:"id"`
					OrderID string `json:"order_id"`
					Status  string `json:"status"`
				} `json:"entity"`
			} `json:"payment"`
		} `json:"payload"`
	}
	if err := json.Unmarshal(rawBody, &payload); err != nil {
		http.Error(w, "invalid payload", http.StatusBadRequest)
		return
	}

	paymentID := payload.Payload.Payment.Entity.ID
	if paymentID == "" {
		http.Error(w, "missing payment ID", http.StatusBadRequest)
		return
	}

	// Step 4: SETNX idempotency check
	ctx := context.Background()
	isNew, err := keys.SetWebhookIdem(ctx, s.rdb, paymentID)
	if err != nil {
		log.Printf("[payment] idempotency check error: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if !isNew {
		// Duplicate webhook — return 200 silently
		w.WriteHeader(http.StatusOK)
		return
	}

	// Step 5: Update payment document
	orderID := payload.Payload.Payment.Entity.OrderID
	now := time.Now()
	s.mongoDB.Collection("payments").UpdateOne(ctx,
		bson.M{"razorpayOrderId": orderID},
		bson.M{"$set": bson.M{
			"status":            "captured",
			"razorpayPaymentId": paymentID,
			"webhookReceivedAt": now,
		}},
	)

	// Step 6: Look up userId from payment doc
	var payDoc bson.M
	if err := s.mongoDB.Collection("payments").FindOne(ctx, bson.M{"razorpayOrderId": orderID}).Decode(&payDoc); err != nil {
		log.Printf("[payment] payment doc not found for order %s: %v", orderID, err)
		w.WriteHeader(http.StatusOK) // still return 200 to Razorpay
		return
	}

	// Step 7: Publish payment.captured to RabbitMQ
	eventJSON, err := json.Marshal(map[string]interface{}{
		"event":        "payment.captured",
		"userId":       payDoc["userId"],
		"paymentId":    paymentID,
		"orderId":      orderID,
		"amount":       payDoc["amount"],
		"planDuration": payDoc["planDuration"],
		"timestamp":    now.Format(time.RFC3339),
	})
	if err == nil {
		s.amqpCh.PublishWithContext(ctx, "sx", "payment.captured", false, false, amqp.Publishing{
			ContentType: "application/json",
			Body:        eventJSON,
		})
	}

	log.Printf("[payment] webhook processed: payment %s order %s", paymentID, orderID)
	w.WriteHeader(http.StatusOK)
}

func verifyRazorpaySignature(rawBody []byte, sig, secret string) bool {
	if secret == "" || sig == "" {
		return false
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(rawBody)
	expected := hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(expected), []byte(sig))
}

// ---------------------------------------------------------------------------
// Background: Plan expiry worker (15-minute ticker)
// ---------------------------------------------------------------------------

func (s *paymentServer) planExpiryWorker(ctx context.Context) {
	ticker := time.NewTicker(15 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.checkExpiredPlans(ctx)
		}
	}
}

func (s *paymentServer) checkExpiredPlans(ctx context.Context) {
	cursor, err := s.mongoDB.Collection("users").Find(ctx, bson.M{
		"plan":          "premium",
		"planExpiresAt": bson.M{"$lt": time.Now()},
	})
	if err != nil {
		log.Printf("[payment] expiry query error: %v", err)
		return
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var user bson.M
		if err := cursor.Decode(&user); err != nil {
			continue
		}
		userID, ok := user["_id"].(string)
		if !ok {
			continue
		}

		// Downgrade to free
		s.mongoDB.Collection("users").UpdateOne(ctx,
			bson.M{"_id": userID},
			bson.M{"$set": bson.M{"plan": "free", "planExpiresAt": nil}},
		)
		// Invalidate Redis cache
		keys.DelPlan(ctx, s.rdb, userID)

		// Publish notification
		eventJSON, _ := json.Marshal(map[string]interface{}{
			"event":     "premium.expired",
			"userId":    userID,
			"timestamp": time.Now().Format(time.RFC3339),
		})
		s.amqpCh.PublishWithContext(ctx, "sx", "premium.expired", false, false, amqp.Publishing{
			ContentType: "application/json",
			Body:        eventJSON,
		})
		log.Printf("[payment] downgraded user %s from premium to free", userID)
	}
}

// ---------------------------------------------------------------------------
// RabbitMQ setup
// ---------------------------------------------------------------------------

func setupRabbitMQ(ch *amqp.Channel) error {
	if err := ch.ExchangeDeclare("sx", "topic", true, false, false, false, nil); err != nil {
		return err
	}

	// payment-success-queue bound to payment.*
	if _, err := ch.QueueDeclare("payment-success-queue", true, false, false, false, nil); err != nil {
		return err
	}
	if err := ch.QueueBind("payment-success-queue", "payment.*", "sx", false, nil); err != nil {
		return err
	}

	// premium-expiry-queue bound to premium.*
	if _, err := ch.QueueDeclare("premium-expiry-queue", true, false, false, false, nil); err != nil {
		return err
	}
	if err := ch.QueueBind("premium-expiry-queue", "premium.*", "sx", false, nil); err != nil {
		return err
	}

	return nil
}

// ---------------------------------------------------------------------------
// Main — dual gRPC + HTTP listener
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
	log.Println("[payment] connected to Redis")

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
	log.Println("[payment] connected to RabbitMQ")

	// MongoDB
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017/quizbattle"
	}
	mongoClient, err := mongo.Connect(options.Client().ApplyURI(mongoURI))
	if err != nil {
		log.Fatalf("mongo connect failed: %v", err)
	}
	defer mongoClient.Disconnect(ctx)
	log.Println("[payment] connected to MongoDB")

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "quiz-battle-dev-secret"
	}

	srv := &paymentServer{
		rdb:            rdb,
		amqpCh:         amqpCh,
		mongoDB:        mongoClient.Database("quizbattle"),
		jwtSecret:      jwtSecret,
		razorpayKeyID:  os.Getenv("RAZORPAY_KEY_ID"),
		razorpaySecret: os.Getenv("RAZORPAY_KEY_SECRET"),
		webhookSecret:  os.Getenv("RAZORPAY_WEBHOOK_SECRET"),
	}

	// Background: plan expiry worker
	go srv.planExpiryWorker(ctx)

	// gRPC server on :50055
	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(auth.UnaryInterceptor(jwtSecret, nil)),
		grpc.StreamInterceptor(auth.StreamInterceptor(jwtSecret, nil)),
	)
	pb.RegisterPaymentServiceServer(grpcServer, srv)

	grpcLis, err := net.Listen("tcp", ":50055")
	if err != nil {
		log.Fatalf("failed to listen on :50055: %v", err)
	}

	go func() {
		log.Println("[payment] gRPC serving on :50055")
		if err := grpcServer.Serve(grpcLis); err != nil {
			log.Fatalf("gRPC serve failed: %v", err)
		}
	}()

	// HTTP server on :8080 — webhook + health only
	mux := http.NewServeMux()
	mux.HandleFunc("/webhook/razorpay", srv.handleWebhook)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	log.Println("[payment] HTTP serving on :8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		log.Fatalf("HTTP serve failed: %v", err)
	}
}
