//go:build phase2verify

// Phase 2 integration test for notif.match.invite fan-out.
//
// Seeds 1 inviter (A) and 2 opponents (B, C) with FCM tokens, plants a
// match_history doc where A played both, then calls JoinMatchmaking as A
// and verifies the backend path (throttle + publish) is hit.
//
// Tail notification logs after running to confirm dispatches:
//
//	docker compose logs --tail=30 notification
//
// Run: go run -tags phase2verify ./test/matchinvite/
package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"

	"quiz-battle/pkg/auth"
	pb "quiz-battle/proto"
)

const (
	mongoURI  = "mongodb://localhost:27017/quizbattle"
	mmAddr    = "localhost:50051"
	jwtSecret = "change-me-in-production"

	inviterID = "mi_test_inviter"
	opponent1 = "mi_test_opp1"
	opponent2 = "mi_test_opp2"
)

func must(err error, msg string) {
	if err != nil {
		log.Fatalf("%s: %v", msg, err)
	}
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	// ------------------------------------------------------------------
	// 1. MongoDB setup — seed users (with FCM tokens on opponents) and a
	//    match_history doc where the inviter played both opponents.
	// ------------------------------------------------------------------
	mc, err := mongo.Connect(options.Client().ApplyURI(mongoURI).SetBSONOptions(&options.BSONOptions{
		ObjectIDAsHexString: true,
	}))
	must(err, "mongo connect")
	defer mc.Disconnect(ctx)
	db := mc.Database("quizbattle")

	// Clean any prior runs so the test is repeatable.
	_, _ = db.Collection("users").DeleteMany(ctx, bson.M{"_id": bson.M{"$in": bson.A{inviterID, opponent1, opponent2}}})
	// Also clean by username since there's a unique index on username and
	// leftover docs from unrelated tests/seeds may collide.
	_, _ = db.Collection("users").DeleteMany(ctx, bson.M{"username": bson.M{"$in": bson.A{"inviter_alice", "phase2_bob", "phase2_carol"}}})
	_, _ = db.Collection("match_history").DeleteMany(ctx, bson.M{"roomId": "mi_test_room_1"})

	usersColl := db.Collection("users")
	_, err = usersColl.InsertMany(ctx, []interface{}{
		bson.M{
			"_id":       inviterID,
			"username":  "inviter_alice",
			"rating":    int32(1450),
			"plan":      "premium", // skip the daily quota gate
			"createdAt": time.Now(),
		},
		bson.M{
			"_id":       opponent1,
			"username":  "phase2_bob",
			"rating":    int32(1420),
			"plan":      "free",
			"fcmTokens": bson.A{"fake_token_bob_phase2"},
			"createdAt": time.Now(),
		},
		bson.M{
			"_id":       opponent2,
			"username":  "phase2_carol",
			"rating":    int32(1480),
			"plan":      "free",
			"fcmTokens": bson.A{"fake_token_carol_phase2"},
			"createdAt": time.Now(),
		},
	})
	must(err, "insert users")

	_, err = db.Collection("match_history").InsertOne(ctx, bson.M{
		"roomId":    "mi_test_room_1",
		"winner":    inviterID,
		"rounds":    int32(5),
		"duration":  int64(180),
		"createdAt": time.Now().Add(-1 * time.Hour),
		"players": bson.A{
			bson.M{"userId": inviterID, "username": "inviter_alice", "finalScore": 800.0, "rank": int32(1), "answersCorrect": int32(4), "avgResponseTimeMs": 3200.0},
			bson.M{"userId": opponent1, "username": "phase2_bob", "finalScore": 600.0, "rank": int32(2), "answersCorrect": int32(3), "avgResponseTimeMs": 4100.0},
			bson.M{"userId": opponent2, "username": "phase2_carol", "finalScore": 500.0, "rank": int32(3), "answersCorrect": int32(2), "avgResponseTimeMs": 4700.0},
		},
	})
	must(err, "insert match_history")

	log.Println("[test] seeded 3 users + 1 match_history doc")

	// ------------------------------------------------------------------
	// 2. Mint JWT for the inviter and dial matchmaking.
	// ------------------------------------------------------------------
	token, err := auth.GenerateToken(inviterID, "inviter_alice", jwtSecret)
	must(err, "mint token")

	conn, err := grpc.NewClient(mmAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	must(err, "grpc dial")
	defer conn.Close()
	client := pb.NewMatchmakingServiceClient(conn)

	// Clear inviter from pool in case of prior test runs.
	rpcCtx := metadata.AppendToOutgoingContext(ctx, "authorization", "Bearer "+token)
	_, _ = client.LeaveMatchmaking(rpcCtx, &pb.LeaveMatchmakingRequest{UserId: inviterID})

	// ------------------------------------------------------------------
	// 3. Call JoinMatchmaking — this should fan-out match invites async.
	// ------------------------------------------------------------------
	resp, err := client.JoinMatchmaking(rpcCtx, &pb.JoinMatchmakingRequest{
		UserId: inviterID,
		Rating: 1450,
	})
	must(err, "join matchmaking")
	fmt.Printf("[test] JoinMatchmaking status=%s\n", resp.Status.String())

	// Give the async goroutine time to publish.
	time.Sleep(2 * time.Second)

	// Clean up: leave pool so we don't block the poller.
	_, _ = client.LeaveMatchmaking(rpcCtx, &pb.LeaveMatchmakingRequest{UserId: inviterID})

	fmt.Println("[test] done — check notification logs for match invite dispatches to bob + carol")
}
