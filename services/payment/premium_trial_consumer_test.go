package main

import (
	"context"
	"os"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"quiz-battle/pkg/coins/shop"
)

// newTestPaymentServer is a minimal payment-server harness — just the
// fields the premium-trial consumer reaches for. No gRPC, no AMQP, no
// Razorpay; the consumer's seams are mongoClient + dbName + users().
func newTestPaymentServer(t *testing.T) (*paymentServer, *mongo.Client, string) {
	t.Helper()
	uri := os.Getenv("MONGO_URI")
	if uri == "" {
		uri = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	c, err := mongo.Connect(options.Client().ApplyURI(uri))
	if err != nil {
		t.Skipf("mongo connect: %v", err)
	}
	if err := c.Ping(ctx, nil); err != nil {
		t.Skipf("mongo ping: %v", err)
	}
	db := "payment_test_" + bson.NewObjectID().Hex()
	t.Cleanup(func() {
		bg := context.Background()
		_ = c.Database(db).Drop(bg)
		_ = c.Disconnect(bg)
	})
	return &paymentServer{mongoClient: c, mongoDB: c.Database(db), dbName: db}, c, db
}

func enqueueTestOutbox(t *testing.T, db *mongo.Database, id, userID, days string) {
	t.Helper()
	row := shop.OutboxRow{
		ID:        id,
		UserID:    userID,
		Kind:      "premium_trial",
		Payload:   map[string]string{"days": days, "ledgerEntryId": id + "-ledger"},
		CreatedAt: time.Now().UTC(),
	}
	if _, err := db.Collection(shop.EffectOutboxCollection).InsertOne(context.Background(), row); err != nil {
		t.Fatalf("seed outbox: %v", err)
	}
}

func seedPaymentTestUser(t *testing.T, db *mongo.Database, uid string, planExpiresAt *time.Time) {
	t.Helper()
	doc := bson.M{"_id": uid, "plan": "free"}
	if planExpiresAt != nil {
		doc["planExpiresAt"] = *planExpiresAt
	}
	if _, err := db.Collection("users").InsertOne(context.Background(), doc); err != nil {
		t.Fatalf("seed user: %v", err)
	}
}

func TestApplyPremiumTrialRow_HappyPath(t *testing.T) {
	srv, _, _ := newTestPaymentServer(t)
	seedPaymentTestUser(t, srv.mongoDB, "user-a", nil)
	enqueueTestOutbox(t, srv.mongoDB, "outbox-a", "user-a", "3")

	rows, err := shop.DequeueDue(context.Background(), srv.mongoDB, "premium_trial", 32)
	if err != nil || len(rows) != 1 {
		t.Fatalf("dequeue: err=%v len=%d", err, len(rows))
	}
	srv.applyPremiumTrialRow(context.Background(), srv.mongoDB, rows[0])

	var u struct {
		Plan          string     `bson:"plan"`
		PlanExpiresAt *time.Time `bson:"planExpiresAt"`
	}
	_ = srv.mongoDB.Collection("users").FindOne(context.Background(), bson.M{"_id": "user-a"}).Decode(&u)
	if u.Plan != "premium" {
		t.Errorf("plan=%q, want premium", u.Plan)
	}
	if u.PlanExpiresAt == nil {
		t.Fatalf("planExpiresAt is nil")
	}
	delta := time.Until(*u.PlanExpiresAt)
	wantApprox := 3 * 24 * time.Hour
	if delta < wantApprox-time.Minute || delta > wantApprox+time.Minute {
		t.Errorf("planExpiresAt delta=%v, want ~%v", delta, wantApprox)
	}

	// Outbox row must be marked processed in the SAME transaction. The
	// drain-worker dequeue (which we just used) filters processedAt: nil,
	// so a re-poll must return zero rows.
	rows2, _ := shop.DequeueDue(context.Background(), srv.mongoDB, "premium_trial", 32)
	if len(rows2) != 0 {
		t.Errorf("re-poll returned %d rows, want 0 — row not marked processed", len(rows2))
	}
}

func TestApplyPremiumTrialRow_RenewalAwareExtendsFromExistingExpiry(t *testing.T) {
	srv, _, _ := newTestPaymentServer(t)
	existing := time.Now().UTC().Add(2 * 24 * time.Hour)
	seedPaymentTestUser(t, srv.mongoDB, "user-b", &existing)
	enqueueTestOutbox(t, srv.mongoDB, "outbox-b", "user-b", "3")

	rows, _ := shop.DequeueDue(context.Background(), srv.mongoDB, "premium_trial", 32)
	srv.applyPremiumTrialRow(context.Background(), srv.mongoDB, rows[0])

	var u struct {
		PlanExpiresAt *time.Time `bson:"planExpiresAt"`
	}
	_ = srv.mongoDB.Collection("users").FindOne(context.Background(), bson.M{"_id": "user-b"}).Decode(&u)
	// Renewal-aware: extend from existing (2 days out), so result ≈ now + 5 days.
	delta := time.Until(*u.PlanExpiresAt)
	want := 5 * 24 * time.Hour
	if delta < want-time.Minute || delta > want+time.Minute {
		t.Errorf("renewal-aware extension wrong: delta=%v, want ~%v", delta, want)
	}
}

func TestApplyPremiumTrialRow_DrainWorkerNeverDoubleGrants(t *testing.T) {
	// Review feedback (PR #15): the original "user-update then MarkProcessed"
	// pattern double-granted whenever MarkProcessed failed transiently —
	// the next poll re-read the freshly-extended planExpiresAt as the
	// renewal base and stacked another `days * 24h`. The fix wraps both
	// writes in WithTransaction; this test exercises the natural drain
	// path twice and asserts the second pass is a no-op.
	srv, _, _ := newTestPaymentServer(t)
	seedPaymentTestUser(t, srv.mongoDB, "user-c", nil)
	enqueueTestOutbox(t, srv.mongoDB, "outbox-c", "user-c", "3")

	srv.drainPremiumTrialOutbox(context.Background())
	srv.drainPremiumTrialOutbox(context.Background())
	srv.drainPremiumTrialOutbox(context.Background())

	var u struct {
		PlanExpiresAt *time.Time `bson:"planExpiresAt"`
	}
	_ = srv.mongoDB.Collection("users").FindOne(context.Background(), bson.M{"_id": "user-c"}).Decode(&u)
	delta := time.Until(*u.PlanExpiresAt)
	want := 3 * 24 * time.Hour
	if delta < want-time.Minute || delta > want+time.Minute {
		t.Errorf("3 drain passes produced delta=%v, want ~%v (single 3-day grant)", delta, want)
	}
}

func TestApplyPremiumTrialRow_UserGoneMarksProcessed(t *testing.T) {
	srv, _, _ := newTestPaymentServer(t)
	// No user seed — the row references a non-existent user.
	enqueueTestOutbox(t, srv.mongoDB, "outbox-ghost", "ghost-user", "3")

	rows, _ := shop.DequeueDue(context.Background(), srv.mongoDB, "premium_trial", 32)
	srv.applyPremiumTrialRow(context.Background(), srv.mongoDB, rows[0])

	// Even with no user to grant to, the row must be marked processed
	// so the worker doesn't spin retrying. The next dequeue is empty.
	rows2, _ := shop.DequeueDue(context.Background(), srv.mongoDB, "premium_trial", 32)
	if len(rows2) != 0 {
		t.Errorf("user-gone row not processed: %d rows still pending", len(rows2))
	}
}

func TestApplyPremiumTrialRow_DefaultDaysOnMissingPayload(t *testing.T) {
	srv, _, _ := newTestPaymentServer(t)
	seedPaymentTestUser(t, srv.mongoDB, "user-d", nil)
	// Outbox row with no `days` payload → should fall back to default 3.
	row := shop.OutboxRow{
		ID:        "outbox-d",
		UserID:    "user-d",
		Kind:      "premium_trial",
		Payload:   map[string]string{},
		CreatedAt: time.Now().UTC(),
	}
	_, _ = srv.mongoDB.Collection(shop.EffectOutboxCollection).InsertOne(context.Background(), row)

	rows, _ := shop.DequeueDue(context.Background(), srv.mongoDB, "premium_trial", 32)
	srv.applyPremiumTrialRow(context.Background(), srv.mongoDB, rows[0])

	var u struct {
		PlanExpiresAt *time.Time `bson:"planExpiresAt"`
	}
	_ = srv.mongoDB.Collection("users").FindOne(context.Background(), bson.M{"_id": "user-d"}).Decode(&u)
	delta := time.Until(*u.PlanExpiresAt)
	want := 3 * 24 * time.Hour
	if delta < want-time.Minute || delta > want+time.Minute {
		t.Errorf("default-days fallback delta=%v, want ~%v", delta, want)
	}
}
