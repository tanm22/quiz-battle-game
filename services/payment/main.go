package main

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
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
	amqpMu         sync.Mutex // AMQP channels are not thread-safe
	amqpCh         *amqp.Channel
	mongoClient    *mongo.Client // bound for the §4.3 PR 5 outbox consumer's collection access
	mongoDB        *mongo.Database
	dbName         string // "quizbattle" in prod; mirrors the scoringServer pattern from PR 1
	jwtSecret      string
	razorpayKeyID  string
	razorpaySecret string
	webhookSecret  string
}

// users returns the users collection on the configured DB. Mirrors the
// helper added on scoringServer in PR 1 so the §4.3 PR 5 premium-trial
// consumer can reach the user document without re-deriving the path.
func (s *paymentServer) users() *mongo.Collection {
	return s.mongoClient.Database(s.dbName).Collection("users")
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

	orderID := payload.Payload.Payment.Entity.OrderID
	ctx := context.Background()
	// capturePayment is idempotent on paymentID via the SETNX guard, so
	// receiving the same webhook twice is a no-op.
	if err := s.capturePayment(ctx, orderID, paymentID); err != nil {
		log.Printf("[payment] webhook capture error: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

// capturePayment is the shared "mark this payment as captured and fan out
// the upgrade event" path. Both the Razorpay webhook and the client-side
// VerifyPayment RPC end here, after their respective signature checks.
//
// It is idempotent on paymentID via Redis SETNX: the first call wins,
// flips the payment doc's status to `captured`, and publishes
// `payment.captured` to RabbitMQ for the scoring service's plan-upgrade
// consumer. Subsequent calls with the same paymentID return nil without
// mutating anything — Razorpay re-deliveries and the
// "Flutter-already-verified-then-webhook-arrives" race both collapse to
// a single capture.
func (s *paymentServer) capturePayment(ctx context.Context, orderID, paymentID string) error {
	if orderID == "" || paymentID == "" {
		return errors.New("orderID and paymentID required")
	}

	isNew, err := keys.SetWebhookIdem(ctx, s.rdb, paymentID)
	if err != nil {
		return fmt.Errorf("idempotency check: %w", err)
	}
	if !isNew {
		// Already processed by an earlier webhook / verify call. Caller
		// can treat as success (the first writer already published the
		// event and the scoring consumer is/was upgrading the plan).
		return nil
	}

	now := time.Now()
	if _, err := s.mongoDB.Collection("payments").UpdateOne(ctx,
		bson.M{"razorpayOrderId": orderID},
		bson.M{"$set": bson.M{
			"status":            "captured",
			"razorpayPaymentId": paymentID,
			"capturedAt":        now,
		}},
	); err != nil {
		// Roll back the SETNX so a retry can re-attempt — without this
		// a transient Mongo blip would permanently mark the payment as
		// "processed" (in Redis) but leave it stuck in `created`.
		s.rdb.Del(ctx, keys.WebhookIdem(paymentID))
		return fmt.Errorf("update payment doc for order %s: %w", orderID, err)
	}

	var payDoc bson.M
	if err := s.mongoDB.Collection("payments").FindOne(ctx,
		bson.M{"razorpayOrderId": orderID}).Decode(&payDoc); err != nil {
		// No matching order — most likely a stale paymentID from
		// outside this system; surface as success so callers stop
		// retrying. The Redis idem key is left set so we don't
		// re-process a future identical paymentID.
		log.Printf("[payment] capturePayment: no payment doc for order %s: %v", orderID, err)
		return nil
	}

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
		s.rdb.Del(ctx, keys.WebhookIdem(paymentID))
		return fmt.Errorf("marshal event: %w", err)
	}

	if err := s.publish(ctx, "payment.captured", eventJSON); err != nil {
		s.rdb.Del(ctx, keys.WebhookIdem(paymentID))
		return fmt.Errorf("publish event: %w", err)
	}

	log.Printf("[payment] captured: payment=%s order=%s user=%v",
		paymentID, orderID, payDoc["userId"])
	return nil
}

// VerifyPayment is the client-driven counterpart to the Razorpay
// webhook. The Flutter app calls this after the Razorpay SDK reports a
// successful charge with the (orderId, paymentId, signature) triple.
// We HMAC-SHA256 verify the signature against `orderId|paymentId` using
// the Razorpay key secret, then route through capturePayment — same
// path the webhook takes.
//
// This is what makes the payment flow work in dev without ngrok or any
// other public webhook tunnel: the verify call is a normal authed gRPC
// from the client, the upgrade fans out via RabbitMQ exactly as it
// would have via the webhook, and Flutter sees a synchronous
// success/failure rather than waiting on a delivery it can't observe.
func (s *paymentServer) VerifyPayment(ctx context.Context, req *pb.VerifyPaymentRequest) (*pb.VerifyPaymentResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if req.RazorpayOrderId == "" || req.RazorpayPaymentId == "" || req.RazorpaySignature == "" {
		return nil, status.Error(codes.InvalidArgument, "razorpay_order_id, razorpay_payment_id, and razorpay_signature are required")
	}
	if s.razorpaySecret == "" {
		return nil, status.Error(codes.FailedPrecondition, "razorpay key secret not configured")
	}

	// Razorpay's documented client-side signature contract:
	//   sig == HMAC-SHA256(key_secret, order_id + "|" + payment_id)
	mac := hmac.New(sha256.New, []byte(s.razorpaySecret))
	mac.Write([]byte(req.RazorpayOrderId + "|" + req.RazorpayPaymentId))
	expected := hex.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(expected), []byte(req.RazorpaySignature)) {
		log.Printf("[payment] VerifyPayment: signature mismatch user=%s order=%s",
			userID, req.RazorpayOrderId)
		return nil, status.Error(codes.PermissionDenied, "invalid payment signature")
	}

	// Authorisation: the order has to belong to the caller. Without
	// this check, a leaked signature could let user A upgrade user B's
	// plan (extremely unlikely but cheap to defend against).
	var owner struct {
		UserID string `bson:"userId"`
	}
	err = s.mongoDB.Collection("payments").
		FindOne(ctx, bson.M{"razorpayOrderId": req.RazorpayOrderId}).Decode(&owner)
	if err != nil {
		return nil, status.Error(codes.NotFound, "order not found")
	}
	if owner.UserID != userID {
		log.Printf("[payment] VerifyPayment: order ownership mismatch user=%s order=%s actual_owner=%s",
			userID, req.RazorpayOrderId, owner.UserID)
		return nil, status.Error(codes.PermissionDenied, "order does not belong to caller")
	}

	if err := s.capturePayment(ctx, req.RazorpayOrderId, req.RazorpayPaymentId); err != nil {
		return nil, status.Errorf(codes.Internal, "capture: %v", err)
	}

	// Returning plan="premium" is optimistic — the actual users.plan
	// flip is done asynchronously by the scoring service's
	// payment.captured consumer. Flutter will reload via GetPlanStatus
	// shortly to reflect the canonical state. expires_at is computed
	// here so the UI can render an immediate confirmation rather than
	// flashing "free" between verify and the consumer catching up.
	planDuration, _ := s.lookupPlanDuration(ctx, req.RazorpayOrderId)
	expiresAt := time.Now().AddDate(0, 1, 0).Unix()
	if planDuration == "yearly" {
		expiresAt = time.Now().AddDate(1, 0, 0).Unix()
	}
	return &pb.VerifyPaymentResponse{
		Success:   true,
		Plan:      "premium",
		ExpiresAt: expiresAt,
	}, nil
}

// lookupPlanDuration is a small helper that reads the planDuration off
// the payment doc — needed by VerifyPayment to compute the optimistic
// expiry returned to the client. Wraps a no-op fallback so a missing
// doc simply yields "monthly" and never errors.
func (s *paymentServer) lookupPlanDuration(ctx context.Context, orderID string) (string, error) {
	var doc struct {
		PlanDuration string `bson:"planDuration"`
	}
	err := s.mongoDB.Collection("payments").
		FindOne(ctx, bson.M{"razorpayOrderId": orderID}).Decode(&doc)
	if err != nil {
		return "monthly", err
	}
	return doc.PlanDuration, nil
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

	const dbName = "quizbattle"
	srv := &paymentServer{
		rdb:            rdb,
		amqpConn:       conn,
		amqpCh:         amqpCh,
		mongoClient:    mongoClient,
		mongoDB:        mongoClient.Database(dbName),
		dbName:         dbName,
		jwtSecret:      jwtSecret,
		razorpayKeyID:  os.Getenv("RAZORPAY_KEY_ID"),
		razorpaySecret: os.Getenv("RAZORPAY_KEY_SECRET"),
		webhookSecret:  os.Getenv("RAZORPAY_WEBHOOK_SECRET"),
	}

	// Background: plan expiry worker (downgrade on expiry)
	go srv.planExpiryWorker(ctx)
	// Background: 3-day premium expiry pre-warning worker
	go srv.premiumExpiryWarningWorker(ctx)
	// §4.3 PR 5: drains coin_effect_outbox rows of kind="premium_trial"
	// and extends planExpiresAt. The shop's Purchase.Buy enqueues these
	// inside its session, so the row commits atomically with the coin
	// debit; this worker processes them as soon as they're visible.
	srv.startPremiumTrialConsumer(ctx)

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
