package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math"
	"net"
	"os"
	"sync"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"golang.org/x/sync/errgroup"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/coins"
	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/models"
	pb "quiz-battle/proto"
)

// ---------------------------------------------------------------------------
// Question document (for looking up correct answers)
// ---------------------------------------------------------------------------

type Question struct {
	ID           string   `bson:"_id,omitempty"`
	Text         string   `bson:"text"`
	Options      []string `bson:"options"`
	CorrectIndex int      `bson:"correctIndex"`
	Topic        string   `bson:"topic"`
}

// ---------------------------------------------------------------------------
// Server struct
// ---------------------------------------------------------------------------

type scoringServer struct {
	pb.UnimplementedScoringServiceServer
	rdb        *redis.Client
	amqpConn   *amqp.Connection
	amqpCh     *amqp.Channel // for publishing only
	amqpMu     sync.Mutex    // AMQP channels are not thread-safe
	mongoDB    *mongo.Database
	ledger     *coins.Ledger // §4.3 — every balance change goes through Grant
	jwtSecret  string
	selfClient pb.ScoringServiceClient // gRPC loopback client for CalculateScore
}

// publish sends a message to the topic exchange with mutex protection. In
// tests where amqpCh is left nil (we don't stand up RabbitMQ for unit tests
// that only exercise Mongo state), publish is a no-op so callers don't need
// to special-case the test seam.
func (s *scoringServer) publish(ctx context.Context, routingKey string, body []byte) error {
	s.amqpMu.Lock()
	defer s.amqpMu.Unlock()
	if s.amqpCh == nil {
		return nil
	}
	return s.amqpCh.PublishWithContext(ctx, "sx", routingKey, false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        body,
	})
}

// newChannel creates a dedicated AMQP channel per consumer (channels are not thread-safe).
func (s *scoringServer) newChannel() (*amqp.Channel, error) {
	return s.amqpConn.Channel()
}

// ---------------------------------------------------------------------------
// 47. CalculateScore gRPC
// ---------------------------------------------------------------------------

func (s *scoringServer) CalculateScore(ctx context.Context, req *pb.CalculateScoreRequest) (*pb.CalculateScoreResponse, error) {
	// Look up correct answer from MongoDB
	correct, err := s.isCorrect(ctx, req.RoomId, int(req.Round), int(req.OptionIndex))
	if err != nil {
		return nil, fmt.Errorf("failed to check answer: %w", err)
	}

	// basePoints = 100 * (1 if correct, 0 if wrong)
	var basePoints float64
	if correct {
		basePoints = 100
	}

	// speedMultiplier: <5000ms → 1.5, >13000ms → 0.8, else 1.0
	speedMultiplier := 1.0
	if req.AnswerTimeMs < 5000 {
		speedMultiplier = 1.5
	} else if req.AnswerTimeMs > 13000 {
		speedMultiplier = 0.8
	}

	score := basePoints * speedMultiplier

	return &pb.CalculateScoreResponse{
		Score:           score,
		Correct:         correct,
		SpeedMultiplier: speedMultiplier,
	}, nil
}

// isCorrect looks up the question for a given room+round and checks the answer.
func (s *scoringServer) isCorrect(ctx context.Context, roomID string, round, optionIndex int) (bool, error) {
	// Get question ID from Redis list (0-indexed, round is 1-indexed)
	questionIDs, err := keys.GetQuestions(ctx, s.rdb, roomID)
	if err != nil || round < 1 || round > len(questionIDs) {
		return false, fmt.Errorf("question lookup failed: %w", err)
	}

	qID := questionIDs[round-1]

	// Look up correct index from MongoDB
	var q Question
	err = s.mongoDB.Collection("questions").FindOne(ctx, bson.M{"_id": qID}).Decode(&q)
	if err != nil {
		// Fallback: try with ObjectID
		objID, parseErr := bson.ObjectIDFromHex(qID)
		if parseErr != nil {
			return false, fmt.Errorf("invalid question ID %s: %w", qID, err)
		}
		err = s.mongoDB.Collection("questions").FindOne(ctx, bson.M{"_id": objID}).Decode(&q)
		if err != nil {
			return false, fmt.Errorf("question not found %s: %w", qID, err)
		}
	}

	return optionIndex == q.CorrectIndex, nil
}

// ---------------------------------------------------------------------------
// 51. GetLeaderboard gRPC — ZREVRANGE room:{id}:leaderboard 0 -1 WITHSCORES
// ---------------------------------------------------------------------------

func (s *scoringServer) GetLeaderboard(ctx context.Context, req *pb.GetLeaderboardRequest) (*pb.GetLeaderboardResponse, error) {
	entries, err := keys.GetLeaderboardEntries(ctx, s.rdb, req.RoomId)
	if err != nil {
		return nil, fmt.Errorf("leaderboard fetch failed: %w", err)
	}

	pbEntries := make([]*pb.LeaderboardEntry, len(entries))
	for i, e := range entries {
		userID := e.Member.(string)
		// Resolve real username + plan from Redis player info
		username := userID
		ePlan := "free"
		if playerJSON, err := keys.GetPlayer(ctx, s.rdb, req.RoomId, userID); err == nil {
			var info struct {
				Username string `json:"username"`
				Plan     string `json:"plan"`
			}
			if json.Unmarshal([]byte(playerJSON), &info) == nil {
				if info.Username != "" {
					username = info.Username
				}
				if info.Plan != "" {
					ePlan = info.Plan
				}
			}
		}
		pbEntries[i] = &pb.LeaderboardEntry{
			UserId:   userID,
			Username: username,
			Score:    e.Score,
			Rank:     int32(i + 1),
			Plan:     ePlan,
		}
	}

	return &pb.GetLeaderboardResponse{Entries: pbEntries}, nil
}

// ---------------------------------------------------------------------------
// GetMatchHistory — returns past matches for the authenticated user
// ---------------------------------------------------------------------------

