package main

import (
	"context"
	"os"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/coins"
	pb "quiz-battle/proto"
)

// scoringTestEnv is a minimal scoringServer wired to a real Mongo replica
// set with just the fields the coin RPCs touch. We don't stand up Redis or
// RabbitMQ — those handlers don't exercise them.
func scoringTestEnv(t *testing.T) (*scoringServer, *mongo.Client, string) {
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
	dbName := "scoring_test_" + bson.NewObjectID().Hex()
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
	srv := &scoringServer{
		mongoDB: c.Database(dbName),
		ledger:  coins.NewLedger(c, dbName),
	}
	return srv, c, dbName
}

func seedScoringUser(t *testing.T, c *mongo.Client, dbName, uid string, balance int64) {
	t.Helper()
	_, err := c.Database(dbName).Collection("users").InsertOne(context.Background(),
		bson.M{"_id": uid, "username": uid, "coins": balance})
	if err != nil {
		t.Fatalf("seed user: %v", err)
	}
}

func TestGetCoinBalance_RequiresAuth(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	_, err := srv.GetCoinBalance(context.Background(), &pb.GetCoinBalanceRequest{})
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("got %v, want Unauthenticated", err)
	}
}

func TestGetCoinBalance_ReturnsCachedBalance(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 250)
	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: "alice", Username: "alice"})

	resp, err := srv.GetCoinBalance(ctx, &pb.GetCoinBalanceRequest{})
	if err != nil {
		t.Fatalf("GetCoinBalance: %v", err)
	}
	if resp.Balance != 250 {
		t.Errorf("got %d, want 250", resp.Balance)
	}
}

func TestGetCoinLedger_RequiresAuth(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	_, err := srv.GetCoinLedger(context.Background(), &pb.GetCoinLedgerRequest{})
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("got %v, want Unauthenticated", err)
	}
}

func TestGetCoinLedger_ReturnsRecentEntries(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	for i := 0; i < 3; i++ {
		if _, err := srv.ledger.Grant(context.Background(), "alice", 50, coins.ReasonMatchWin,
			"match:"+bson.NewObjectID().Hex(), map[string]string{"i": string(rune('0' + i))}); err != nil {
			t.Fatalf("seed grant: %v", err)
		}
		time.Sleep(2 * time.Millisecond)
	}

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: "alice", Username: "alice"})
	resp, err := srv.GetCoinLedger(ctx, &pb.GetCoinLedgerRequest{PageSize: 10})
	if err != nil {
		t.Fatalf("GetCoinLedger: %v", err)
	}
	if len(resp.Entries) != 3 {
		t.Fatalf("got %d entries, want 3", len(resp.Entries))
	}
	if resp.Entries[0].Delta != 50 || resp.Entries[0].Reason != coins.ReasonMatchWin {
		t.Errorf("entry shape unexpected: %+v", resp.Entries[0])
	}
	if resp.Entries[0].CreatedAtUnixMs == 0 {
		t.Errorf("createdAtUnixMs should be populated")
	}
	if resp.NextPageToken != "" {
		t.Errorf("only 3 entries — expected empty cursor, got %q", resp.NextPageToken)
	}
}
