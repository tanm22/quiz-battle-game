package main

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// §4.9 integration coverage for the Razorpay webhook HTTP handler.
// Where the existing webhook_signature_test.go locks in the pure
// verifier function, this file drives requests through handleWebhook
// against a real Mongo + real Redis (DB 12, reserved for these tests)
// and a publishHook seam that captures the outbound RabbitMQ event.
// That exercises the full chain — sig verify → Mongo state mutation →
// event publish → SETNX idempotency — without needing a broker.

const testWebhookSecret = "test-webhook-secret"

type captured struct {
	routingKey string
	body       []byte
}

// newServerWithCaptures builds a paymentServer wired enough for the
// webhook handler. Mongo is namespaced per-test via a random db name;
// Redis uses DB 12 with FlushDB on setup so a stray idem key from
// another run can't trip the deduper. The returned slice pointer is
// what the publishHook appends to — tests assert against *captures.
func newServerWithCaptures(t *testing.T) (*paymentServer, *[]captured) {
	t.Helper()

	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true"
	}
	connCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	mc, err := mongo.Connect(options.Client().ApplyURI(mongoURI))
	if err != nil {
		t.Skipf("mongo connect: %v", err)
	}
	if err := mc.Ping(connCtx, nil); err != nil {
		t.Skipf("mongo ping: %v", err)
	}
	dbName := "payment_webhook_test_" + bson.NewObjectID().Hex()

	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: redisAddr, DB: 12})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		t.Skipf("redis ping: %v", err)
	}
	_ = rdb.FlushDB(context.Background()).Err()

	t.Cleanup(func() {
		bg := context.Background()
		_ = mc.Database(dbName).Drop(bg)
		_ = mc.Disconnect(bg)
		_ = rdb.FlushDB(bg).Err()
		_ = rdb.Close()
	})

	captures := []captured{}
	srv := &paymentServer{
		mongoClient:   mc,
		mongoDB:       mc.Database(dbName),
		dbName:        dbName,
		rdb:           rdb,
		webhookSecret: testWebhookSecret,
		publishHook: func(routingKey string, body []byte) {
			captures = append(captures, captured{routingKey, append([]byte(nil), body...)})
		},
	}
	return srv, &captures
}

