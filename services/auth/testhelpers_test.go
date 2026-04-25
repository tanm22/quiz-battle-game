package main

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// newTestAuthServer connects to the local Mongo (MONGO_URI env or
// localhost:27017) and creates a fresh, unique database that the
// caller exclusively owns for the duration of the test.
//
// The database is dropped via t.Cleanup so tests stay isolated.
func newTestAuthServer(t *testing.T) *authServer {
	t.Helper()

	uri := os.Getenv("MONGO_URI")
	if uri == "" {
		uri = "mongodb://localhost:27017"
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

	dbName := fmt.Sprintf("authtest_%d_%s", time.Now().UnixNano(), t.Name())
	db := client.Database(dbName)

	t.Cleanup(func() {
		_ = db.Drop(context.Background())
		_ = client.Disconnect(context.Background())
	})

	return &authServer{
		mongoDB:   db,
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