func (s *scoringServer) GetMatchHistory(ctx context.Context, req *pb.GetMatchHistoryRequest) (*pb.GetMatchHistoryResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, fmt.Errorf("auth: %w", err)
	}

	// Feature gating: free users see last 3, premium sees full history
	plan, _ := keys.GetPlan(ctx, s.rdb, userID)
	if plan == "" {
		var doc bson.M
		if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&doc); err == nil {
			if p, ok := doc["plan"].(string); ok {
				plan = p
			}
		}
		if plan == "" {
			plan = "free"
		}
		keys.SetPlan(ctx, s.rdb, userID, plan)
	}

	limit := int64(req.Limit)
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	if plan != "premium" && limit > 3 {
		limit = 3
	}
	skip := int64(req.Offset)
	if skip < 0 {
		skip = 0
	}

	coll := s.mongoDB.Collection("match_history")
	cursor, err := coll.Find(ctx,
		bson.M{"players.userId": userID},
		options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}}).SetLimit(limit).SetSkip(skip),
	)
	if err != nil {
		return nil, fmt.Errorf("query match_history: %w", err)
	}
	defer cursor.Close(ctx)

	var matches []*pb.MatchHistoryEntry
	for cursor.Next(ctx) {
		var doc struct {
			RoomID    string    `bson:"roomId"`
			Winner    string    `bson:"winner"`
			Rounds    int32     `bson:"rounds"`
			Duration  int64     `bson:"duration"`
			CreatedAt time.Time `bson:"createdAt"`
			Players   []struct {
				UserID            string  `bson:"userId"`
				Username          string  `bson:"username"`
				FinalScore        float64 `bson:"finalScore"`
				Rank              int32   `bson:"rank"`
				AnswersCorrect    int32   `bson:"answersCorrect"`
				AvgResponseTimeMs float64 `bson:"avgResponseTimeMs"`
			} `bson:"players"`
		}
		if err := cursor.Decode(&doc); err != nil {
			continue
		}

		players := make([]*pb.PlayerResult, len(doc.Players))
		for i, p := range doc.Players {
			players[i] = &pb.PlayerResult{
				UserId:            p.UserID,
				Username:          p.Username,
				FinalScore:        p.FinalScore,
				Rank:              p.Rank,
				AnswersCorrect:    p.AnswersCorrect,
				AvgResponseTimeMs: p.AvgResponseTimeMs,
			}
		}

		matches = append(matches, &pb.MatchHistoryEntry{
			RoomId:    doc.RoomID,
			Winner:    doc.Winner,
			Players:   players,
			Rounds:    doc.Rounds,
			Duration:  doc.Duration,
			CreatedAt: doc.CreatedAt.Unix(),
		})
	}

	return &pb.GetMatchHistoryResponse{Matches: matches}, nil
}

// ---------------------------------------------------------------------------
// Phase 2: GetHomeScreenData — parallel fan-out (ISSUE-10)
// ---------------------------------------------------------------------------

func (s *scoringServer) GetHomeScreenData(ctx context.Context, _ *pb.GetHomeScreenDataRequest) (*pb.GetHomeScreenDataResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	// Fetch plan first (needed by leaderboard query below)
	plan, _ := keys.GetPlan(ctx, s.rdb, userID)
	if plan == "" {
		var doc bson.M
		if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&doc); err == nil {
			if p, ok := doc["plan"].(string); ok {
				plan = p
			}
		}
		if plan == "" {
			plan = "free"
		}
		keys.SetPlan(ctx, s.rdb, userID, plan)
	}

	var user models.User
	var quotaUsed int64
	var lbPreview []*pb.LeaderboardEntry

	g, gctx := errgroup.WithContext(ctx)

	// [1] Fetch user profile + streak from MongoDB
	g.Go(func() error {
		return s.mongoDB.Collection("users").FindOne(gctx, bson.M{"_id": userID}).Decode(&user)
	})

	// [2] Fetch quota usage from Redis
	g.Go(func() error {
		var err error
		quotaUsed, err = keys.GetQuotaUsed(gctx, s.rdb, userID)
		return err
	})

	// [3] Fetch leaderboard preview from MongoDB (top users by rating)
	g.Go(func() error {
		limit := int64(3)
		if plan == "premium" {
			limit = 10
		}
		cursor, err := s.mongoDB.Collection("users").Find(gctx,
			bson.M{},
			options.Find().SetSort(bson.D{{Key: "rating", Value: -1}}).SetLimit(limit),
		)
		if err != nil {
			return err
		}
		defer cursor.Close(gctx)
		rank := int32(1)
		for cursor.Next(gctx) {
			var u bson.M
			if err := cursor.Decode(&u); err != nil {
				continue
			}
			uid, _ := u["_id"].(string)
			uname, _ := u["username"].(string)
			rating := int32(1200)
			if r, ok := u["rating"].(int32); ok {
				rating = r
			}
			uplan, _ := u["plan"].(string)
			if uplan == "" {
				uplan = "free"
			}
			lbPreview = append(lbPreview, &pb.LeaderboardEntry{
				UserId:   uid,
				Username: uname,
				Score:    float64(rating),
				Rank:     rank,
				Plan:     uplan,
			})
			rank++
		}
		return nil
	})

	if err := g.Wait(); err != nil {
		return nil, status.Errorf(codes.Internal, "home data fetch failed: %v", err)
	}

	if user.Plan == "" {
		user.Plan = "free"
	}
	quotaLimit := int32(1)
	if user.Plan == "premium" {
		quotaLimit = 999 // unlimited
	}

	var accuracy float32
	if user.TotalAnswers > 0 {
		accuracy = float32(user.CorrectAnswers) / float32(user.TotalAnswers) * 100
	}

	return &pb.GetHomeScreenDataResponse{
		Profile: &pb.UserProfile{
			UserId:        user.ID,
			Username:      user.Username,
			DisplayName:   user.DisplayName,
			Email:         user.Email,
			AvatarUrl:     user.AvatarUrl,
			Rating:        user.Rating,
			MatchesPlayed: user.MatchesPlayed,
			Wins:          user.Wins,
			Plan:          user.Plan,
			Coins:         user.Coins,
			Streak: &pb.StreakInfo{
				Current:         int32(user.Streak.Current),
				Longest:         int32(user.Streak.Longest),
				LastClaimedDate: user.Streak.LastClaimedDate,
			},
			ReferralCode:        user.ReferralCode,
			IsGuest:             user.IsGuest,
			AccuracyPercent:     accuracy,
			WinStreak:           user.WinStreak,
			PreferredTopics:     user.PreferredTopics,
			OnboardingCompleted: user.OnboardingCompleted,
		},
		QuotaRemaining:     int32(int64(quotaLimit) - quotaUsed),
		QuotaLimit:         quotaLimit,
		LeaderboardPreview: lbPreview,
	}, nil
}

// ---------------------------------------------------------------------------
// Phase 3: GetGlobalLeaderboard — time-filtered, plan-gated
// ---------------------------------------------------------------------------

