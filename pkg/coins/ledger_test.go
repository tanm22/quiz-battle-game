package coins_test

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sync"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"quiz-battle/pkg/coins"
)

// mongoForTest connects to the test Mongo replica set, creates a unique
// database for the test, ensures the coin_ledger indexes seed runs, and
// schedules cleanup. Skips the test if Mongo isn't reachable so dev
// machines without docker can still run `go test ./...`.
func mongoForTest(t *testing.T) (*mongo.Client, string) {
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
	dbName := "coins_test_" + bson.NewObjectID().Hex()
	t.Cleanup(func() {
		bg := context.Background()
		_ = c.Database(dbName).Drop(bg)
		_ = c.Disconnect(bg)
	})
	if _, err := c.Database(dbName).Collection("coin_ledger").Indexes().CreateOne(
		context.Background(),
		mongo.IndexModel{
			Keys:    bson.D{{Key: "userId", Value: 1}, {Key: "refId", Value: 1}, {Key: "reason", Value: 1}},
			Options: options.Index().SetUnique(true).SetName("uniq_user_ref_reason"),
		},
	); err != nil {
		t.Fatalf("create idempotency index: %v", err)
	}
	return c, dbName
}

func seedUser(t *testing.T, c *mongo.Client, dbName, uid string, balance int64) {
	t.Helper()
	_, err := c.Database(dbName).Collection("users").InsertOne(context.Background(), bson.M{"_id": uid, "coins": balance})
	if err != nil {
		t.Fatalf("seed user: %v", err)
	}
}

func TestGrant_HappyPath(t *testing.T) {
	c, db := mongoForTest(t)
	seedUser(t, c, db, "u1", 50)

	l := coins.NewLedger(c, db)
	entry, err := l.Grant(context.Background(), "u1", 100, coins.ReasonDailyReward, "streak:u1:2026-04-26", nil)
	if err != nil {
		t.Fatalf("Grant: %v", err)
	}
	if entry.Delta != 100 || entry.BalanceAfter != 150 {
		t.Errorf("got delta=%d balanceAfter=%d, want 100/150", entry.Delta, entry.BalanceAfter)
	}
	if time.Since(entry.CreatedAt) > 5*time.Second {
		t.Errorf("createdAt too old: %v", entry.CreatedAt)
	}

	bal, err := l.GetBalance(context.Background(), "u1")
	if err != nil || bal != 150 {
		t.Errorf("GetBalance got %d err=%v, want 150", bal, err)
	}
}

func TestGrant_RejectsZero(t *testing.T) {
	c, db := mongoForTest(t)
	seedUser(t, c, db, "u1", 0)
	l := coins.NewLedger(c, db)
	if _, err := l.Grant(context.Background(), "u1", 0, coins.ReasonMatchWin, "match:m1", nil); !errors.Is(err, coins.ErrAmountInvalid) {
		t.Fatalf("got %v, want ErrAmountInvalid", err)
	}
}

func TestGrant_RejectsUnknownReason(t *testing.T) {
	c, db := mongoForTest(t)
	seedUser(t, c, db, "u1", 0)
	l := coins.NewLedger(c, db)
	if _, err := l.Grant(context.Background(), "u1", 10, "made.up.reason", "ref", nil); !errors.Is(err, coins.ErrUnknownReason) {
		t.Fatalf("got %v, want ErrUnknownReason", err)
	}
}

func TestGrant_RejectsMissingRefID(t *testing.T) {
	c, db := mongoForTest(t)
	seedUser(t, c, db, "u1", 0)
	l := coins.NewLedger(c, db)
	if _, err := l.Grant(context.Background(), "u1", 10, coins.ReasonMatchWin, "", nil); !errors.Is(err, coins.ErrMissingRefID) {
		t.Fatalf("got %v, want ErrMissingRefID", err)
	}
}

func TestGrant_IdempotentOnDuplicateRef(t *testing.T) {
	c, db := mongoForTest(t)
	seedUser(t, c, db, "u1", 0)
	l := coins.NewLedger(c, db)

	first, err := l.Grant(context.Background(), "u1", 50, coins.ReasonMatchWin, "match:m1", nil)
	if err != nil {
		t.Fatalf("first Grant: %v", err)
	}
	second, err := l.Grant(context.Background(), "u1", 50, coins.ReasonMatchWin, "match:m1", nil)
	if err != nil {
		t.Fatalf("second Grant: %v", err)
	}
	if first.ID != second.ID || second.BalanceAfter != 50 {
		t.Errorf("idempotency broken: first=%v second=%v", first, second)
	}

	bal, _ := l.GetBalance(context.Background(), "u1")
	if bal != 50 {
		t.Errorf("balance double-credited: got %d, want 50", bal)
	}
}

