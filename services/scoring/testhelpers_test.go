package main

import (
	"context"
	"os"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"quiz-battle/pkg/coins"
)

// mongoForTest dials the rs0 Mongo (transactions are required by
// coins.Ledger) and provisions a per-test database name so test runs
// don't leak state into each other. Skips gracefully when MONGO_URI
// isn't reachable — local devs run docker compose up first; CI runs an
// rs0 sidecar.
func mongoForTest(t *testing.T) (*mongo.Client, string) {
	t.Helper()
	uri := os.Getenv("MONGO_URI")
	if uri == "" {
		uri = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true"
	}
	c, err := mongo.Connect(options.Client().ApplyURI(uri).SetBSONOptions(&options.BSONOptions{
		ObjectIDAsHexString: true,
	}))
	if err != nil {
		t.Skipf("mongo unavailable: %v", err)
	}
	pingCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := c.Ping(pingCtx, nil); err != nil {
		t.Skipf("mongo ping failed: %v", err)
	}
	dbName := "scoring_test_" + bson.NewObjectID().Hex()
	t.Cleanup(func() {
		_ = c.Database(dbName).Drop(context.Background())
		_ = c.Disconnect(context.Background())
	})
	// Mirror seed: the unique index is what enforces dup-key on idempotency
	// in the same shape as production.
	_, _ = c.Database(dbName).Collection("coin_ledger").Indexes().CreateOne(
		context.Background(),
		mongo.IndexModel{
			Keys:    bson.D{{Key: "userId", Value: 1}, {Key: "refId", Value: 1}, {Key: "reason", Value: 1}},
			Options: options.Index().SetUnique(true),
		},
	)
	return c, dbName
}

// newTestScoringServer builds a scoringServer with just the fields the
// coin-earn / handleEarnEvent path needs: mongoClient, mongoDB, dbName,
// ledger. Redis and RabbitMQ are intentionally left nil — handlers that
// touch them aren't exercised by these tests.
func newTestScoringServer(t *testing.T) *scoringServer {
	t.Helper()
	client, dbName := mongoForTest(t)
	return &scoringServer{
		mongoClient: client,
		mongoDB:     client.Database(dbName),
		dbName:      dbName,
		ledger:      coins.NewLedger(client, dbName),
	}
}

// createTestUserWithCoins inserts a user document with the given starting
// balance and returns the userId, mirroring the seed pattern's
// "_id == username" so test references stay readable. Tests that need a
// random userId can ignore the returned value.
func createTestUserWithCoins(t *testing.T, srv *scoringServer, username string, balance int64) string {
	t.Helper()
	uid := username
	_, err := srv.mongoDB.Collection("users").InsertOne(context.Background(), bson.M{
		"_id":      uid,
		"username": username,
		"coins":    balance,
		"plan":     "free",
	})
	if err != nil {
		t.Fatalf("insert test user: %v", err)
	}
	return uid
}