func (s *scoringServer) GetGlobalLeaderboard(ctx context.Context, req *pb.GetGlobalLeaderboardRequest) (*pb.GetGlobalLeaderboardResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	// Get user plan for result limiting
	plan, _ := keys.GetPlan(ctx, s.rdb, userID)
	if plan == "" {
		var doc bson.M
		if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&doc); err == nil {
			if p, ok := doc["plan"].(string); ok {
				plan = p
			}
		}
		if plan == "" {
			plan = "free"
		}
		keys.SetPlan(ctx, s.rdb, userID, plan)
	}

	limit := int64(3)
	if plan == "premium" {
		limit = 50
	}

	filter := req.TimeFilter
	if filter == "" {
		filter = "alltime"
	}

	var entries []*pb.LeaderboardEntry

	switch filter {
	case "daily", "weekly":
		// Aggregate wins from match_history within time window
		var since time.Time
		now := time.Now()
		if filter == "daily" {
			since = time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
		} else {
			// Start of current week (Monday)
			weekday := int(now.Weekday())
			if weekday == 0 {
				weekday = 7
			}
			since = time.Date(now.Year(), now.Month(), now.Day()-(weekday-1), 0, 0, 0, 0, now.Location())
		}

		pipeline := mongo.Pipeline{
			{{Key: "$match", Value: bson.M{"createdAt": bson.M{"$gte": since}}}},
			{{Key: "$unwind", Value: "$players"}},
			{{Key: "$group", Value: bson.M{
				"_id":        "$players.userId",
				"username":   bson.M{"$last": "$players.username"},
				"totalScore": bson.M{"$sum": "$players.finalScore"},
				"wins":       bson.M{"$sum": bson.M{"$cond": bson.A{bson.M{"$eq": bson.A{"$winner", "$players.userId"}}, 1, 0}}},
			}}},
			{{Key: "$sort", Value: bson.D{{Key: "totalScore", Value: -1}}}},
			{{Key: "$limit", Value: limit}},
		}

		cursor, err := s.mongoDB.Collection("match_history").Aggregate(ctx, pipeline)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "aggregation failed: %v", err)
		}
		defer cursor.Close(ctx)

		rank := int32(1)
		for cursor.Next(ctx) {
			var doc struct {
				UserID     string  `bson:"_id"`
				Username   string  `bson:"username"`
				TotalScore float64 `bson:"totalScore"`
			}
			if cursor.Decode(&doc) != nil {
				continue
			}
			// Resolve plan for badge display
			userPlan := "free"
			if p, err := keys.GetPlan(ctx, s.rdb, doc.UserID); err == nil && p != "" {
				userPlan = p
			} else {
				var u bson.M
				if s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": doc.UserID}).Decode(&u) == nil {
					if p, ok := u["plan"].(string); ok && p != "" {
						userPlan = p
					}
				}
			}
			entries = append(entries, &pb.LeaderboardEntry{
				UserId:   doc.UserID,
				Username: doc.Username,
				Score:    doc.TotalScore,
				Rank:     rank,
				Plan:     userPlan,
			})
			rank++
		}

	default: // alltime — by rating
		cursor, err := s.mongoDB.Collection("users").Find(ctx,
			bson.M{},
			options.Find().SetSort(bson.D{{Key: "rating", Value: -1}}).SetLimit(limit),
		)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "query failed: %v", err)
		}
		defer cursor.Close(ctx)

		rank := int32(1)
		for cursor.Next(ctx) {
			var u bson.M
			if cursor.Decode(&u) != nil {
				continue
			}
			uid, _ := u["_id"].(string)
			uname, _ := u["username"].(string)
			rating := int32(1200)
			if r, ok := u["rating"].(int32); ok {
				rating = r
			}
			userPlan, _ := u["plan"].(string)
			if userPlan == "" {
				userPlan = "free"
			}
			entries = append(entries, &pb.LeaderboardEntry{
				UserId:   uid,
				Username: uname,
				Score:    float64(rating),
				Rank:     rank,
				Plan:     userPlan,
			})
			rank++
		}
	}

	return &pb.GetGlobalLeaderboardResponse{Entries: entries}, nil
}

// ---------------------------------------------------------------------------
// Phase 2: UpdateFCMToken
// ---------------------------------------------------------------------------

func (s *scoringServer) UpdateFCMToken(ctx context.Context, req *pb.UpdateFCMTokenRequest) (*pb.UpdateFCMTokenResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	_, err = s.mongoDB.Collection("users").UpdateOne(ctx,
		bson.M{"_id": userID},
		bson.M{"$addToSet": bson.M{"fcmTokens": req.Token}},
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update failed: %v", err)
	}

	return &pb.UpdateFCMTokenResponse{Success: true}, nil
}

// ---------------------------------------------------------------------------
// Phase 2: GetReferralDashboard (stub — full logic in CP-6)
// ---------------------------------------------------------------------------

func (s *scoringServer) GetReferralDashboard(ctx context.Context, _ *pb.GetReferralDashboardRequest) (*pb.GetReferralDashboardResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	var user models.User
	if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	// Count referrals
	total, _ := s.mongoDB.Collection("referrals").CountDocuments(ctx, bson.M{"referrerId": userID})
	converted, _ := s.mongoDB.Collection("referrals").CountDocuments(ctx, bson.M{"referrerId": userID, "status": "converted"})

	return &pb.GetReferralDashboardResponse{
		ReferralCode: user.ReferralCode,
		TotalInvites: int32(total),
		Conversions:  int32(converted),
		CoinsEarned:  converted * 100, // 100 coins per conversion
	}, nil
}

// ---------------------------------------------------------------------------
// Phase 2: ApplyReferralCode (stub — full logic in CP-6)
// ---------------------------------------------------------------------------

func (s *scoringServer) ApplyReferralCode(ctx context.Context, req *pb.ApplyReferralCodeRequest) (*pb.ApplyReferralCodeResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	// Check user hasn't already been referred
	var user models.User
	if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}
	if user.ReferredBy != "" {
		return nil, status.Error(codes.AlreadyExists, "already referred by someone")
	}

	// Anti-abuse: guest accounts cannot be referred (farmable)
	if user.IsGuest {
		return nil, status.Error(codes.FailedPrecondition, "link an email before applying a referral code")
	}

	// Look up referral code
	referrerID, err := keys.GetRefCode(ctx, s.rdb, req.Code)
	if err != nil || referrerID == "" {
		return nil, status.Error(codes.NotFound, "invalid referral code")
	}

	// Anti-abuse: reject self-referral
	if referrerID == userID {
		return nil, status.Error(codes.InvalidArgument, "cannot refer yourself")
	}

	// Anti-abuse: max 20 converted referrals per referrer
	count, _ := s.mongoDB.Collection("referrals").CountDocuments(ctx,
		bson.M{"referrerId": referrerID, "status": "converted"})
	if count >= 20 {
		return nil, status.Error(codes.ResourceExhausted, "referrer has reached the referral cap")
	}

	// Create referral doc + set referredBy
	s.mongoDB.Collection("referrals").InsertOne(ctx, bson.M{
		"referrerId":    referrerID,
		"refereeId":     userID,
		"referralCode":  req.Code,
		"status":        "pending",
		"rewardGranted": false,
		"createdAt":     time.Now(),
	})
	s.mongoDB.Collection("users").UpdateOne(ctx, bson.M{"_id": userID}, bson.M{"$set": bson.M{"referredBy": referrerID}})

	return &pb.ApplyReferralCodeResponse{Success: true}, nil
}

// ---------------------------------------------------------------------------
// 48. RabbitMQ consumer for answer-processing-queue
// ---------------------------------------------------------------------------

type answerMessage struct {
	RoomID          string `json:"roomId"`
	UserID          string `json:"userId"`
	Round           int    `json:"round"`
	OptionIndex     int    `json:"optionIndex"`
	ClientTimestamp int64  `json:"clientTimestamp"`
	ServerTimestamp int64  `json:"serverTimestamp"`
}

