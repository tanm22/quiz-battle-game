//go:build phase2verify

// Phase 2 edge case: a user with ZERO match_history entries — the async
// goroutine should exit cleanly without publishing anything.
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
	mongoURI   = "mongodb://localhost:27017/quizbattle"
	mmAddr     = "localhost:50051"
	jwtSecret  = "change-me-in-production"
	newbieID   = "mi_test_newbie"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	mc, err := mongo.Connect(options.Client().ApplyURI(mongoURI).SetBSONOptions(&options.BSONOptions{
		ObjectIDAsHexString: true,
	}))
	if err != nil {
		log.Fatal(err)
	}
	defer mc.Disconnect(ctx)
	db := mc.Database("quizbattle")

	_, _ = db.Collection("users").DeleteMany(ctx, bson.M{"_id": newbieID})
	_, _ = db.Collection("users").DeleteMany(ctx, bson.M{"username": "phase2_newbie"})
	_, _ = db.Collection("match_history").DeleteMany(ctx, bson.M{"players.userId": newbieID})

	_, err = db.Collection("users").InsertOne(ctx, bson.M{
		"_id":       newbieID,
		"username":  "phase2_newbie",
		"rating":    int32(1200),
		"plan":      "premium",
		"createdAt": time.Now(),
	})
	if err != nil {
		log.Fatal(err)
	}

	token, err := auth.GenerateToken(newbieID, "phase2_newbie", jwtSecret)
	if err != nil {
		log.Fatal(err)
	}

	conn, err := grpc.NewClient(mmAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()
	client := pb.NewMatchmakingServiceClient(conn)

	rpcCtx := metadata.AppendToOutgoingContext(ctx, "authorization", "Bearer "+token)
	_, _ = client.LeaveMatchmaking(rpcCtx, &pb.LeaveMatchmakingRequest{UserId: newbieID})

	resp, err := client.JoinMatchmaking(rpcCtx, &pb.JoinMatchmakingRequest{
		UserId: newbieID,
		Rating: 1200,
	})
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("[newbie] JoinMatchmaking status=%s\n", resp.Status.String())

	time.Sleep(2 * time.Second)
	_, _ = client.LeaveMatchmaking(rpcCtx, &pb.LeaveMatchmakingRequest{UserId: newbieID})
	fmt.Println("[newbie] done — no match_history → no invites expected")
}