func signWebhook(body []byte, secret string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

func capturedEvent(t *testing.T, body []byte) map[string]any {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal(body, &m); err != nil {
		t.Fatalf("captured event not valid JSON: %v", err)
	}
	return m
}

// seedPaymentDoc inserts a payments row in the `created` state for the
// given (userId, orderId). The webhook handler looks the doc up by
// razorpayOrderId and mutates it to `captured` — without a row the
// handler short-circuits and the test would only assert the signature
// path.
func seedPaymentDoc(t *testing.T, srv *paymentServer, userID, orderID, planDuration string) {
	t.Helper()
	_, err := srv.mongoDB.Collection("payments").InsertOne(context.Background(), bson.M{
		"_id":             bson.NewObjectID().Hex(),
		"userId":          userID,
		"razorpayOrderId": orderID,
		"amount":          int64(29900),
		"planDuration":    planDuration,
		"status":          "created",
		"createdAt":       time.Now().UTC(),
	})
	if err != nil {
		t.Fatalf("seed payment: %v", err)
	}
}

func paymentCapturedBody(orderID, paymentID string) []byte {
	body, _ := json.Marshal(map[string]any{
		"event": "payment.captured",
		"payload": map[string]any{
			"payment": map[string]any{
				"entity": map[string]any{
					"id":       paymentID,
					"order_id": orderID,
					"status":   "captured",
				},
			},
		},
	})
	return body
}

// TestHandleWebhook_HappyPath — signed payment.captured → 200,
// payment doc flipped to captured, payment.captured event published
// with userId / orderId / paymentId in the body.
func TestHandleWebhook_HappyPath(t *testing.T) {
	srv, captures := newServerWithCaptures(t)
	const userID = "user-happy"
	const orderID = "order_HAPPY01"
	const paymentID = "pay_HAPPY01"
	seedPaymentDoc(t, srv, userID, orderID, "monthly")

	body := paymentCapturedBody(orderID, paymentID)
	req := httptest.NewRequest(http.MethodPost, "/webhook/razorpay", bytes.NewReader(body))
	req.Header.Set("X-Razorpay-Signature", signWebhook(body, testWebhookSecret))
	rr := httptest.NewRecorder()

	srv.handleWebhook(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%q", rr.Code, rr.Body.String())
	}

	// Payment doc flipped to captured.
	var doc bson.M
	if err := srv.mongoDB.Collection("payments").FindOne(context.Background(),
		bson.M{"razorpayOrderId": orderID}).Decode(&doc); err != nil {
		t.Fatalf("payments lookup: %v", err)
	}
	if got, _ := doc["status"].(string); got != "captured" {
		t.Errorf("payment status = %q, want captured", got)
	}
	if got, _ := doc["razorpayPaymentId"].(string); got != paymentID {
		t.Errorf("razorpayPaymentId = %q, want %q", got, paymentID)
	}

	// Exactly one payment.captured event published with the userId.
	if len(*captures) != 1 {
		t.Fatalf("publishes = %d, want 1; got %+v", len(*captures), *captures)
	}
	cap := (*captures)[0]
	if cap.routingKey != "payment.captured" {
		t.Errorf("routing key = %q, want payment.captured", cap.routingKey)
	}
	event := capturedEvent(t, cap.body)
	if event["userId"] != userID {
		t.Errorf("event userId = %v, want %q", event["userId"], userID)
	}
	if event["orderId"] != orderID || event["paymentId"] != paymentID {
		t.Errorf("event ids mismatch: %+v", event)
	}
}

// TestHandleWebhook_BadSignature — request body changed under the
// signature (or signed with the wrong secret) must return 400 and
// MUST NOT touch Mongo, MUST NOT publish.
func TestHandleWebhook_BadSignature(t *testing.T) {
	srv, captures := newServerWithCaptures(t)
	const orderID = "order_BADSIG"
	seedPaymentDoc(t, srv, "user-bad", orderID, "monthly")

	body := paymentCapturedBody(orderID, "pay_BAD")
	req := httptest.NewRequest(http.MethodPost, "/webhook/razorpay", bytes.NewReader(body))
	// Sign with the wrong secret — the verifier should reject.
	req.Header.Set("X-Razorpay-Signature", signWebhook(body, "other-secret"))
	rr := httptest.NewRecorder()

	srv.handleWebhook(rr, req)

	if rr.Code == http.StatusOK {
		t.Errorf("status = 200; want non-200 on bad signature")
	}
	if !strings.Contains(strings.ToLower(rr.Body.String()), "signature") {
		t.Errorf("body = %q; want a signature-related error", rr.Body.String())
	}

	// Mongo untouched, no publish.
	var doc bson.M
	_ = srv.mongoDB.Collection("payments").FindOne(context.Background(),
		bson.M{"razorpayOrderId": orderID}).Decode(&doc)
	if got, _ := doc["status"].(string); got != "created" {
		t.Errorf("payment status mutated to %q on bad-sig request", got)
	}
	if len(*captures) != 0 {
		t.Errorf("publishes = %d on bad-sig request; want 0", len(*captures))
	}
}

// TestHandleWebhook_Idempotent — receiving the same paymentID twice
// is the canonical Razorpay retry pattern. First call captures and
// publishes; second is a no-op (200 + zero publishes).
func TestHandleWebhook_Idempotent(t *testing.T) {
	srv, captures := newServerWithCaptures(t)
	const userID = "user-idem"
	const orderID = "order_IDEM01"
	const paymentID = "pay_IDEM01"
	seedPaymentDoc(t, srv, userID, orderID, "monthly")

	body := paymentCapturedBody(orderID, paymentID)
	sig := signWebhook(body, testWebhookSecret)

	// First delivery.
	req1 := httptest.NewRequest(http.MethodPost, "/webhook/razorpay", bytes.NewReader(body))
	req1.Header.Set("X-Razorpay-Signature", sig)
	rr1 := httptest.NewRecorder()
	srv.handleWebhook(rr1, req1)
	if rr1.Code != http.StatusOK {
		t.Fatalf("first call: status %d, want 200", rr1.Code)
	}
	if len(*captures) != 1 {
		t.Fatalf("first call publishes = %d, want 1", len(*captures))
	}

	// Second delivery (same paymentID). Must short-circuit at the
	// SETNX guard; status stays 200 but no extra publish.
	req2 := httptest.NewRequest(http.MethodPost, "/webhook/razorpay", bytes.NewReader(body))
	req2.Header.Set("X-Razorpay-Signature", sig)
	rr2 := httptest.NewRecorder()
	srv.handleWebhook(rr2, req2)
	if rr2.Code != http.StatusOK {
		t.Errorf("second call: status %d, want 200 (idempotent)", rr2.Code)
	}
	if len(*captures) != 1 {
		t.Errorf("second call: total publishes = %d, want 1 (no re-publish)", len(*captures))
	}
}

// TestHandleWebhook_NonCapturedEventAcked — other Razorpay event types
// (order.paid, refund.processed, etc.) are signed but not actionable
// for us. Handler must ack with 200 and not touch state. Without this
// guard Razorpay would retry every unhandled event type forever.
func TestHandleWebhook_NonCapturedEventAcked(t *testing.T) {
	srv, captures := newServerWithCaptures(t)
	const orderID = "order_OTHER"
	seedPaymentDoc(t, srv, "user-other", orderID, "monthly")

	body, _ := json.Marshal(map[string]any{
		"event": "order.paid",
		"payload": map[string]any{
			"payment": map[string]any{
				"entity": map[string]any{
					"id":       "pay_other",
					"order_id": orderID,
					"status":   "captured",
				},
			},
		},
	})
	req := httptest.NewRequest(http.MethodPost, "/webhook/razorpay", bytes.NewReader(body))
	req.Header.Set("X-Razorpay-Signature", signWebhook(body, testWebhookSecret))
	rr := httptest.NewRecorder()
	srv.handleWebhook(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("status = %d, want 200 for unhandled event", rr.Code)
	}
	if len(*captures) != 0 {
		t.Errorf("publishes = %d on unhandled event; want 0", len(*captures))
	}
	// Payment doc must stay in `created` — we never processed it.
	var doc bson.M
	_ = srv.mongoDB.Collection("payments").FindOne(context.Background(),
		bson.M{"razorpayOrderId": orderID}).Decode(&doc)
	if got, _ := doc["status"].(string); got != "created" {
		t.Errorf("payment status changed to %q on non-captured event", got)
	}
}

// TestHandleWebhook_WrongMethod — GET / PUT / DELETE on the webhook
// URL must return 405. Cheap test that documents the surface.
func TestHandleWebhook_WrongMethod(t *testing.T) {
	srv, _ := newServerWithCaptures(t)
	for _, m := range []string{http.MethodGet, http.MethodPut, http.MethodDelete} {
		req := httptest.NewRequest(m, "/webhook/razorpay", nil)
		rr := httptest.NewRecorder()
		srv.handleWebhook(rr, req)
		if rr.Code != http.StatusMethodNotAllowed {
			t.Errorf("%s: status = %d, want 405", m, rr.Code)
		}
	}
}

