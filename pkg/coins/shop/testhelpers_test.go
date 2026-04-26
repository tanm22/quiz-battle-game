package shop_test

import (
	"context"
	"os"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// mongoForTest connects to the local replica-set Mongo, creates a unique
// per-test database, ensures the shop indexes the package depends on, and
// schedules cleanup. Mirrors the helper in pkg/coins/ledger_test.go so the
// two packages can share an integration story without copy-paste drift.
//
// Tests that don't have Mongo available are skipped, not failed: a
// developer running `go test ./...` on a fresh checkout without the
// docker-compose stack should see a clean SKIP, not a crash.
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
	dbName := "shop_test_" + bson.NewObjectID().Hex()
	t.Cleanup(func() {
		bg := context.Background()
		_ = c.Database(dbName).Drop(bg)
		_ = c.Disconnect(bg)
	})

	// coin_ledger needs the same idempotency index Purchase relies on. The
	// shop package's tests exercise Buy end-to-end, so without this index
	// the unique-key duplicate-detection fast path would never trigger.
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

// seedUser inserts a users-collection document with the given balance and
// returns the uid for chained use. Returning the uid lets call sites read
// like `uid := seedUser(...)` rather than threading the literal twice.
func seedUser(t *testing.T, c *mongo.Client, dbName, uid string, balance int64) string {
	t.Helper()
	_, err := c.Database(dbName).Collection("users").InsertOne(
		context.Background(),
		bson.M{"_id": uid, "username": uid, "coins": balance},
	)
	if err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return uid
}