func (s *scoringServer) consumeAnswers(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[scoring] failed to open channel: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("answer-processing-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[scoring] failed to consume answer-processing-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			s.processAnswer(ctx, msg)
		}
	}
}

func (s *scoringServer) processAnswer(ctx context.Context, msg amqp.Delivery) {
	var answer answerMessage
	if err := json.Unmarshal(msg.Body, &answer); err != nil {
		log.Printf("[scoring] bad answer payload: %v", err)
		msg.Nack(false, false) // don't requeue malformed messages
		return
	}

	// Call CalculateScore gRPC to compute the score (spec: must use gRPC, not in-process)
	answerTimeMs := answer.ServerTimestamp - answer.ClientTimestamp
	if answerTimeMs < 0 {
		answerTimeMs = 15000
	} else if answerTimeMs > 15000 {
		answerTimeMs = 15000
	}
	calcResp, err := s.selfClient.CalculateScore(ctx, &pb.CalculateScoreRequest{
		RoomId:       answer.RoomID,
		UserId:       answer.UserID,
		Round:        int32(answer.Round),
		OptionIndex:  int32(answer.OptionIndex),
		AnswerTimeMs: answerTimeMs,
	})
	if err != nil {
		log.Printf("[scoring] CalculateScore gRPC error: %v", err)
		if getDeathCount(msg) >= 3 {
			msg.Nack(false, false)
		} else {
			msg.Nack(false, true)
		}
		return
	}

	correct := calcResp.Correct
	score := calcResp.Score

	// Step 12/48: Atomic idempotency — HSETNX room:{id}:answers:{round} {userId}
	answerJSON, err := json.Marshal(map[string]interface{}{
		"optionIndex":     answer.OptionIndex,
		"correct":         correct,
		"score":           score,
		"timestamp":       answer.ServerTimestamp,
		"clientTimestamp": answer.ClientTimestamp,
	})
	if err != nil {
		log.Printf("[scoring] failed to marshal answer record: %v", err)
		msg.Nack(false, true)
		return
	}
	wasSet, err := keys.TrySetAnswer(ctx, s.rdb, answer.RoomID, answer.Round, answer.UserID, string(answerJSON))
	if err != nil {
		log.Printf("[scoring] TrySetAnswer error: %v", err)
		msg.Nack(false, true)
		return
	}
	if !wasSet {
		log.Printf("[scoring] duplicate answer from %s for room %s round %d — skipping", answer.UserID, answer.RoomID, answer.Round)
		msg.Ack(false)
		return
	}

	// Step 49: Update leaderboard via Lua script (atomic read-modify-write)
	entries, err := keys.UpdateLeaderboard(ctx, s.rdb, answer.RoomID, answer.UserID, score)
	if err != nil {
		log.Printf("[scoring] leaderboard update error: %v", err)
		msg.Nack(false, true)
		return
	}

	log.Printf("[scoring] %s scored %.0f in room %s round %d (correct=%v, speed=%.1fx)",
		answer.UserID, score, answer.RoomID, answer.Round, correct, calcResp.SpeedMultiplier)

	// Publish leaderboard.updated to RabbitMQ for real-time broadcast
	leaderboardEvent, _ := json.Marshal(map[string]interface{}{
		"roomId":  answer.RoomID,
		"entries": entries,
	})
	s.publish(ctx, "leaderboard.updated", leaderboardEvent)

	msg.Ack(false)
}

// getDeathCount extracts the x-death count from message headers for DLQ routing.
func getDeathCount(msg amqp.Delivery) int {
	if msg.Headers == nil {
		return 0
	}
	xDeath, ok := msg.Headers["x-death"]
	if !ok {
		return 0
	}
	deaths, ok := xDeath.([]interface{})
	if !ok || len(deaths) == 0 {
		return 0
	}
	first, ok := deaths[0].(amqp.Table)
	if !ok {
		return 0
	}
	count, ok := first["count"]
	if !ok {
		return 0
	}
	switch v := count.(type) {
	case int64:
		return int(v)
	case int32:
		return int(v)
	default:
		return 0
	}
}

// ---------------------------------------------------------------------------
// 52-54. Persistence Worker — consumes match.finished, writes to MongoDB
// ---------------------------------------------------------------------------

type matchFinishedEvent struct {
	RoomID  string             `json:"roomId"`
	Winner  string             `json:"winner"`
	Rounds  int                `json:"rounds"`
	Players []*pb.PlayerResult `json:"players"`
}

func (s *scoringServer) consumeMatchFinished(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[persistence] failed to open channel: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("match-finished-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[persistence] failed to consume match-finished-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			s.persistMatch(ctx, msg)
		}
	}
}

// resolveRoundsForHistory returns the best available round count for
// persisting a finished match. finishMatch uses eventRounds = -1 when the
// opponent abandons and 0 when all players disconnect; those sentinels
// would corrupt match_history (Phase-1 spec item 4 requires a real value).
// When the sentinel is non-positive, fall back to roundsPlayed which the
// caller reads from the authoritative room:{id}:round key. If both are
// zero (match ended before round 1 dispatch), 0 is the truthful answer.
func resolveRoundsForHistory(eventRounds, roundsPlayed int) int {
	if eventRounds <= 0 {
		return roundsPlayed
	}
	return eventRounds
}

