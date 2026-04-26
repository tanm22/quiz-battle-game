package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"quiz-battle/pkg/coins"
)

// newTestAuthServer connects to the local Mongo replica set (MONGO_URI env
// or localhost rs0 default) and creates a fresh, unique database that the
// caller exclusively owns for the duration of the test.
//
// We default to ?replicaSet=rs0&directConnection=true because §4.3 ledger
// writes use Mongo transactions, which require a session against a replica
// set. Tests that don't need transactions still work against this URI.
//
// The database is dropped via t.Cleanup so tests stay isolated.
func newTestAuthServer(t *testing.T) *authServer {
	t.Helper()

	uri := os.Getenv("MONGO_URI")
	if uri == "" {
		uri = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(options.Client().ApplyURI(uri))
	if err != nil {
		t.Fatalf("mongo.Connect: %v", err)
	}
	if err := client.Ping(ctx, nil); err != nil {
		t.Fatalf("mongo.Ping: %v (is docker compose up?)", err)
	}

	// Mongo caps database names at 63 bytes; long Go test names blow past that
	// when concatenated with the unixnano. Truncate the test-name suffix so we
	// stay safely under the limit while still keeping it grep-friendly.
	suffix := strings.ReplaceAll(t.Name(), "/", "_")
	if len(suffix) > 24 {
		suffix = suffix[:24]
	}
	dbName := fmt.Sprintf("authtest_%d_%s", time.Now().UnixNano(), suffix)
	db := client.Database(dbName)

	// Ensure the idempotency index exists so ledger.Grant's duplicate-key
	// path works in tests just like it does after the seed service runs.
	_, _ = db.Collection("coin_ledger").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "userId", Value: 1}, {Key: "refId", Value: 1}, {Key: "reason", Value: 1}},
		Options: options.Index().SetUnique(true).SetName("uniq_user_ref_reason"),
	})

	t.Cleanup(func() {
		_ = db.Drop(context.Background())
		_ = client.Disconnect(context.Background())
	})

	return &authServer{
		mongoDB:   db,
		ledger:    coins.NewLedger(client, dbName),
		jwtSecret: "test-jwt-secret",
	}
}

// createTestUser inserts a minimal user document and returns its ID.
func createTestUser(t *testing.T, srv *authServer, username string) string {
	t.Helper()
	id := fmt.Sprintf("user_%s_%d", username, time.Now().UnixNano())
	_, err := srv.users().InsertOne(context.Background(), bson.M{
		"_id":           id,
		"username":      username,
		"isGuest":       false,
		"rating":        1200,
		"matchesPlayed": int32(0),
		"wins":          int32(0),
		"plan":          "free",
		"coins":         int64(0),
		"createdAt":     time.Now().Unix(),
	})
	if err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return id
}
