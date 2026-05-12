package main

import (
	"context"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/mongo"

	"quiz-battle/pkg/coins/shop"
)

// insertOutboxRow is a thinner enqueue than enqueueTestOutbox in
// premium_trial_consumer_test.go because the watcher tests need to set
// the kind, processedAt timestamp, and createdAt offsets explicitly
// (the consumer-test helper hard-codes kind="premium_trial" and a fresh
// CreatedAt). Keeping a watcher-local helper avoids over-broadening the
// consumer-test helper to serve two unrelated needs.
func insertOutboxRow(t *testing.T, db *mongo.Database, row shop.OutboxRow) {
	t.Helper()
	if _, err := db.Collection(shop.EffectOutboxCollection).InsertOne(context.Background(), row); err != nil {
		t.Fatalf("insert outbox row: %v", err)
	}
}

func TestSampleOutbox_EmptyCollection(t *testing.T) {
	srv, _, _ := newTestPaymentServer(t)

	pending, age, err := srv.sampleOutbox(context.Background(), "premium_trial")
	if err != nil {
		t.Fatalf("sampleOutbox: %v", err)
	}
	if pending != 0 {
		t.Errorf("pending = %d, want 0", pending)
	}
	if age != 0 {
		t.Errorf("age = %v, want 0", age)
	}
}

func TestSampleOutbox_OneFreshUnprocessedRow(t *testing.T) {
	srv, _, _ := newTestPaymentServer(t)
	// CreatedAt = now - 5s lets us assert age ≈ 5 with a ±1s tolerance —
	// deterministic without forcing a real sleep. Same trick the §4.3
	// premium-expiry-warning tests use for time-of-day fixtures.
	insertOutboxRow(t, srv.mongoDB, shop.OutboxRow{
		ID:        "row-fresh",
		UserID:    "user-a",
		Kind:      "premium_trial",
		Payload:   map[string]string{"days": "3"},
		CreatedAt: time.Now().UTC().Add(-5 * time.Second),
	})

	pending, age, err := srv.sampleOutbox(context.Background(), "premium_trial")
	if err != nil {
		t.Fatalf("sampleOutbox: %v", err)
	}
	if pending != 1 {
		t.Errorf("pending = %d, want 1", pending)
	}
	if age < 4 || age > 6 {
		t.Errorf("age = %v, want ~5 (±1s)", age)
	}
}

func TestSampleOutbox_ProcessedRowIgnored(t *testing.T) {
	srv, _, _ := newTestPaymentServer(t)
	processedAt := time.Now().UTC().Add(-10 * time.Second)
	insertOutboxRow(t, srv.mongoDB, shop.OutboxRow{
		ID:          "row-processed",
		UserID:      "user-a",
		Kind:        "premium_trial",
		Payload:     map[string]string{"days": "3"},
		CreatedAt:   time.Now().UTC().Add(-1 * time.Hour),
		ProcessedAt: &processedAt,
	})
	insertOutboxRow(t, srv.mongoDB, shop.OutboxRow{
		ID:        "row-pending",
		UserID:    "user-b",
		Kind:      "premium_trial",
		Payload:   map[string]string{"days": "3"},
		CreatedAt: time.Now().UTC().Add(-2 * time.Second),
	})

	pending, age, err := srv.sampleOutbox(context.Background(), "premium_trial")
	if err != nil {
		t.Fatalf("sampleOutbox: %v", err)
	}
	if pending != 1 {
		t.Errorf("pending = %d, want 1 (only the unprocessed row counted)", pending)
	}
	// Age must come from the *unprocessed* row, not the (older) processed one.
	if age < 1 || age > 3 {
		t.Errorf("age = %v, want ~2 (the unprocessed row's age, not the 1h-old processed one)", age)
	}
}

func TestSampleOutbox_WrongKindIgnored(t *testing.T) {
	srv, _, _ := newTestPaymentServer(t)
	// Different kind — must not be counted by the "premium_trial" sample.
	insertOutboxRow(t, srv.mongoDB, shop.OutboxRow{
		ID:        "row-other",
		UserID:    "user-a",
		Kind:      "something_else",
		Payload:   map[string]string{"foo": "bar"},
		CreatedAt: time.Now().UTC().Add(-30 * time.Second),
	})

	pending, age, err := srv.sampleOutbox(context.Background(), "premium_trial")
	if err != nil {
		t.Fatalf("sampleOutbox: %v", err)
	}
	if pending != 0 {
		t.Errorf("pending = %d, want 0 (wrong-kind row must not count)", pending)
	}
	if age != 0 {
		t.Errorf("age = %v, want 0", age)
	}
}

func TestSampleOutbox_OldestSelectsCorrectRow(t *testing.T) {
	// Sanity: with two unprocessed rows, the age must come from the
	// older one. This catches a regression where SetSort was missing or
	// reversed (a real bug class — the watcher's stuck-row signal is
	// meaningless if it tracks the *newest* unprocessed row's age).
	srv, _, _ := newTestPaymentServer(t)
	insertOutboxRow(t, srv.mongoDB, shop.OutboxRow{
		ID:        "row-newer",
		UserID:    "user-a",
		Kind:      "premium_trial",
		Payload:   map[string]string{"days": "3"},
		CreatedAt: time.Now().UTC().Add(-2 * time.Second),
	})
	insertOutboxRow(t, srv.mongoDB, shop.OutboxRow{
		ID:        "row-older",
		UserID:    "user-b",
		Kind:      "premium_trial",
		Payload:   map[string]string{"days": "3"},
		CreatedAt: time.Now().UTC().Add(-20 * time.Second),
	})

	pending, age, err := srv.sampleOutbox(context.Background(), "premium_trial")
	if err != nil {
		t.Fatalf("sampleOutbox: %v", err)
	}
	if pending != 2 {
		t.Errorf("pending = %d, want 2", pending)
	}
	if age < 19 || age > 21 {
		t.Errorf("age = %v, want ~20 (the OLDER row's age, not the 2s-old one)", age)
	}
}