func (s *scoringServer) persistMatch(ctx context.Context, msg amqp.Delivery) {
	var event matchFinishedEvent
	if err := json.Unmarshal(msg.Body, &event); err != nil {
		log.Printf("[persistence] bad match.finished payload: %v", err)
		msg.Nack(false, false)
		return
	}

	log.Printf("[persistence] persisting match %s", event.RoomID)

	// Build match_history document from room:{id}:leaderboard and room metadata
	entries, _ := keys.GetLeaderboardEntries(ctx, s.rdb, event.RoomID)

	// Authoritative participant list — room:{id}:players is populated on room
	// creation, independent of whether the player ever submitted an answer. The
	// leaderboard ZSET only contains players who answered at least once, so an
	// abandoning player who left before round 1 would be missing from history
	// entirely if we built the players array from leaderboard alone.
	allPlayers, _ := keys.GetAllPlayers(ctx, s.rdb, event.RoomID)

	// The caller passes event.Rounds = -1 on opponent-abandon and 0 on
	// zero-connected. Those are status signals, not actual round counts — use
	// room:{id}:round (the current-round counter) as the tally upper bound so
	// answersCorrect stays accurate in abandonment cases.
	roundsPlayed, err := keys.GetRoomRound(ctx, s.rdb, event.RoomID)
	if err != nil {
		roundsPlayed = 0
	}

	// Compute per-player stats from answer records in Redis
	players := make([]bson.M, 0, len(allPlayers))
	playerCorrect := make(map[string]int32)
	playerTotal := make(map[string]int32)
	scored := make(map[string]bool, len(entries))
	var winner string

	// Helper: tally a single player's round-by-round stats from Redis.
	tallyStats := func(userID string) (int, int, float64) {
		var correct int
		var totalResponseMs int64
		var answered int
		for round := 1; round <= roundsPlayed; round++ {
			answerJSON, err := s.rdb.HGet(ctx, keys.Answers(event.RoomID, round), userID).Result()
			if err != nil {
				continue
			}
			var rec struct {
				Correct         bool  `json:"correct"`
				Timestamp       int64 `json:"timestamp"`
				ClientTimestamp int64 `json:"clientTimestamp"`
			}
			if json.Unmarshal([]byte(answerJSON), &rec) == nil {
				answered++
				if rec.Correct {
					correct++
				}
				if rec.Timestamp > 0 && rec.ClientTimestamp > 0 {
					totalResponseMs += rec.Timestamp - rec.ClientTimestamp
				}
			}
		}
		var avg float64
		if answered > 0 {
			avg = float64(totalResponseMs) / float64(answered)
		}
		return correct, answered, avg
	}

	// Helper: resolve username, preferring the username stored in the room
	// players hash (captured at join time) over the users collection.
	resolveUsername := func(userID string) string {
		if raw, ok := allPlayers[userID]; ok {
			var info struct {
				Username string `json:"username"`
			}
			if json.Unmarshal([]byte(raw), &info) == nil && info.Username != "" {
				return info.Username
			}
		}
		var userDoc bson.M
		if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&userDoc); err == nil {
			if u, ok := userDoc["username"].(string); ok && u != "" {
				return u
			}
		}
		return userID
	}

	// First pass: leaderboard entries (already ranked by score desc).
	for i, e := range entries {
		userID := e.Member.(string)
		scored[userID] = true
		if i == 0 {
			winner = userID
		}

		correct, answered, avgMs := tallyStats(userID)
		playerCorrect[userID] = int32(correct)
		playerTotal[userID] = int32(answered)

		players = append(players, bson.M{
			"userId":            userID,
			"username":          resolveUsername(userID),
			"finalScore":        e.Score,
			"rank":              i + 1,
			"answersCorrect":    correct,
			"avgResponseTimeMs": avgMs,
		})
	}

	// Second pass: participants who never scored (abandoned before answering
	// round 1). Append them with zero score at the bottom of the ranking so
	// their match history still surfaces this room.
	nextRank := len(entries) + 1
	for userID := range allPlayers {
		if scored[userID] {
			continue
		}
		correct, answered, avgMs := tallyStats(userID)
		playerCorrect[userID] = int32(correct)
		playerTotal[userID] = int32(answered)

		players = append(players, bson.M{
			"userId":            userID,
			"username":          resolveUsername(userID),
			"finalScore":        0.0,
			"rank":              nextRank,
			"answersCorrect":    correct,
			"avgResponseTimeMs": avgMs,
		})
		nextRank++
	}

	if winner == "" {
		winner = event.Winner
	}

	// Compute duration in milliseconds from room state createdAt
	var durationMs int64
	stateJSON, err := keys.GetRoomState(ctx, s.rdb, event.RoomID)
	if err == nil {
		var state struct {
			CreatedAt int64 `json:"createdAt"`
		}
		if json.Unmarshal([]byte(stateJSON), &state) == nil && state.CreatedAt > 0 {
			durationMs = (time.Now().Unix() - state.CreatedAt) * 1000
		}
	}

	roundsForHistory := resolveRoundsForHistory(event.Rounds, roundsPlayed)

	matchDoc := bson.M{
		"roomId":    event.RoomID,
		"players":   players,
		"rounds":    roundsForHistory,
		"winner":    winner,
		"createdAt": time.Now(),
		"duration":  durationMs,
	}

	// Step 53: Upsert with $setOnInsert to prevent double-writes
	historyRes, err := s.mongoDB.Collection("match_history").UpdateOne(
		ctx,
		bson.M{"roomId": event.RoomID},
		bson.M{"$setOnInsert": matchDoc},
		options.UpdateOne().SetUpsert(true),
	)
	if err != nil {
		log.Printf("[persistence] match_history upsert failed: %v", err)
		msg.Nack(false, true)
		return
	}
	// firstInsert is the canonical "this is a fresh match.finished, not a
	// queue redelivery" signal — UpsertedID is non-nil only on the row's
	// initial insert. Downstream side-effects that aren't naturally
	// idempotent (tournament standings $inc) gate on this flag.
	firstInsert := historyRes.UpsertedID != nil

	// Step 54: Update user stats and Elo ratings
	// Elo formula: K=32, expected = 1/(1+10^((Rb-Ra)/400))
	// Winner gets +K*(1-expected), loser gets -K*expected
	usersColl := s.mongoDB.Collection("users")

	// Look up current ratings for Elo calculation
	ratings := make(map[string]float64)
	for _, e := range entries {
		userID := e.Member.(string)
		var userDoc bson.M
		if err := usersColl.FindOne(ctx, bson.M{"_id": userID}).Decode(&userDoc); err == nil {
			if r, ok := userDoc["rating"].(int32); ok {
				ratings[userID] = float64(r)
			} else {
				ratings[userID] = 1200
			}
		} else {
			ratings[userID] = 1200
		}
	}

	const K = 32.0
	winnerID := ""
	if len(entries) > 0 {
		winnerID = entries[0].Member.(string)
	}

	for _, e := range entries {
		userID := e.Member.(string)
		ra := ratings[userID]
		isWinner := userID == winnerID

		// Compute average expected score against all other players
		var totalExpected float64
		opponents := 0
		for _, other := range entries {
			otherID := other.Member.(string)
			if otherID == userID {
				continue
			}
			rb := ratings[otherID]
			expected := 1.0 / (1.0 + math.Pow(10, (rb-ra)/400.0))
			totalExpected += expected
			opponents++
		}
		if opponents == 0 {
			continue
		}
		avgExpected := totalExpected / float64(opponents)

		var actual float64
		if isWinner {
			actual = 1.0
		}
		delta := int32(math.Round(K * (actual - avgExpected)))

		// Read current win streak to compute new value
		var curUser models.User
		_ = usersColl.FindOne(ctx, bson.M{"_id": userID}).Decode(&curUser)

		inc := bson.M{
			"matchesPlayed":  int32(1),
			"rating":         delta,
			"correctAnswers": playerCorrect[userID],
			"totalAnswers":   playerTotal[userID],
		}
		set := bson.M{}
		if isWinner {
			inc["wins"] = int32(1)
			newWS := curUser.WinStreak + 1
			set["winStreak"] = newWS
			if newWS > curUser.LongestWinStreak {
				set["longestWinStreak"] = newWS
			}
		} else {
			set["winStreak"] = int32(0)
		}
		update := bson.M{"$inc": inc}
		if len(set) > 0 {
			update["$set"] = set
		}
		_, err := usersColl.UpdateOne(ctx, bson.M{"_id": userID}, update, options.UpdateOne().SetUpsert(true))
		if err != nil {
			log.Printf("[persistence] user update failed for %s: %v", userID, err)
		}
	}

	log.Printf("[persistence] match %s persisted — winner: %s, %d players", event.RoomID, winner, len(entries))

	// Phase 3 (4.2): roll the match score into any active tournaments the
	// participants are currently entered in. Points-based ranking — every
	// completed match contributes its raw score to the participant's
	// tournament standing. The quiz service's finalization worker reads
	// from tournament_standings to compute top-N when the window closes.
	//
	// Gated on firstInsert because $inc isn't idempotent — a queue
	// redelivery of match.finished (consumer crash before ack, channel
	// drop mid-flight) would otherwise double the participant's standing
	// score every time. The match_history $setOnInsert is the canonical
	// dedup point, so we lean on its UpsertedID rather than introducing a
	// parallel idempotency mechanism.
	if firstInsert {
		s.updateTournamentStandings(ctx, entries, resolveUsername)
	} else {
		log.Printf("[persistence] match %s redelivery — skipping tournament standings update", event.RoomID)
	}

	// Phase 2: Detect first quiz completion for referred users → trigger referral reward
	for _, e := range entries {
		userID := e.Member.(string)
		var user models.User
		if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
			continue
		}
		if user.ReferredBy == "" {
			continue
		}
		matchCount, _ := s.mongoDB.Collection("match_history").CountDocuments(ctx, bson.M{"players.userId": userID})
		if matchCount == 1 {
			refEvent, _ := json.Marshal(map[string]interface{}{
				"event":       "referral.first_quiz_completed",
				"referrerId":  user.ReferredBy,
				"refereeId":   userID,
				"refereeName": user.Username,
			})
			s.publish(ctx, "referral.first_quiz_completed", refEvent)
			log.Printf("[persistence] published referral.first_quiz_completed for user %s", userID)
		}
	}

	msg.Ack(false)
}