func TestGrant_IdempotencyConflictOnDeltaMismatch(t *testing.T) {
	// A second Grant with the SAME refID+reason but a DIFFERENT delta must
	// surface ErrIdempotencyConflict so a buggy caller (e.g. a backfill
	// script copy-pasting an old refID) can't silently re-book at the
	// originally-recorded amount. Today's callers all use natural refIDs
	// so this is defense-in-depth, but the failure mode here is silent
	// and money-shaped, so we make it loud.
	c, db := mongoForTest(t)
	seedUser(t, c, db, "u1", 0)
	l := coins.NewLedger(c, db)

	if _, err := l.Grant(context.Background(), "u1", 50, coins.ReasonMatchWin, "match:m1", nil); err != nil {
		t.Fatalf("first Grant: %v", err)
	}
	_, err := l.Grant(context.Background(), "u1", 100, coins.ReasonMatchWin, "match:m1", nil)
	if !errors.Is(err, coins.ErrIdempotencyConflict) {
		t.Fatalf("got %v, want ErrIdempotencyConflict on delta mismatch", err)
	}

	// Balance must not double-credit on the mismatched second attempt.
	bal, _ := l.GetBalance(context.Background(), "u1")
	if bal != 50 {
		t.Errorf("balance after rejected mismatched grant: got %d, want 50", bal)
	}
}

func TestGrant_InsufficientBalance(t *testing.T) {
	c, db := mongoForTest(t)
	seedUser(t, c, db, "u1", 30)
	l := coins.NewLedger(c, db)

	_, err := l.Grant(context.Background(), "u1", -100, coins.ReasonShopPurchase, "purchase:p1", nil)
	if !errors.Is(err, coins.ErrInsufficientBalance) {
		t.Fatalf("expected ErrInsufficientBalance, got %v", err)
	}

	bal, _ := l.GetBalance(context.Background(), "u1")
	if bal != 30 {
		t.Errorf("failed grant must not mutate balance: got %d", bal)
	}
	count, _ := c.Database(db).Collection("coin_ledger").CountDocuments(context.Background(), bson.M{"userId": "u1"})
	if count != 0 {
		t.Errorf("failed grant must not write a ledger row: got %d", count)
	}
}

func TestGrant_ConcurrentGrantsNeverDoubleCredit(t *testing.T) {
	c, db := mongoForTest(t)
	seedUser(t, c, db, "u1", 0)
	l := coins.NewLedger(c, db)

	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, _ = l.Grant(context.Background(), "u1", 10, coins.ReasonMatchWin, "match:dup", nil)
		}()
	}
	wg.Wait()

	bal, _ := l.GetBalance(context.Background(), "u1")
	if bal != 10 {
		t.Errorf("balance should be 10 after 20 racing identical grants, got %d", bal)
	}
	count, _ := c.Database(db).Collection("coin_ledger").CountDocuments(context.Background(), bson.M{"userId": "u1"})
	if count != 1 {
		t.Errorf("ledger should have exactly 1 row, got %d", count)
	}
}

func TestGetLedger_PagedNewestFirst(t *testing.T) {
	c, db := mongoForTest(t)
	seedUser(t, c, db, "u1", 0)
	l := coins.NewLedger(c, db)

	for i := 0; i < 5; i++ {
		_, err := l.Grant(context.Background(), "u1", 10, coins.ReasonMatchWin, fmt.Sprintf("match:%d", i), nil)
		if err != nil {
			t.Fatalf("seed grant %d: %v", i, err)
		}
		time.Sleep(2 * time.Millisecond)
	}

	page1, next, err := l.GetLedger(context.Background(), "u1", 3, "")
	if err != nil {
		t.Fatalf("page1: %v", err)
	}
	if len(page1) != 3 || next == "" {
		t.Fatalf("page1 len=%d next=%q", len(page1), next)
	}
	if page1[0].RefID != "match:4" {
		t.Errorf("first should be newest match:4, got %s", page1[0].RefID)
	}

	page2, next2, err := l.GetLedger(context.Background(), "u1", 3, next)
	if err != nil {
		t.Fatalf("page2: %v", err)
	}
	if len(page2) != 2 || next2 != "" {
		t.Errorf("page2 len=%d next=%q", len(page2), next2)
	}
}

func TestGetLedger_DefaultPageSize(t *testing.T) {
	c, db := mongoForTest(t)
	seedUser(t, c, db, "u1", 0)
	l := coins.NewLedger(c, db)

	rows, _, err := l.GetLedger(context.Background(), "u1", 0, "")
	if err != nil {
		t.Fatalf("default page: %v", err)
	}
	if rows == nil {
		t.Errorf("expected non-nil empty slice")
	}
}
