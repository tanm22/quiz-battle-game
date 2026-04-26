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

// mongoForTest dials Mongo (replica-set required for transactions) and
// returns a per-test database name so tests don't bleed state. Tests skip
// gracefully when MONGO_URI isn't reachable — CI provides a sidecar rs0,
// local devs run docker compose up first.
func mongoForTest(t *testing.T) (*mongo.Client, string) {
	t.Helper()
	uri := os.Getenv("MONGO_URI")
	if uri == "" {
		uri = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true"
	}
	c, err := mongo.Connect(options.Client().ApplyURI(uri))
	if err != nil {
		t.Skipf("mongo unavailable: %v", err)
	}
	// Quick liveness check so we skip cleanly when there's no broker rather
	// than hanging the test on first use.
	pingCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := c.Ping(pingCtx, nil); err != nil {
		t.Skipf("mongo ping failed: %v", err)
	}
	dbName := "coins_test_" + bson.NewObjectID().Hex()
	t.Cleanup(func() {
		_ = c.Database(dbName).Drop(context.Background())
		_ = c.Disconnect(context.Background())
	})
	// Mirror seed: the unique index is what enforces dup-key on idempotency.
	_, _ = c.Database(dbName).Collection("coin_ledger").Indexes().CreateOne(
		context.Background(),
		mongo.IndexModel{
			Keys:    bson.D{{Key: "userId", Value: 1}, {Key: "refId", Value: 1}, {Key: "reason", Value: 1}},
			Options: options.Index().SetUnique(true),
		},
	)
	return c, dbName
}

func seedUser(t *testing.T, c *mongo.Client, dbName, uid string, balance int64) string {
	t.Helper()
	_, err := c.Database(dbName).Collection("users").InsertOne(context.Background(), bson.M{"_id": uid, "coins": balance})
	if err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return uid
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

func TestGrant_ValidatesArguments(t *testing.T) {
	c, db := mongoForTest(t)
	seedUser(t, c, db, "u1", 0)
	l := coins.NewLedger(c, db)
	ctx := context.Background()

	if _, err := l.Grant(ctx, "u1", 0, coins.ReasonMatchWin, "match:zero", nil); !errors.Is(err, coins.ErrAmountInvalid) {
		t.Errorf("zero delta: got %v, want ErrAmountInvalid", err)
	}
	if _, err := l.Grant(ctx, "u1", 10, "not.a.real.reason", "match:1", nil); !errors.Is(err, coins.ErrUnknownReason) {
		t.Errorf("bogus reason: got %v, want ErrUnknownReason", err)
	}
	if _, err := l.Grant(ctx, "u1", 10, coins.ReasonMatchWin, "", nil); !errors.Is(err, coins.ErrMissingRefID) {
		t.Errorf("empty refID: got %v, want ErrMissingRefID", err)
	}
}

func TestGetLedger_PagedNewestFirst(t *testing.T) {
	c, db := mongoForTest(t)
	seedUser(t, c, db, "u1", 0)
	l := coins.NewLedger(c, db)

	for i := 0; i < 5; i++ {
		_, err := l.Grant(context.Background(), "u1", 10, coins.ReasonMatchWin, fmt.Sprintf("match:%d", i), nil)
		if err != nil {
			t.Fatalf("seed grant: %v", err)
		}
		time.Sleep(2 * time.Millisecond) // distinct createdAt
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