// ---------------------------------------------------------------------------
// Analytics Worker — stub that logs match.finished payloads (section 9.6 note)
// ---------------------------------------------------------------------------

func (s *scoringServer) consumeAnalytics(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[analytics] failed to open channel: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("match-analytics-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[analytics] failed to consume match-analytics-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			log.Printf("[analytics] match.finished event: %s", string(msg.Body))
			msg.Ack(false)
		}
	}
}

// ---------------------------------------------------------------------------
// Phase 2: payment.captured consumer — upgrade user plan (ISSUE-07)
// ---------------------------------------------------------------------------

func (s *scoringServer) consumePaymentCaptured(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[payment-consumer] failed to open channel: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("payment-success-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[payment-consumer] failed to consume payment-success-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}

			var event struct {
				UserID       string `json:"userId"`
				PlanDuration string `json:"planDuration"`
			}
			if err := json.Unmarshal(msg.Body, &event); err != nil {
				log.Printf("[payment-consumer] bad payload: %v", err)
				msg.Nack(false, false)
				continue
			}

			// Calculate plan expiry — extend from current expiry if still active
			var duration time.Duration
			if event.PlanDuration == "yearly" {
				duration = 365 * 24 * time.Hour
			} else {
				duration = 30 * 24 * time.Hour // monthly
			}
			base := time.Now()
			var existingUser bson.M
			if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": event.UserID}).Decode(&existingUser); err == nil {
				if t, ok := existingUser["planExpiresAt"].(time.Time); ok && t.After(base) {
					base = t // don't lose remaining premium days on renewal
				}
			}
			expiresAt := base.Add(duration)

			// Upgrade user plan in MongoDB. Clear premiumExpiryWarned so the
			// payment service's pre-warning worker will fire again against the
			// new (extended) expiry date — otherwise a renewing user would
			// never be reminded about the new expiry.
			_, err := s.mongoDB.Collection("users").UpdateOne(ctx,
				bson.M{"_id": event.UserID},
				bson.M{
					"$set":   bson.M{"plan": "premium", "planExpiresAt": expiresAt},
					"$unset": bson.M{"premiumExpiryWarned": ""},
				},
			)
			if err != nil {
				log.Printf("[payment-consumer] plan upgrade failed for %s: %v", event.UserID, err)
				msg.Nack(false, true)
				continue
			}

			// Invalidate Redis plan cache (ISSUE-07)
			keys.DelPlan(ctx, s.rdb, event.UserID)

			// Publish activation notification
			notifJSON, _ := json.Marshal(map[string]interface{}{
				"event":  "notif.premium.activated",
				"userId": event.UserID,
			})
			s.publish(ctx, "notif.premium.activated", notifJSON)

			log.Printf("[payment-consumer] upgraded user %s to premium (expires %s)", event.UserID, expiresAt.Format("2006-01-02"))
			msg.Ack(false)
		}
	}
}

// ---------------------------------------------------------------------------
// Phase 2: referral.first_quiz_completed consumer (ISSUE-06 full chain)
// ---------------------------------------------------------------------------

func (s *scoringServer) consumeReferralEvents(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[referral-consumer] failed to open channel: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("referral-event-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[referral-consumer] failed to consume referral-event-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			if err := s.handleReferralEvent(ctx, msg.Body); err != nil {
				if errors.Is(err, errBadReferralPayload) {
					log.Printf("[referral-consumer] bad payload, dropping: %v body=%s", err, string(msg.Body))
					msg.Nack(false, false)
					continue
				}
				log.Printf("[referral-consumer] error: %v body=%s", err, string(msg.Body))
				// Transient error — requeue. The queue's x-max-delivery-count
				// dead-letters the message after repeated failures.
				msg.Nack(false, true)
				continue
			}
			msg.Ack(false)
		}
	}
}

// ---------------------------------------------------------------------------
// Phase 3 (4.2): Tournament standings + finished-event consumer
// ---------------------------------------------------------------------------

