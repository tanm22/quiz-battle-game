package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"golang.org/x/crypto/bcrypt"
)

type Question struct {
	Text              string   `json:"text" bson:"text"`
	Options           []string `json:"options" bson:"options"`
	CorrectIndex      int      `json:"correctIndex" bson:"correctIndex"`
	Difficulty        string   `json:"difficulty" bson:"difficulty"`
	Topic             string   `json:"topic" bson:"topic"`
	AvgResponseTimeMs int      `json:"avgResponseTimeMs" bson:"avgResponseTimeMs"`
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017/quizbattle"
	}

	client, err := mongo.Connect(options.Client().ApplyURI(mongoURI))
	if err != nil {
		log.Fatalf("mongo connect: %v", err)
	}
	defer client.Disconnect(ctx)

	db := client.Database("quizbattle")

	// --- Create indexes ---
	log.Println("[seed] creating indexes...")

	usersColl := db.Collection("users")
	usersColl.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "username", Value: 1}},
		Options: options.Index().SetUnique(true),
	})
	usersColl.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "email", Value: 1}},
		Options: options.Index().SetUnique(true).SetSparse(true),
	})

	questionsColl := db.Collection("questions")
	questionsColl.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys: bson.D{{Key: "difficulty", Value: 1}},
	})

	db.Collection("match_history").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "roomId", Value: 1}},
		Options: options.Index().SetUnique(true),
	})
	db.Collection("match_history").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys: bson.D{{Key: "players.userId", Value: 1}},
	})

	// Phase 2 indexes
	usersColl.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "googleId", Value: 1}},
		Options: options.Index().SetUnique(true).SetSparse(true),
	})
	usersColl.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "referralCode", Value: 1}},
		Options: options.Index().SetUnique(true).SetSparse(true),
	})
	usersColl.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys: bson.D{{Key: "plan", Value: 1}, {Key: "planExpiresAt", Value: 1}},
	})

	paymentsColl := db.Collection("payments")
	paymentsColl.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "razorpayOrderId", Value: 1}},
		Options: options.Index().SetUnique(true),
	})
	paymentsColl.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys: bson.D{{Key: "userId", Value: 1}},
	})

	referralsColl := db.Collection("referrals")
	referralsColl.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "refereeId", Value: 1}},
		Options: options.Index().SetUnique(true),
	})
	referralsColl.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys: bson.D{{Key: "referrerId", Value: 1}},
	})

	db.Collection("tournaments").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys: bson.D{{Key: "startTime", Value: 1}, {Key: "status", Value: 1}},
	})

	log.Println("[seed] indexes created")

	// --- Seed questions ---
	data, err := os.ReadFile("questions.json")
	if err != nil {
		// Try alternate path (when run from project root)
		data, err = os.ReadFile("seed/questions.json")
		if err != nil {
			log.Fatalf("read questions.json: %v", err)
		}
	}

	var questions []Question
	if err := json.Unmarshal(data, &questions); err != nil {
		log.Fatalf("parse questions.json: %v", err)
	}

	// Upsert questions to avoid duplicates on re-run
	for i, q := range questions {
		filter := bson.M{"text": q.Text}
		update := bson.M{"$setOnInsert": q}
		_, err := questionsColl.UpdateOne(ctx, filter, update, options.UpdateOne().SetUpsert(true))
		if err != nil {
			log.Printf("[seed] question %d upsert error: %v", i, err)
		}
	}
	count, _ := questionsColl.CountDocuments(ctx, bson.M{})
	log.Printf("[seed] %d questions in database", count)

	// --- Seed test users ---
	testUsers := []struct {
		Username string
		Password string
		Rating   int32
		Wins     int32
		Played   int32
	}{
		{"alice", "testpass123", 1400, 15, 20},
		{"bob", "testpass123", 1250, 8, 18},
		{"charlie", "testpass123", 1100, 5, 15},
		{"diana", "testpass123", 1350, 12, 22},
		{"eve", "testpass123", 950, 3, 12},
		{"frank", "testpass123", 1500, 20, 25},
	}

	for _, u := range testUsers {
		hash, _ := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.DefaultCost)
		id := fmt.Sprintf("user_%s", u.Username)
		refCode := fmt.Sprintf("REF%s", u.Username[:4])
		doc := bson.M{
			"_id":           id,
			"username":      u.Username,
			"passwordHash":  string(hash),
			"isGuest":       false,
			"rating":        u.Rating,
			"matchesPlayed": u.Played,
			"wins":          u.Wins,
			"plan":          "free",
			"coins":         int64(0),
			"referralCode":  refCode,
			"streak":        bson.M{"current": 0, "longest": 0, "lastClaimedDate": ""},
			"createdAt":     time.Now().Unix(),
		}
		_, err := usersColl.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$setOnInsert": doc}, options.UpdateOne().SetUpsert(true))
		if err != nil {
			log.Printf("[seed] user %s upsert error: %v", u.Username, err)
		}
	}
	userCount, _ := usersColl.CountDocuments(ctx, bson.M{})
	log.Printf("[seed] %d users in database", userCount)

	log.Println("[seed] done")
}
