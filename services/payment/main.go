package main

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"sync"
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
	amqpConn       *amqp.Connection
	amqpMu         sync.Mutex   // AMQP channels are not thread-safe
	amqpCh         *amqp.Channel
	mongoDB        *mongo.Database
	jwtSecret      string
	razorpayKeyID  string
	razorpaySecret string
	webhookSecret  string
}

// publish sends a message to the topic exchange with mutex protection.
func (s *paymentServer) publish(ctx context.Context, routingKey string, body []byte) error {
	s.amqpMu.Lock()
	defer s.amqpMu.Unlock()
	return s.amqpCh.PublishWithContext(ctx, "sx", routingKey, false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        body,
	})
}

// ---------------------------------------------------------------------------
// gRPC: CreateOrder
// ---------------------------------------------------------------------------

func (s *paymentServer) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) (*pb.CreateOrderResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	if req.PlanDuration != "monthly" && req.PlanDuration != "yearly" {
		return nil, status.Error(codes.InvalidArgument, "plan_duration must be 'monthly' or 'yearly'")
	}

	amount := int64(29900) // monthly default, in paise
	if req.PlanDuration == "yearly" {
		amount = 299900
	}

	// Create order via Razorpay Orders API
	orderReqBody, _ := json.Marshal(map[string]interface{}{
		"amount":   amount,
		"currency": "INR",
		"receipt":  fmt.Sprintf("rcpt_%s_%d", userID[:8], time.Now().Unix()),
		"notes": map[string]string{
			"userId":       userID,
			"planDuration": req.PlanDuration,
		},
	})

	httpReq, err := http.NewRequestWithContext(ctx, "POST", "https://api.razorpay.com/v1/orders", bytes.NewReader(orderReqBody))
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to build request: %v", err)
	}
	httpReq.SetBasicAuth(s.razorpayKeyID, s.razorpaySecret)
	httpReq.Header.Set("Content-Type", "application/json")

	httpClient := &http.Client{Timeout: 10 * time.Second}
	resp, err := httpClient.Do(httpReq)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "razorpay API unreachable: %v", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		log.Printf("[payment] razorpay order creation failed (%d): %s", resp.StatusCode, string(respBody))
		return nil, status.Errorf(codes.Internal, "razorpay order creation failed (%d)", resp.StatusCode)
	}

	var rzpOrder struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(respBody, &rzpOrder); err != nil || rzpOrder.ID == "" {
		return nil, status.Error(codes.Internal, "invalid response from razorpay")
	}

	// Insert payment document
	_, err = s.mongoDB.Collection("payments").InsertOne(ctx, bson.M{
		"userId":          userID,
		"razorpayOrderId": rzpOrder.ID,
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
		OrderId:  rzpOrder.ID,
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
		rec := &pb.PaymentRecord{}
		if v, ok := doc["razorpayOrderId"].(string); ok {
			rec.OrderId = v
		}
		if v, ok := doc["amount"].(int64); ok {
			rec.Amount = v
		} else if v, ok := doc["amount"].(int32); ok {
			rec.Amount = int64(v)
		}
		if v, ok := doc["currency"].(string); ok {
			rec.Currency = v
		}
		if v, ok := doc["status"].(string); ok {
			rec.Status = v
		}
		if v, ok := doc["planDuration"].(string); ok {
			rec.PlanDuration = v
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

	// Step 1: Read raw body with 1 MB size cap (prevent memory exhaustion)
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	rawBody, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "request too large or unreadable", http.StatusRequestEntityTooLarge)
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

	// Step 4: Only process payment.captured events — acknowledge others silently
	if payload.Event != "payment.captured" {
		w.WriteHeader(http.StatusOK)
		return
	}

	paymentID := payload.Payload.Payment.Entity.ID
	if paymentID == "" {
		http.Error(w, "missing payment ID", http.StatusBadRequest)
		return
	}

	// Step 5: SETNX idempotency check
	ctx := context.Background()
	isNew, err := keys.SetWebhookIdem(ctx, s.rdb, paymentID)
	if err != nil {
		log.Printf("[payment] idempotency check error: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if !isNew {
		w.WriteHeader(http.StatusOK)
		return
	}

	// Step 6: Update payment document
	orderID := payload.Payload.Payment.Entity.OrderID
	now := time.Now()
	if _, err := s.mongoDB.Collection("payments").UpdateOne(ctx,
		bson.M{"razorpayOrderId": orderID},
		bson.M{"$set": bson.M{
			"status":            "captured",
			"razorpayPaymentId": paymentID,
			"webhookReceivedAt": now,
		}},
	); err != nil {
		log.Printf("[payment] failed to update payment doc for order %s: %v", orderID, err)
		s.rdb.Del(ctx, keys.WebhookIdem(paymentID)) // rollback so Razorpay can retry
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	// Step 7: Look up userId from payment doc
	var payDoc bson.M
	if err := s.mongoDB.Collection("payments").FindOne(ctx, bson.M{"razorpayOrderId": orderID}).Decode(&payDoc); err != nil {
		log.Printf("[payment] payment doc not found for order %s: %v", orderID, err)
		w.WriteHeader(http.StatusOK) // no matching order — don't retry
		return
	}

	// Step 8: Publish payment.captured to RabbitMQ (must succeed or rollback)
	eventJSON, err := json.Marshal(map[string]interface{}{
		"event":        "payment.captured",
		"userId":       payDoc["userId"],
		"paymentId":    paymentID,
		"orderId":      orderID,
		"amount":       payDoc["amount"],
		"planDuration": payDoc["planDuration"],
		"timestamp":    now.Format(time.RFC3339),
	})
	if err != nil {
		log.Printf("[payment] failed to marshal event for order %s: %v", orderID, err)
		s.rdb.Del(ctx, keys.WebhookIdem(paymentID))
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if err := s.publish(ctx, "payment.captured", eventJSON); err != nil {
		log.Printf("[payment] failed to publish event for order %s: %v", orderID, err)
		s.rdb.Del(ctx, keys.WebhookIdem(paymentID))
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
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

		// Downgrade to free. Also clear premiumExpiryWarned so a future
		// re-subscription can receive a fresh 3-day pre-warning.
		s.mongoDB.Collection("users").UpdateOne(ctx,
			bson.M{"_id": userID},
			bson.M{
				"$set":   bson.M{"plan": "free", "planExpiresAt": nil},
				"$unset": bson.M{"premiumExpiryWarned": ""},
			},
		)
		// Invalidate Redis cache
		keys.DelPlan(ctx, s.rdb, userID)

		// Publish notification via thread-safe helper
		eventJSON, _ := json.Marshal(map[string]interface{}{
			"event":     "premium.expired",
			"userId":    userID,
			"timestamp": time.Now().Format(time.RFC3339),
		})
		if err := s.publish(ctx, "premium.expired", eventJSON); err != nil {
			log.Printf("[payment] failed to publish expiry for user %s: %v", userID, err)
		}
		log.Printf("[payment] downgraded user %s from premium to free", userID)
	}
}

// ---------------------------------------------------------------------------
// Background: Premium expiry 3-day pre-warning worker (24-hour ticker)
// ---------------------------------------------------------------------------

// premiumExpiryWarningWorker runs once a day and emits notif.premium.expiry for
// users whose planExpiresAt is ~3 days out. Each user is warned at most once
// per plan — the premiumExpiryWarned flag is set here and cleared on upgrade
// (scoring service) or downgrade (checkExpiredPlans) so renewals get a fresh
// warning cycle.
//
// Window (71h..73h) is narrower than the ticker interval (24h). With the
// premiumExpiryWarned dedupe flag in place, a wider window would cause the
// same user to match for multiple consecutive days — the flag short-circuits
// repeats, but the extra Mongo scans are wasted work. If the service restarts
// right as a user's expiry is crossing the window, they may be missed; that's
// acceptable because the pre-warning is a non-critical nudge (the actual
// downgrade still happens on time via planExpiryWorker).
func (s *paymentServer) premiumExpiryWarningWorker(ctx context.Context) {
	// Initial sweep after a short delay so RabbitMQ declarations and Mongo
	// indexes have time to settle before we start scanning users.
	initialDelay := time.NewTimer(30 * time.Second)
	defer initialDelay.Stop()
	select {
	case <-ctx.Done():
		return
	case <-initialDelay.C:
		s.sendPremiumExpiryWarnings(ctx)
	}

	ticker := time.NewTicker(24 * time.Hour)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.sendPremiumExpiryWarnings(ctx)
		}
	}
}

func (s *paymentServer) sendPremiumExpiryWarnings(ctx context.Context) {
	now := time.Now()
	windowStart := now.Add(71 * time.Hour)
	windowEnd := now.Add(73 * time.Hour)

	cursor, err := s.mongoDB.Collection("users").Find(ctx, bson.M{
		"plan": "premium",
		"planExpiresAt": bson.M{
			"$gte": windowStart,
			"$lte": windowEnd,
		},
		"premiumExpiryWarned": bson.M{"$ne": true},
	})
	if err != nil {
		log.Printf("[payment] expiry-warning query error: %v", err)
		return
	}
	defer cursor.Close(ctx)

	count := 0
	for cursor.Next(ctx) {
		var user bson.M
		if err := cursor.Decode(&user); err != nil {
			continue
		}
		userID, ok := user["_id"].(string)
		if !ok {
			continue
		}
		expiresAt, _ := user["planExpiresAt"].(time.Time)

		// Mark warned BEFORE publishing — on publish failure we miss one
		// user on the next tick rather than risking duplicate sends.
		if _, err := s.mongoDB.Collection("users").UpdateOne(ctx,
			bson.M{"_id": userID},
			bson.M{"$set": bson.M{"premiumExpiryWarned": true}},
		); err != nil {
			log.Printf("[payment] failed to mark user %s as warned: %v", userID, err)
			continue
		}

		eventJSON, _ := json.Marshal(map[string]interface{}{
			"event":     "notif.premium.expiry",
			"userId":    userID,
			"expiresAt": expiresAt.Format(time.RFC3339),
			"timestamp": now.Format(time.RFC3339),
		})
		if err := s.publish(ctx, "notif.premium.expiry", eventJSON); err != nil {
			log.Printf("[payment] failed to publish expiry warning for user %s: %v", userID, err)
			// Roll back the warned flag so the next tick retries this user.
			s.mongoDB.Collection("users").UpdateOne(ctx,
				bson.M{"_id": userID},
				bson.M{"$unset": bson.M{"premiumExpiryWarned": ""}},
			)
			continue
		}
		count++
		log.Printf("[payment] queued premium expiry warning for user %s (expires %s)",
			userID, expiresAt.Format(time.RFC3339))
	}
	if count > 0 {
		log.Printf("[payment] sent %d premium expiry warning(s)", count)
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
		amqpConn:       conn,
		amqpCh:         amqpCh,
		mongoDB:        mongoClient.Database("quizbattle"),
		jwtSecret:      jwtSecret,
		razorpayKeyID:  os.Getenv("RAZORPAY_KEY_ID"),
		razorpaySecret: os.Getenv("RAZORPAY_KEY_SECRET"),
		webhookSecret:  os.Getenv("RAZORPAY_WEBHOOK_SECRET"),
	}

	// Background: plan expiry worker (downgrade on expiry)
	go srv.planExpiryWorker(ctx)
	// Background: 3-day premium expiry pre-warning worker
	go srv.premiumExpiryWarningWorker(ctx)

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