// updateTournamentStandings rolls each participant's match score into their
// row in the tournament_standings collection for every tournament whose
// scoring window is currently open. Called from persistMatch after Elo /
// user stats have been written so a single match contributes to global
// ranking and tournament ranking in one unit of work.
//
// Window semantics: a tournament counts a match if status="active" AND
// startTime <= now <= endTime AND the user is in participants[]. A tournament
// can be in status="upcoming" and still have endTime in the future — those
// don't count yet. Once the finalization worker flips status="completed",
// further matches don't accumulate.
//
// $inc + upsert is the entire concurrency story: two simultaneous match
// finishes for the same user in the same tournament both add safely.
func (s *scoringServer) updateTournamentStandings(
	ctx context.Context,
	entries []redis.Z,
	resolveUsername func(string) string,
) {
	if len(entries) == 0 {
		return
	}

	userIDs := make([]string, 0, len(entries))
	scoreByUser := make(map[string]int64, len(entries))
	for _, e := range entries {
		uid, ok := e.Member.(string)
		if !ok || uid == "" {
			continue
		}
		userIDs = append(userIDs, uid)
		// Per-match score is float (speed multiplier produces fractional
		// points); tournament aggregate stays int64. Round to nearest so
		// totals don't drift on long-running tournaments.
		scoreByUser[uid] = int64(math.Round(e.Score))
	}
	if len(userIDs) == 0 {
		return
	}

	now := time.Now()
	cursor, err := s.mongoDB.Collection("tournaments").Find(ctx, bson.M{
		"status":       "active",
		"startTime":    bson.M{"$lte": now},
		"endTime":      bson.M{"$gt": now},
		"participants": bson.M{"$in": userIDs},
	})
	if err != nil {
		log.Printf("[tournament-standings] tournament lookup failed: %v", err)
		return
	}
	defer cursor.Close(ctx)

	standings := s.mongoDB.Collection("tournament_standings")
	for cursor.Next(ctx) {
		var t models.Tournament
		if err := cursor.Decode(&t); err != nil {
			log.Printf("[tournament-standings] decode failed: %v", err)
			continue
		}

		// Fan out per participating user. Skip users not in this tournament's
		// roster — the $in filter above is across all returned tournaments,
		// so a single user might match one tournament but not another.
		members := make(map[string]struct{}, len(t.Participants))
		for _, p := range t.Participants {
			members[p] = struct{}{}
		}

		for _, uid := range userIDs {
			if _, in := members[uid]; !in {
				continue
			}
			delta := scoreByUser[uid]
			_, err := standings.UpdateOne(ctx,
				bson.M{"tournamentId": t.ID, "userId": uid},
				bson.M{
					"$inc": bson.M{
						"score":         delta,
						"matchesPlayed": int32(1),
					},
					"$set": bson.M{
						"username":  resolveUsername(uid),
						"updatedAt": now,
					},
					"$setOnInsert": bson.M{
						"tournamentId": t.ID,
						"userId":       uid,
						"createdAt":    now,
					},
				},
				options.UpdateOne().SetUpsert(true),
			)
			if err != nil {
				log.Printf("[tournament-standings] upsert failed for tournament=%s user=%s: %v", t.ID, uid, err)
			}
		}
	}
}

// consumeTournamentFinished handles tournament.finished events (one per
// winner) emitted by the quiz service finalization worker. Awards prize
// coins via $inc and emits a per-user push notification.
//
// The quiz service is responsible for idempotency on the publish side
// (Tournament.WinnersAwarded flag), so this consumer doesn't need its own
// dedup — a duplicate would only reach us if the publish-side guard fails,
// in which case the user has bigger problems than a double-coin grant.
func (s *scoringServer) consumeTournamentFinished(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[tournament-finished] failed to open channel: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("tournament-finished-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[tournament-finished] failed to consume: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}

			var event struct {
				TournamentID   string `json:"tournamentId"`
				TournamentName string `json:"tournamentName"`
				UserID         string `json:"userId"`
				Username       string `json:"username"`
				Rank           int    `json:"rank"`
				CoinsAwarded   int64  `json:"coinsAwarded"`
				FinalScore     int64  `json:"finalScore"`
			}
			if err := json.Unmarshal(msg.Body, &event); err != nil {
				log.Printf("[tournament-finished] bad payload: %v", err)
				msg.Nack(false, false)
				continue
			}

			// Idempotent transition on the tournament_payouts work-list:
			// "pending" or "published" → "paid". A queue redelivery (or a
			// drain-worker republish of the same payout) hits an already-
			// "paid" row, sees ModifiedCount == 0, and ack-skips. Only the
			// thread that wins this UpdateOne actually grants coins.
			//
			// This is the dedup point that lets the producer side
			// re-publish freely on RabbitMQ failure without double-paying.
			now := time.Now()
			res, err := s.mongoDB.Collection("tournament_payouts").UpdateOne(ctx,
				bson.M{
					"tournamentId": event.TournamentID,
					"userId":       event.UserID,
					"status":       bson.M{"$ne": "paid"},
				},
				bson.M{"$set": bson.M{"status": "paid", "paidAt": now}},
			)
			if err != nil {
				log.Printf("[tournament-finished] payout transition failed for user=%s tournament=%s: %v", event.UserID, event.TournamentID, err)
				msg.Nack(false, true)
				continue
			}
			if res.MatchedCount == 0 {
				// No payout row exists for this (tournament, user) at all.
				// Either the producer didn't write one (shouldn't happen
				// under normal flow) or the row was manually pruned. Ack
				// without granting coins so we don't pay out a phantom
				// winner; log loudly so an operator can investigate.
				log.Printf("[tournament-finished] no payout row for user=%s tournament=%s — discarding event", event.UserID, event.TournamentID)
				msg.Ack(false)
				continue
			}
			if res.ModifiedCount == 0 {
				// Row exists but was already in "paid" state — this is the
				// expected redelivery / drain-worker-republish path. Skip.
				msg.Ack(false)
				continue
			}

			if event.CoinsAwarded > 0 {
				_, err := s.mongoDB.Collection("users").UpdateOne(ctx,
					bson.M{"_id": event.UserID},
					bson.M{"$inc": bson.M{"coins": event.CoinsAwarded}},
				)
				if err != nil {
					// We already flipped the payout row to "paid" above —
					// requeuing would only retry the $inc behind a row
					// that the redelivery loop will now skip. Log loud
					// and ack; manual reconciliation needed in this rare
					// path. A real outbox would close this gap (out of
					// scope here).
					log.Printf("[tournament-finished] coin grant failed AFTER payout transition for user=%s tournament=%s: %v — manual reconciliation required", event.UserID, event.TournamentID, err)
					msg.Ack(false)
					continue
				}
			}

			notifJSON, _ := json.Marshal(map[string]interface{}{
				"event":          "notif.tournament.finished",
				"userId":         event.UserID,
				"username":       event.Username,
				"tournamentId":   event.TournamentID,
				"tournamentName": event.TournamentName,
				"rank":           event.Rank,
				"coinsAwarded":   event.CoinsAwarded,
				"finalScore":     event.FinalScore,
			})
			// The publish error doesn't change the ack decision — the coin
			// grant is already committed and requeuing would double-pay.
			// Logging is the floor so prod triage can see push drops;
			// durable retry of the FCM event would need its own outbox
			// (out of scope here).
			if err := s.publish(ctx, "notif.tournament.finished", notifJSON); err != nil {
				log.Printf("[tournament-finished] notif publish failed for user=%s tournament=%s: %v", event.UserID, event.TournamentID, err)
			}

			log.Printf("[tournament-finished] user=%s tournament=%s rank=%d coins=%d", event.UserID, event.TournamentID, event.Rank, event.CoinsAwarded)
			msg.Ack(false)
		}
	}
}

// ---------------------------------------------------------------------------
// RabbitMQ setup
// ---------------------------------------------------------------------------

func setupRabbitMQ(ch *amqp.Channel) error {
	// Ensure sx exchange exists
	if err := ch.ExchangeDeclare("sx", "topic", true, false, false, false, nil); err != nil {
		return fmt.Errorf("exchange declare: %w", err)
	}

	// Bind leaderboard.updated for broadcasting (consumed by quiz service or directly)
	_, err := ch.QueueDeclare("leaderboard-updated-queue", true, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("leaderboard queue declare: %w", err)
	}
	if err := ch.QueueBind("leaderboard-updated-queue", "leaderboard.updated", "sx", false, nil); err != nil {
		return fmt.Errorf("leaderboard queue bind: %w", err)
	}

	// Phase 2: payment-success-queue (consumed by this service to upgrade plans)
	if _, err := ch.QueueDeclare("payment-success-queue", true, false, false, false, nil); err != nil {
		return fmt.Errorf("payment queue declare: %w", err)
	}
	if err := ch.QueueBind("payment-success-queue", "payment.*", "sx", false, nil); err != nil {
		return fmt.Errorf("payment queue bind: %w", err)
	}

	// Phase 2: referral-event-queue (consumed by this service to grant rewards).
	// Mirrors the tournament-finished DLQ pattern: a poison message would
	// otherwise head-of-line-block the queue forever once we requeue on error.
	if _, err := ch.QueueDeclare("referral-event-dlq", true, false, false, false, nil); err != nil {
		return fmt.Errorf("referral DLQ declare: %w", err)
	}
	if _, err := ch.QueueDeclare("referral-event-queue", true, false, false, false, amqp.Table{
		"x-dead-letter-exchange":    "",
		"x-dead-letter-routing-key": "referral-event-dlq",
		"x-max-delivery-count":      3,
	}); err != nil {
		return fmt.Errorf("referral queue declare: %w", err)
	}
	if err := ch.QueueBind("referral-event-queue", "referral.*", "sx", false, nil); err != nil {
		return fmt.Errorf("referral queue bind: %w", err)
	}

	// Phase 2: push-notification-queue (this service publishes notif.* events)
	if _, err := ch.QueueDeclare("push-notification-queue", true, false, false, false, nil); err != nil {
		return fmt.Errorf("push-notification queue declare: %w", err)
	}
	if err := ch.QueueBind("push-notification-queue", "notif.#", "sx", false, nil); err != nil {
		return fmt.Errorf("push-notification queue bind: %w", err)
	}

	// Phase 3 (4.2): tournament-finished-queue. Quiz service publishes
	// tournament.finished once per top-N winner when the finalization
	// worker closes a tournament. We consume to award coins + emit FCM.
	//
	// Mirrors the answer-processing-queue dead-letter pattern: a poison
	// message (e.g. coin grant fails repeatedly because Mongo is down)
	// gets diverted to tournament-finished-dlq after 3 redeliveries
	// instead of head-of-line-blocking the queue forever.
	if _, err := ch.QueueDeclare("tournament-finished-dlq", true, false, false, false, nil); err != nil {
		return fmt.Errorf("tournament-finished DLQ declare: %w", err)
	}
	if _, err := ch.QueueDeclare("tournament-finished-queue", true, false, false, false, amqp.Table{
		"x-dead-letter-exchange":    "",
		"x-dead-letter-routing-key": "tournament-finished-dlq",
		"x-max-delivery-count":      3,
	}); err != nil {
		return fmt.Errorf("tournament-finished queue declare: %w", err)
	}
	if err := ch.QueueBind("tournament-finished-queue", "tournament.finished", "sx", false, nil); err != nil {
		return fmt.Errorf("tournament-finished queue bind: %w", err)
	}

	return nil
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Redis
	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: redisAddr})
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("redis connect failed: %v", err)
	}
	log.Println("[scoring] connected to Redis")

	// RabbitMQ
	rabbitURL := os.Getenv("RABBITMQ_URL")
	if rabbitURL == "" {
		rabbitURL = "amqp://guest:guest@localhost:5672/"
	}
	conn, err := amqp.Dial(rabbitURL)
	if err != nil {
		log.Fatalf("rabbitmq connect failed: %v", err)
	}
	defer conn.Close()

	amqpCh, err := conn.Channel()
	if err != nil {
		log.Fatalf("rabbitmq channel failed: %v", err)
	}
	defer amqpCh.Close()

	if err := setupRabbitMQ(amqpCh); err != nil {
		log.Fatalf("rabbitmq setup failed: %v", err)
	}
	log.Println("[scoring] connected to RabbitMQ")

	// MongoDB
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017/quizbattle"
	}
	mongoClient, err := mongo.Connect(options.Client().ApplyURI(mongoURI).SetBSONOptions(&options.BSONOptions{
		ObjectIDAsHexString: true,
	}))
	if err != nil {
		log.Fatalf("mongodb connect failed: %v", err)
	}
	defer mongoClient.Disconnect(ctx)
	log.Println("[scoring] connected to MongoDB")

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "quiz-battle-dev-secret"
	}

	srv := &scoringServer{
		rdb:       rdb,
		amqpConn:  conn,
		amqpCh:    amqpCh,
		mongoDB:   mongoClient.Database(coins.DefaultDBName),
		ledger:    coins.NewLedger(mongoClient, coins.DefaultDBName),
		jwtSecret: jwtSecret,
	}

	// gRPC server — CalculateScore is called internally by the scoring worker
	// via loopback, so it must bypass JWT auth
	skipMethods := []string{
		"/quiz.ScoringService/CalculateScore",
	}
	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(auth.UnaryInterceptor(jwtSecret, skipMethods)),
		grpc.StreamInterceptor(auth.StreamInterceptor(jwtSecret, skipMethods)),
	)
	pb.RegisterScoringServiceServer(grpcServer, srv)

	lis, err := net.Listen("tcp", ":50053")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	// Start gRPC server in background, then set up self-client for CalculateScore
	go func() {
		log.Println("[scoring] serving on :50053")
		if err := grpcServer.Serve(lis); err != nil {
			log.Fatalf("failed to serve: %v", err)
		}
	}()

	// Create gRPC loopback client so the scoring worker calls CalculateScore via gRPC
	selfConn, err := grpc.NewClient("localhost:50053",
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		log.Fatalf("failed to create self-client: %v", err)
	}
	defer selfConn.Close()
	srv.selfClient = pb.NewScoringServiceClient(selfConn)

	// Start RabbitMQ consumers (3 goroutines)
	go srv.consumeAnswers(ctx)            // 9.5: answer scoring
	go srv.consumeMatchFinished(ctx)      // 9.6: persistence worker
	go srv.consumeAnalytics(ctx)          // 9.6 note: analytics stub
	go srv.consumePaymentCaptured(ctx)    // Phase 2: plan upgrade on payment
	go srv.consumeReferralEvents(ctx)     // Phase 2: referral reward chain (ISSUE-06)
	go srv.consumeTournamentFinished(ctx) // Phase 3 (4.2): tournament prize coin awards

	// Block forever (gRPC server runs in background goroutine)
	select {}
}
