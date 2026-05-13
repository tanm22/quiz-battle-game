package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"net"
	"sort"
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
	"quiz-battle/pkg/coins/shop"
	"quiz-battle/pkg/config"
	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/lifecycle"
	"quiz-battle/pkg/log"
	"quiz-battle/pkg/metrics"
	"quiz-battle/pkg/models"
	"quiz-battle/pkg/ratelimit"
	"quiz-battle/pkg/tlsutil"
	"quiz-battle/pkg/validate"
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
	rdb         *redis.Client
	amqpConn    *amqp.Connection
	amqpCh      *amqp.Channel // for publishing only
	amqpMu      sync.Mutex    // AMQP channels are not thread-safe
	mongoClient *mongo.Client // bound for shop.Purchase's session lifecycle
	mongoDB     *mongo.Database
	ledger      *coins.Ledger  // §4.3 — every balance change goes through Grant
	purchase    *shop.Purchase // §4.3 PR 4 — shop spend orchestrator
	jwtSecret   string
	// publishHook, when non-nil, captures every publish call instead of
	// sending to amqpCh. Set in tests so we can assert routing keys and
	// payloads without standing up RabbitMQ. Nil in production.
	publishHook func(routingKey string, body []byte)
	selfClient  pb.ScoringServiceClient // gRPC loopback client for CalculateScore
	metrics     *metrics.Metrics        // nil in tests; non-nil in main()
	// §4.7 PR-B1: anti-abuse limiter on ApplyReferralCode. 3 attempts
	// per 10 minutes per userID — apply is a one-time-ish action and
	// a tighter limiter would block legitimate retries on transient
	// errors. Nil-safe via the limiter's nil check.
	referralLimiter *ratelimit.Limiter
	// §4.7: anti-abuse limiter on PurchaseShopItem. Idempotency keys
	// already debounce same-key spam, but a fresh-key purchase loop
	// is unbounded without this guard. Nil-safe at the pkg/ratelimit
	// level — shopTestEnv-built servers leave this as the zero value
	// and the limiter passes through unchanged.
	purchaseLimiter *ratelimit.Limiter
	// §4.7 PR-A1: UpdateFCMToken spam gate. Legitimate clients update
	// only on app install, OS-level reinstall, or after FCM rotates a
	// token (rare). 10/hour/user is generous for those plus an
	// occasional dev-tools push, and tight enough that a misbehaving
	// client can't bloat the user's fcmTokens array with garbage.
	fcmTokenLimiter *ratelimit.Limiter
}

// purchaseRateLimit caps shop-purchase calls per user per minute. Set
// liberally — a legitimate user spamming a single SKU is debounced by
// idempotency keys, but a fresh-key purchase loop is unbounded without
// this guard. 30/min is generous for any normal user; an attacker hits
// the wall fast.
const purchaseRateLimit = 30

// publish sends a message to the topic exchange with mutex protection.
// In tests, two seams short-circuit the broker hop:
//   - publishHook captures (routingKey, body) so tests can assert what
//     was published; preferred when the test cares about the wire shape.
//   - nil amqpCh is a silent no-op so tests that only exercise Mongo
//     state (where the publish is incidental) don't need any setup.
func (s *scoringServer) publish(ctx context.Context, routingKey string, body []byte) error {
	s.amqpMu.Lock()
	defer s.amqpMu.Unlock()
	if s.publishHook != nil {
		s.publishHook(routingKey, body)
		return nil
	}
	if s.amqpCh == nil {
		return nil
	}
	err := log.PublishWithContext(ctx, s.amqpCh, "sx", routingKey, false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        body,
	})
	if s.metrics != nil {
		s.metrics.RecordPublish(routingKey, err)
	}
	return err
}

// recordConsume increments amqp_consumes_total{queue, status} on the
// service's per-process metrics registry. Nil-safe so test scoringServer
// instances (which don't construct metrics) can call this freely.
func (s *scoringServer) recordConsume(queue, status string) {
	if s.metrics != nil {
		s.metrics.RecordConsume(queue, status)
	}
}

// recordDispatched increments amqp_dispatched_total{queue}. Use this
// for consumers whose per-message handler does its own ack/nack
// internally (processAnswer, persistMatch) and the consume loop only
// observes "a message was handed off."
func (s *scoringServer) recordDispatched(queue string) {
	if s.metrics != nil {
		s.metrics.RecordDispatched(queue)
	}
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

	_, speedMultiplier, score := computeRoundScore(correct, req.AnswerTimeMs)

	return &pb.CalculateScoreResponse{
		Score:           score,
		Correct:         correct,
		SpeedMultiplier: speedMultiplier,
	}, nil
}

// computeRoundScore is the pure scoring math used by CalculateScore.
// Extracted so the formula is unit-testable without a Mongo round-trip
// for the isCorrect lookup. Implements the §47 spec verbatim:
//
//	basePoints      = 100 if correct, 0 otherwise
//	speedMultiplier = 1.5  when answerTimeMs <  5000
//	                  1.0  when 5000 <= answerTimeMs <= 13000
//	                  0.8  when answerTimeMs > 13000
//	score           = basePoints * speedMultiplier
//
// Boundaries are strict: exactly 5000ms is medium (not fast), exactly
// 13000ms is medium (not slow). A wrong answer scores 0 regardless of
// speed (the multiplier is still reported back for telemetry).
//
// Recency bonuses (streak + first-correct) are NOT computed here —
// they require room+round+user state that lives in Redis and would
// make this gRPC handler non-idempotent under retries. They are
// applied in processAnswer after TrySetAnswer confirms the answer
// is being recorded for the first time. See computeRecencyBonus.
func computeRoundScore(correct bool, answerTimeMs int64) (basePoints, speedMultiplier, score float64) {
	if correct {
		basePoints = 100
	}
	speedMultiplier = 1.0
	if answerTimeMs < 5000 {
		speedMultiplier = 1.5
	} else if answerTimeMs > 13000 {
		speedMultiplier = 0.8
	}
	score = basePoints * speedMultiplier
	return
}

// Recency bonus tuning. Kept as package-level constants so the values
// are visible in tests and easy to tune without re-reading the math.
const (
	// streakBonusUnit is the points added per stacked correct answer
	// beyond the first. Streak level 1 (first correct in a row) earns
	// nothing; level 2 earns one unit; level 3 earns two; etc.
	streakBonusUnit = 10
	// streakBonusCap caps the multiplier so a long match can't make
	// the streak bonus dwarf the base score — at the cap a single
	// correct answer is worth speedMultiplier*100 + streakCap*unit
	// (so 150 + 50 = 200 on a fast correct in a hot streak).
	streakBonusCap = 5
)

// firstCorrectBonusByRank maps a correct answer's arrival rank within
// the round to its first-correct bonus. Index 0 = rank 1 (first
// correct), index 1 = rank 2 (second correct), etc. Anything past the
// slice length earns 0 — the bonus is a small nudge for being early,
// not a runaway lead.
var firstCorrectBonusByRank = []float64{25, 10}

// computeRecencyBonus maps the post-bump streak level and the correct-
// answer rank within the round to a points bonus added on top of the
// base (speed × correct) score. Streak level / rank are produced by
// BumpStreak / IncrCorrectOrder in pkg/keys.
//
//	streakLevel = 1  → streakBonus = 0   (first correct establishes the streak)
//	streakLevel = 2  → streakBonus = 10
//	streakLevel = 3  → streakBonus = 20
//	...
//	streakLevel ≥ 6  → streakBonus = 50  (capped at streakBonusCap*streakBonusUnit)
//
//	correctRank = 1  → firstCorrectBonus = 25
//	correctRank = 2  → firstCorrectBonus = 10
//	correctRank ≥ 3  → firstCorrectBonus = 0
//
// Called only after the answer has been confirmed correct AND
// idempotently recorded — a wrong answer or a duplicate submission
// produces no bonus and (for wrong) resets the streak via
// ResetStreak so the next correct answer starts at level 1.
func computeRecencyBonus(streakLevel, correctRank int64) (streakBonus, firstCorrectBonus, total float64) {
	if streakLevel > 1 {
		stack := streakLevel - 1
		if stack > streakBonusCap {
			stack = streakBonusCap
		}
		streakBonus = float64(stack) * streakBonusUnit
	}
	if correctRank >= 1 && int(correctRank) <= len(firstCorrectBonusByRank) {
		firstCorrectBonus = firstCorrectBonusByRank[correctRank-1]
	}
	total = streakBonus + firstCorrectBonus
	return
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
	// Defense in depth: the unary interceptor already rejects
	// unauthenticated calls, but a refactor that accidentally moves
	// GetLeaderboard onto the interceptor's skip list would silently
	// expose live match leaderboards. Calling UserIDFromContext here
	// makes the auth requirement visible at the call site and ensures
	// the security contract is local to this handler.
	if _, err := auth.UserIDFromContext(ctx); err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	// §4.7 PR-A1: bound the room-id string so a malicious client can't
	// pad it to a giant Redis key and blow the per-keylength memory
	// budget on the server.
	if err := validate.MaxLen(req.RoomId, 128); err != nil {
		return nil, status.Error(codes.InvalidArgument, "room_id: too long")
	}
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
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
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

	// §4.7 PR-A1: reject unknown TimeFilter values at the edge rather
	// than silently aliasing to a default the user didn't ask for.
	// Empty string is valid (treated as alltime below).
	if err := validate.TimeFilter(req.TimeFilter); err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "time_filter: %v", err)
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

	// §4.7 PR-A1: bound the token size + reject empty. Real FCM tokens
	// are ~163 ASCII chars; 512 is generous. Without this, a malicious
	// client could $addToSet a 1MB blob into the user document.
	if req.Token == "" {
		return nil, status.Error(codes.InvalidArgument, "token: required")
	}
	if err := validate.MaxLen(req.Token, 512); err != nil {
		return nil, status.Error(codes.InvalidArgument, "token: too long")
	}

	// §4.7 PR-A1: token-churn rate limit. Real clients update once per
	// install; 10/h is generous for dev reinstalls and an accidental
	// retry loop without letting a misbehaving client bloat fcmTokens.
	if !s.fcmTokenLimiter.AllowWithLog(ctx, userID) {
		return nil, status.Error(codes.ResourceExhausted, "too many token updates; please wait")
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

	// §4.7 PR-A1: validate the code format before it reaches the Redis
	// lookup. Stops "${jndi:...}"-style payloads and bounds the input
	// size at the same time. Matches the issuance format scoring's
	// mint logic produces.
	if err := validate.ReferralCode(req.Code); err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "code: %v", err)
	}

	// §4.7 PR-B1: anti-abuse gate. Stops a script from probing every
	// possible referral code looking for a hit. The "already referred"
	// check below is a one-shot gate per user, but the lookup itself
	// (keys.GetRefCode) is unguarded — without this limiter, a brand
	// new account could enumerate the keyspace at full Redis speed.
	if !s.referralLimiter.AllowWithLog(ctx, userID) {
		return nil, status.Error(codes.ResourceExhausted, "too many referral attempts; try again later")
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
		log.Fatal(ctx, "open channel failed", "consumer", "scoring", "err", err)
	}
	defer ch.Close()

	// prefetch=16 — bounds in-flight scoring work so a Mongo blip can't
	// silently grow the unacked set into a memory leak. Same ceiling as
	// the earn consumer; both have Mongo as the tail-latency dep.
	if err := ch.Qos(16, 0, false); err != nil {
		log.Fatal(ctx, "qos failed", "consumer", "scoring", "err", err)
	}

	msgs, err := ch.Consume("answer-processing-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatal(ctx, "consume failed", "consumer", "scoring", "queue", "answer-processing-queue", "err", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			s.processAnswer(log.ContextFromDelivery(ctx, msg), msg)
			s.recordDispatched("answer-processing-queue")
		}
	}
}

func (s *scoringServer) processAnswer(ctx context.Context, msg amqp.Delivery) {
	// Recover so an unexpected panic — nil-map deref, type-assertion
	// failure inside Redis/Mongo response decoding, etc. — logs cleanly
	// instead of killing the consumer goroutine and silently halting
	// answer scoring for every room. The msg is left unacked on panic;
	// RabbitMQ redelivers it, and the `x-death` count gates the DLQ
	// after a few retries — so a poison message can't loop forever.
	defer log.RecoverPanic(ctx, "processAnswer")

	var answer answerMessage
	if err := json.Unmarshal(msg.Body, &answer); err != nil {
		log.FromContext(ctx).Warn("bad answer payload", "consumer", "scoring", "err", err)
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
		log.FromContext(ctx).Error("CalculateScore gRPC failed",
			"consumer", "scoring",
			"user_id", answer.UserID,
			"room_id", answer.RoomID,
			"round", answer.Round,
			"err", err)
		if getDeathCount(msg) >= 3 {
			msg.Nack(false, false)
		} else {
			msg.Nack(false, true)
		}
		return
	}

	correct := calcResp.Correct
	baseScore := calcResp.Score
	score := baseScore

	// Step 12/48: Atomic idempotency — HSETNX room:{id}:answers:{round} {userId}.
	// The HSETNX is the canonical "first delivery wins" gate — recency
	// bonus side-effects (BumpStreak, IncrCorrectOrder) only run if this
	// goroutine wins it, so a duplicate replay of the same RabbitMQ
	// message can't double-INCR the streak / first-correct counters.
	// The placeholder record stores the base score; we OVERWRITE it
	// below with the bonus-inclusive value so the per-answer record and
	// the leaderboard ZSET never disagree on what the player scored
	// (a future per-question breakdown UI relies on this).
	placeholderJSON, err := json.Marshal(map[string]interface{}{
		"optionIndex":     answer.OptionIndex,
		"correct":         correct,
		"score":           baseScore,
		"timestamp":       answer.ServerTimestamp,
		"clientTimestamp": answer.ClientTimestamp,
	})
	if err != nil {
		log.FromContext(ctx).Error("marshal answer record failed",
			"consumer", "scoring",
			"user_id", answer.UserID,
			"room_id", answer.RoomID,
			"round", answer.Round,
			"err", err)
		msg.Nack(false, true)
		return
	}
	wasSet, err := keys.TrySetAnswer(ctx, s.rdb, answer.RoomID, answer.Round, answer.UserID, string(placeholderJSON))
	if err != nil {
		log.FromContext(ctx).Error("TrySetAnswer failed",
			"consumer", "scoring",
			"user_id", answer.UserID,
			"room_id", answer.RoomID,
			"round", answer.Round,
			"err", err)
		msg.Nack(false, true)
		return
	}
	if !wasSet {
		log.FromContext(ctx).Info("duplicate answer skipped", "consumer", "scoring", "user_id", answer.UserID, "room_id", answer.RoomID, "round", answer.Round)
		msg.Ack(false)
		return
	}

	// Recency bonuses are applied AFTER TrySetAnswer commits the first
	// submission, so a duplicate replay of the same RabbitMQ message can't
	// re-INCR the streak / first-correct counters and inflate the score.
	//
	// - Correct: bump per-user streak (level 1 on first correct in a row,
	//   higher when stacking) AND atomically claim a rank for being the
	//   N'th correct answer in this round.
	// - Wrong: reset the streak so the next correct answer starts fresh
	//   at level 1. No first-correct counter increment.
	//
	// Counter failures are logged but non-fatal — the base score still
	// applies, the answer record is durable, and at worst the player
	// misses one round of bonus.
	var streakBonus, firstCorrectBonus float64
	if correct {
		streakLevel, sErr := keys.BumpStreak(ctx, s.rdb, answer.RoomID, answer.UserID)
		if sErr != nil {
			log.FromContext(ctx).Warn("BumpStreak failed; skipping streak bonus",
				"consumer", "scoring", "user_id", answer.UserID, "room_id", answer.RoomID, "err", sErr)
			streakLevel = 1
		}
		correctRank, oErr := keys.IncrCorrectOrder(ctx, s.rdb, answer.RoomID, answer.Round)
		if oErr != nil {
			log.FromContext(ctx).Warn("IncrCorrectOrder failed; skipping first-correct bonus",
				"consumer", "scoring", "user_id", answer.UserID, "room_id", answer.RoomID, "round", answer.Round, "err", oErr)
			correctRank = 0
		}
		var bonus float64
		streakBonus, firstCorrectBonus, bonus = computeRecencyBonus(streakLevel, correctRank)
		score += bonus
	} else {
		if rErr := keys.ResetStreak(ctx, s.rdb, answer.RoomID, answer.UserID); rErr != nil {
			log.FromContext(ctx).Warn("ResetStreak failed; streak may carry over a wrong answer",
				"consumer", "scoring", "user_id", answer.UserID, "room_id", answer.RoomID, "err", rErr)
		}
	}

	// Overwrite the per-answer record with the bonus-inclusive score and
	// the bonus breakdown. Reads of room:{id}:answers:{round} (used by
	// finishMatch's tallyCorrect/tallyAvgMs and the persistence
	// consumer's tallyStats) only look at `correct` and the two
	// timestamps — the `score` field is for downstream tooling that
	// wants the same number the leaderboard ZSET carries. HSET (not
	// HSETNX) on an already-claimed field is safe; only the goroutine
	// that won TrySetAnswer reaches this line.
	finalJSON, mErr := json.Marshal(map[string]interface{}{
		"optionIndex":       answer.OptionIndex,
		"correct":           correct,
		"score":             score,
		"baseScore":         baseScore,
		"streakBonus":       streakBonus,
		"firstCorrectBonus": firstCorrectBonus,
		"timestamp":         answer.ServerTimestamp,
		"clientTimestamp":   answer.ClientTimestamp,
	})
	if mErr != nil {
		log.FromContext(ctx).Warn("marshal final answer record failed; keeping placeholder",
			"consumer", "scoring", "user_id", answer.UserID, "room_id", answer.RoomID,
			"round", answer.Round, "err", mErr)
	} else if hErr := s.rdb.HSet(ctx, keys.Answers(answer.RoomID, answer.Round),
		answer.UserID, string(finalJSON)).Err(); hErr != nil {
		log.FromContext(ctx).Warn("HSet final answer record failed; keeping placeholder",
			"consumer", "scoring", "user_id", answer.UserID, "room_id", answer.RoomID,
			"round", answer.Round, "err", hErr)
	}

	// Step 49: Update leaderboard via Lua script (atomic read-modify-write)
	entries, err := keys.UpdateLeaderboard(ctx, s.rdb, answer.RoomID, answer.UserID, score)
	if err != nil {
		log.FromContext(ctx).Error("leaderboard update failed",
			"consumer", "scoring",
			"user_id", answer.UserID,
			"room_id", answer.RoomID,
			"round", answer.Round,
			"err", err)
		msg.Nack(false, true)
		return
	}

	log.FromContext(ctx).Info("answer scored",
		"consumer", "scoring",
		"user_id", answer.UserID,
		"score", score,
		"room_id", answer.RoomID,
		"round", answer.Round,
		"correct", correct,
		"speed_multiplier", calcResp.SpeedMultiplier,
		"streak_bonus", streakBonus,
		"first_correct_bonus", firstCorrectBonus)

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
		log.Fatal(ctx, "open channel failed", "consumer", "persistence", "err", err)
	}
	defer ch.Close()

	if err := ch.Qos(16, 0, false); err != nil {
		log.Fatal(ctx, "qos failed", "consumer", "persistence", "err", err)
	}

	msgs, err := ch.Consume("match-finished-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatal(ctx, "consume failed", "consumer", "persistence", "queue", "match-finished-queue", "err", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			s.persistMatch(log.ContextFromDelivery(ctx, msg), msg)
			// persistMatch handles the ack/nack itself; record this
			// as a dispatch event. Operators can compute the gap
			// between amqp_dispatched_total and amqp_consumes_total
			// per queue to spot handlers that don't disposition.
			s.recordDispatched("match-finished-queue")
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

// Elo tuning. Kept as named consts so persistMatch and any future
// rating-related code path read from one source of truth.
const (
	eloK             = 32.0 // chess-club default; bigger swings on each game
	eloDefaultRating = 1200 // starting rating for a freshly-seen user
)

// computeEloDelta returns the rating delta and the win flag for a
// single participant in a finished match. winnerID == "" means the
// match had no winner (both sides scored zero) — every participant
// gets actual=0.5, the standard draw treatment, so the sum of deltas
// stays at zero and rating isn't quietly drained from the pool.
//
// `applied` is false only for a solo room (one participant, no
// opponents). The caller still bumps matchesPlayed in that case but
// skips the rating math (delta would be 0 anyway).
//
// Pure function — no Redis, no Mongo. The persistMatch consumer is
// hard to unit-test as a whole; isolating the Elo math here is the
// cheapest way to pin the rating contract.
func computeEloDelta(userID string, participants []string, ratings map[string]float64, winnerID string, k float64) (delta int32, isWinner bool, applied bool) {
	ra := ratings[userID]
	isWinner = userID == winnerID

	var totalExpected float64
	opponents := 0
	for _, otherID := range participants {
		if otherID == userID {
			continue
		}
		rb := ratings[otherID]
		expected := 1.0 / (1.0 + math.Pow(10, (rb-ra)/400.0))
		totalExpected += expected
		opponents++
	}
	if opponents == 0 {
		return 0, isWinner, false
	}
	avgExpected := totalExpected / float64(opponents)

	var actual float64
	switch {
	case winnerID == "":
		actual = 0.5 // draw — both sides scored zero, treat as a tie
	case isWinner:
		actual = 1.0
	default:
		actual = 0.0
	}
	return int32(math.Round(k * (actual - avgExpected))), isWinner, true
}

func (s *scoringServer) persistMatch(ctx context.Context, msg amqp.Delivery) {
	// Recover so a panic during Mongo decode / FindOneAndUpdate path
	// can't take down the persistence consumer goroutine. msg stays
	// unacked on panic, so RabbitMQ will redeliver; the DLQ pattern via
	// x-death count keeps a poisoned message from looping forever.
	defer log.RecoverPanic(ctx, "persistMatch")

	var event matchFinishedEvent
	if err := json.Unmarshal(msg.Body, &event); err != nil {
		log.FromContext(ctx).Warn("bad payload", "consumer", "persistence", "event", "match.finished", "body", string(msg.Body), "err", err)
		msg.Nack(false, false)
		return
	}

	log.FromContext(ctx).Info("persisting match", "consumer", "persistence", "room_id", event.RoomID)

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

	// §4.5: build round → topic map up front so the per-answer logging
	// loop below doesn't query Mongo per round per player. The Redis
	// questions list orders questionIDs by round (round N = index N-1);
	// we batch-fetch all matching question docs once per match.
	topicByRound := s.loadTopicsForMatch(ctx, event.RoomID, roundsPlayed)

	// Compute per-player stats from answer records in Redis
	players := make([]bson.M, 0, len(allPlayers))
	playerCorrect := make(map[string]int32)
	playerTotal := make(map[string]int32)
	scored := make(map[string]bool, len(entries))
	var winner string

	// Helper: tally a single player's round-by-round stats from Redis.
	// §4.5: per-answer log rows accumulated by tallyStats and bulk-inserted
	// once at the end. Per-row inserts would issue N answers × M players
	// network round trips; batching keeps persistMatch's wall-clock cost
	// flat as match length grows.
	var answerLogDocs []any
	now := time.Now()

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
				// Response time clamp mirrors processAnswer's contract: a
				// missing-clientTimestamp answer or one whose clocks went
				// backwards reads as 15 000 ms (the round budget). Better
				// than 0 ms, which would pollute the percentile bucket
				// and make the user look superhumanly fast.
				responseMs := int64(15000)
				if rec.Timestamp > 0 && rec.ClientTimestamp > 0 {
					rt := rec.Timestamp - rec.ClientTimestamp
					if rt < 0 {
						rt = 15000
					} else if rt > 15000 {
						rt = 15000
					}
					responseMs = rt
				}
				totalResponseMs += responseMs
				// §4.5: log this answer for analytics aggregation. Topic
				// resolves to "" when the question doc was deleted between
				// match start and this point — extremely unlikely (Redis
				// holds the questionIDs list for the room TTL) but if it
				// does, an empty topic falls under "(unknown)" in the
				// per-topic accuracy chart rather than corrupting another
				// topic's bucket.
				answerLogDocs = append(answerLogDocs, bson.M{
					"userId":         userID,
					"matchId":        event.RoomID,
					"round":          int32(round),
					"topic":          topicByRound[round],
					"correct":        rec.Correct,
					"responseTimeMs": responseMs,
					"createdAt":      now,
				})
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
		log.FromContext(ctx).Error("match_history upsert failed", "consumer", "persistence", "err", err)
		msg.Nack(false, true)
		return
	}
	// firstInsert is the canonical "this is a fresh match.finished, not a
	// queue redelivery" signal — UpsertedID is non-nil only on the row's
	// initial insert. Downstream side-effects that aren't naturally
	// idempotent (tournament standings $inc) gate on this flag.
	firstInsert := historyRes.UpsertedID != nil

	// Step 54: Update user stats and Elo ratings.
	//
	// Iterate EVERY participant, not just the scored ones. The earlier
	// version only walked the leaderboard ZSET (`entries`), so a
	// participant who finished with score=0 (timed out every round, or
	// disconnected without answering) had their matchesPlayed counter
	// silently skipped and their rating left untouched. That made
	// `users.matchesPlayed` drift out of sync with `match_history` and
	// gave abandoners a free pass on rating loss. After this change
	// every participant gets exactly one matchesPlayed bump per
	// finished match and an Elo update that reflects the match outcome.
	//
	// No-winner (both sides scored 0) is handled as a draw inside
	// computeEloDelta — actual=0.5 keeps rating conservation intact
	// (sum of deltas = 0 instead of every player losing K/2).
	//
	// Gated on `firstInsert` because the `$inc` on matchesPlayed / rating
	// / wins / correctAnswers / totalAnswers is NOT idempotent. A
	// RabbitMQ redelivery of match.finished (consumer crash before Ack,
	// channel drop mid-flight, broker requeue, or the finishMatch
	// concurrent-defer race the SETNX guard in services/quiz/main.go
	// closes) would otherwise double every per-user counter and corrupt
	// `users.rating` on the second pass. match_history's $setOnInsert
	// is the canonical "fresh delivery vs redelivery" signal — the same
	// gate already protects rating_history, answer_log, and the
	// tournament-standings $inc further below.
	usersColl := s.mongoDB.Collection("users")

	// Stable participant order so a Mongo redelivery applies updates
	// in the same sequence — keeps debug logs comparable across runs.
	participants := make([]string, 0, len(allPlayers))
	for uid := range allPlayers {
		participants = append(participants, uid)
	}
	sort.Strings(participants)

	// Pre-load current ratings for every participant.
	ratings := make(map[string]float64, len(participants))
	for _, userID := range participants {
		var userDoc bson.M
		if err := usersColl.FindOne(ctx, bson.M{"_id": userID}).Decode(&userDoc); err == nil {
			if r, ok := userDoc["rating"].(int32); ok {
				ratings[userID] = float64(r)
			} else {
				ratings[userID] = eloDefaultRating
			}
		} else {
			ratings[userID] = eloDefaultRating
		}
	}

	winnerID := ""
	if len(entries) > 0 {
		winnerID = entries[0].Member.(string)
	}

	if firstInsert {
		for _, userID := range participants {
			// applied is false for a solo room (opponents == 0). delta is
			// already 0 in that case, so the matchesPlayed increment below
			// still fires while rating math is a no-op.
			delta, isWinner, _ := computeEloDelta(userID, participants, ratings, winnerID, eloK)

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
			// §4.5: read the post-update rating back from the upsert so the
			// snapshot is always consistent with users.rating — the prior
			// `int32(ra) + delta` math broke on a brand-new upsert path
			// where `$inc rating: delta` creates the doc with `rating=delta`,
			// not `1200+delta`. Using FindOneAndUpdate(returnDocument=After)
			// makes Mongo the single source of truth for the snapshot value.
			var post struct {
				Rating int32 `bson:"rating"`
			}
			err := usersColl.FindOneAndUpdate(ctx,
				bson.M{"_id": userID},
				update,
				options.FindOneAndUpdate().
					SetUpsert(true).
					SetReturnDocument(options.After).
					SetProjection(bson.M{"rating": 1}),
			).Decode(&post)
			if err != nil {
				log.FromContext(ctx).Error("user update failed", "consumer", "persistence", "user_id", userID, "err", err)
				continue
			}

			// §4.5: snapshot the post-Elo rating for the rating-graph series.
			// One row per (user × match) — the surrounding firstInsert
			// gate prevents a RabbitMQ redelivery from writing duplicates
			// for the same match. Without this gate any future query that
			// doesn't bucket-by-day (analytics export, ML feature pull,
			// ad-hoc admin lookup) would see two rows per match for
			// redelivered events.
			if _, err := s.mongoDB.Collection("rating_history").InsertOne(ctx, bson.M{
				"userId":      userID,
				"matchId":     event.RoomID,
				"rating":      post.Rating,
				"ratingDelta": delta,
				"createdAt":   now,
			}); err != nil {
				log.FromContext(ctx).Error("rating_history insert failed", "consumer", "persistence", "user_id", userID, "err", err)
			}
		}
	} else {
		log.FromContext(ctx).Info("match redelivery skipped user-stats $inc",
			"consumer", "persistence", "room_id", event.RoomID)
	}

	// §4.5: bulk-insert the answer_log rows accumulated during tallyStats,
	// gated on `firstInsert` for the same reason as rating_history above
	// — without it a redelivered match.finished doubles every per-answer
	// row, inflating sample_count and the favorite-topic count even
	// though the per-topic accuracy ratio happens to stay stable.
	// match_history's $setOnInsert is the canonical "fresh delivery vs
	// redelivery" signal already used by the tournament-standings $inc
	// further below.
	if firstInsert && len(answerLogDocs) > 0 {
		if _, err := s.mongoDB.Collection("answer_log").InsertMany(ctx, answerLogDocs); err != nil {
			log.FromContext(ctx).Error("answer_log insert failed", "consumer", "persistence", "room_id", event.RoomID, "err", err)
		}
	}

	log.FromContext(ctx).Info("match persisted", "consumer", "persistence", "room_id", event.RoomID, "winner", winner, "players", len(entries))

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
		log.FromContext(ctx).Info("match redelivery skipped tournament update", "consumer", "persistence", "room_id", event.RoomID)
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
			log.FromContext(ctx).Info("published referral.first_quiz_completed", "consumer", "persistence", "user_id", userID)
		}
	}

	msg.Ack(false)
}

// ---------------------------------------------------------------------------
// §4.5 Deeper analytics — helpers
// ---------------------------------------------------------------------------

// loadTopicsForMatch returns a round (1-based) → topic map for the given
// room. The Redis questions list orders questionIDs by round; we
// batch-fetch the matching question docs from Mongo so the per-answer
// logging loop in persistMatch can label every answer's topic without
// per-round Mongo round trips.
//
// A best-effort helper — failures (Redis empty, Mongo unreachable) yield
// an empty map, and the caller falls back to "" for missing topics. The
// analytics RPCs treat empty topic as "(unknown)" so a degraded path
// here doesn't poison another topic's accuracy bucket.
func (s *scoringServer) loadTopicsForMatch(ctx context.Context, roomID string, roundsPlayed int) map[int]string {
	out := make(map[int]string, roundsPlayed)
	if roundsPlayed <= 0 {
		return out
	}
	questionIDs, err := keys.GetQuestions(ctx, s.rdb, roomID)
	if err != nil || len(questionIDs) == 0 {
		return out
	}

	// The questions list may be longer than roundsPlayed (Redis stores
	// all selected questions for the match; an early-abandon match
	// only played a prefix). Trim so we don't fetch extra rows.
	if roundsPlayed < len(questionIDs) {
		questionIDs = questionIDs[:roundsPlayed]
	}

	// Convert string IDs to ObjectIDs; skip any that don't parse.
	objIDs := make([]bson.ObjectID, 0, len(questionIDs))
	idxByObjHex := make(map[string]int, len(questionIDs))
	for i, idStr := range questionIDs {
		oid, err := bson.ObjectIDFromHex(idStr)
		if err != nil {
			continue
		}
		objIDs = append(objIDs, oid)
		idxByObjHex[oid.Hex()] = i // round = i+1
	}
	if len(objIDs) == 0 {
		return out
	}

	cursor, err := s.mongoDB.Collection("questions").Find(ctx,
		bson.M{"_id": bson.M{"$in": objIDs}},
		options.Find().SetProjection(bson.M{"topic": 1}),
	)
	if err != nil {
		return out
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var doc struct {
			ID    bson.ObjectID `bson:"_id"`
			Topic string        `bson:"topic"`
		}
		if err := cursor.Decode(&doc); err != nil {
			continue
		}
		if idx, ok := idxByObjHex[doc.ID.Hex()]; ok {
			out[idx+1] = doc.Topic
		}
	}
	return out
}

// ---------------------------------------------------------------------------
// Analytics Worker — stub that logs match.finished payloads (section 9.6 note)
// ---------------------------------------------------------------------------

func (s *scoringServer) consumeAnalytics(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatal(ctx, "open channel failed", "consumer", "analytics", "err", err)
	}
	defer ch.Close()

	if err := ch.Qos(16, 0, false); err != nil {
		log.Fatal(ctx, "qos failed", "consumer", "analytics", "err", err)
	}

	msgs, err := ch.Consume("match-analytics-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatal(ctx, "consume failed", "consumer", "analytics", "queue", "match-analytics-queue", "err", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			msgCtx := log.ContextFromDelivery(ctx, msg)
			// Stub: no real analytics yet (durable record lives in Mongo
			// match_history). Debug-level so the body dump only appears
			// when an operator opts in via LOG_LEVEL=debug — INFO would
			// emit one body-carrying line per finished match in prod.
			log.FromContext(msgCtx).Debug("match.finished event received", "consumer", "analytics", "body", string(msg.Body))
			msg.Ack(false)
			s.recordConsume("match-analytics-queue", metrics.StatusAck)
		}
	}
}

// ---------------------------------------------------------------------------
// Phase 2: payment.captured consumer — upgrade user plan (ISSUE-07)
// ---------------------------------------------------------------------------

func (s *scoringServer) consumePaymentCaptured(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatal(ctx, "open channel failed", "consumer", "payment", "err", err)
	}
	defer ch.Close()

	if err := ch.Qos(16, 0, false); err != nil {
		log.Fatal(ctx, "qos failed", "consumer", "payment", "err", err)
	}

	msgs, err := ch.Consume("payment-success-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatal(ctx, "consume failed", "consumer", "payment", "queue", "payment-success-queue", "err", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			msgCtx := log.ContextFromDelivery(ctx, msg)

			var event struct {
				UserID       string `json:"userId"`
				PlanDuration string `json:"planDuration"`
			}
			if err := json.Unmarshal(msg.Body, &event); err != nil {
				log.FromContext(msgCtx).Warn("bad payload", "consumer", "payment", "body", string(msg.Body), "err", err)
				msg.Nack(false, false)
				s.recordConsume("payment-success-queue", metrics.StatusNackDrop)
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
			if err := s.mongoDB.Collection("users").FindOne(msgCtx, bson.M{"_id": event.UserID}).Decode(&existingUser); err == nil {
				if t, ok := existingUser["planExpiresAt"].(time.Time); ok && t.After(base) {
					base = t // don't lose remaining premium days on renewal
				}
			}
			expiresAt := base.Add(duration)

			// Upgrade user plan in MongoDB. Clear premiumExpiryWarned so the
			// payment service's pre-warning worker will fire again against the
			// new (extended) expiry date — otherwise a renewing user would
			// never be reminded about the new expiry.
			_, err := s.mongoDB.Collection("users").UpdateOne(msgCtx,
				bson.M{"_id": event.UserID},
				bson.M{
					"$set":   bson.M{"plan": "premium", "planExpiresAt": expiresAt},
					"$unset": bson.M{"premiumExpiryWarned": ""},
				},
			)
			if err != nil {
				log.FromContext(msgCtx).Error("plan upgrade failed", "consumer", "payment", "user_id", event.UserID, "err", err)
				msg.Nack(false, true)
				s.recordConsume("payment-success-queue", metrics.StatusNackRequeue)
				continue
			}

			// Invalidate Redis plan cache (ISSUE-07)
			keys.DelPlan(msgCtx, s.rdb, event.UserID)

			// Publish activation notification
			notifJSON, _ := json.Marshal(map[string]interface{}{
				"event":  "notif.premium.activated",
				"userId": event.UserID,
			})
			s.publish(msgCtx, "notif.premium.activated", notifJSON)

			log.FromContext(msgCtx).Info("user upgraded to premium", "consumer", "payment", "user_id", event.UserID, "expires_at", expiresAt.Format("2006-01-02"))
			msg.Ack(false)
			s.recordConsume("payment-success-queue", metrics.StatusAck)
		}
	}
}

// ---------------------------------------------------------------------------
// Phase 2: referral.first_quiz_completed consumer (ISSUE-06 full chain)
// ---------------------------------------------------------------------------

func (s *scoringServer) consumeReferralEvents(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatal(ctx, "open channel failed", "consumer", "referral", "err", err)
	}
	defer ch.Close()

	if err := ch.Qos(16, 0, false); err != nil {
		log.Fatal(ctx, "qos failed", "consumer", "referral", "err", err)
	}

	msgs, err := ch.Consume("referral-event-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatal(ctx, "consume failed", "consumer", "referral", "queue", "referral-event-queue", "err", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			msgCtx := log.ContextFromDelivery(ctx, msg)
			if err := s.handleReferralEvent(msgCtx, msg.Body); err != nil {
				if errors.Is(err, errBadReferralPayload) {
					log.FromContext(msgCtx).Warn("bad payload dropping", "consumer", "referral", "body", string(msg.Body), "err", err)
					msg.Nack(false, false)
					s.recordConsume("referral-event-queue", metrics.StatusNackDrop)
					continue
				}
				log.FromContext(msgCtx).Error("referral event processing failed", "consumer", "referral", "body", string(msg.Body), "err", err)
				// Transient error — requeue. With classic queues there is no
				// auto-DLQ on a delivery-count threshold, so a persistent
				// failure (Mongo unreachable, etc.) loops until the
				// underlying issue is fixed; an operator alert on
				// referral-event-queue depth is the floor.
				msg.Nack(false, true)
				s.recordConsume("referral-event-queue", metrics.StatusNackRequeue)
				continue
			}
			msg.Ack(false)
			s.recordConsume("referral-event-queue", metrics.StatusAck)
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
		log.FromContext(ctx).Error("tournament lookup failed", "component", "tournament_standings", "err", err)
		return
	}
	defer cursor.Close(ctx)

	standings := s.mongoDB.Collection("tournament_standings")
	for cursor.Next(ctx) {
		var t models.Tournament
		if err := cursor.Decode(&t); err != nil {
			log.FromContext(ctx).Error("tournament decode failed", "component", "tournament_standings", "err", err)
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
				log.FromContext(ctx).Error("standings upsert failed", "component", "tournament_standings", "tournament_id", t.ID, "user_id", uid, "err", err)
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
		log.Fatal(ctx, "open channel failed", "consumer", "tournament_finished", "err", err)
	}
	defer ch.Close()

	if err := ch.Qos(16, 0, false); err != nil {
		log.Fatal(ctx, "qos failed", "consumer", "tournament_finished", "err", err)
	}

	msgs, err := ch.Consume("tournament-finished-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatal(ctx, "consume failed", "consumer", "tournament_finished", "queue", "tournament-finished-queue", "err", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			msgCtx := log.ContextFromDelivery(ctx, msg)
			if err := s.handleTournamentFinished(msgCtx, msg.Body); err != nil {
				if errors.Is(err, errBadTournamentPayload) {
					log.FromContext(msgCtx).Warn("bad payload dropping", "consumer", "tournament_finished", "body", string(msg.Body), "err", err)
					msg.Nack(false, false)
					s.recordConsume("tournament-finished-queue", metrics.StatusNackDrop)
					continue
				}
				log.FromContext(msgCtx).Error("tournament event processing failed", "consumer", "tournament_finished", "body", string(msg.Body), "err", err)
				// Transient — requeue. With classic queues there is no
				// auto-DLQ on a delivery-count threshold, so a persistent
				// failure (Mongo unreachable, etc.) loops until the
				// underlying issue is fixed; an operator alert on
				// tournament-finished-queue depth is the floor.
				msg.Nack(false, true)
				s.recordConsume("tournament-finished-queue", metrics.StatusNackRequeue)
				continue
			}
			msg.Ack(false)
			s.recordConsume("tournament-finished-queue", metrics.StatusAck)
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

	// ----- Queues scoring consumes from that ALSO live in quiz's setup -----
	//
	// answer-processing-queue, match-finished-queue, and match-analytics-queue
	// are declared by the quiz service too (services/quiz/main.go:setupRabbitMQ).
	// Docker-compose starts quiz and scoring in parallel — neither waits for
	// the other — so scoring's consumeAnswers / consumeMatchFinished /
	// consumeAnalytics raced quiz's declares and hit NOT_FOUND when scoring
	// won the start ordering. The consume's log.Fatal then killed the entire
	// scoring process (no restart policy in compose), silently breaking the
	// match flow for the whole CI run.
	//
	// QueueDeclare is idempotent across services as long as args match
	// EXACTLY, so we mirror quiz's declarations here. Either service can win
	// the race; whichever loses gets a no-op declare. The args MUST stay in
	// lockstep with services/quiz/main.go — any drift would surface as
	// PRECONDITION_FAILED instead of NOT_FOUND.

	// answer-processing-queue + its DLQ (scoring consumes via consumeAnswers).
	if _, err := ch.QueueDeclare("answer-processing-dlq", true, false, false, false, nil); err != nil {
		return fmt.Errorf("answer-processing DLQ declare: %w", err)
	}
	if _, err := ch.QueueDeclare("answer-processing-queue", true, false, false, false, amqp.Table{
		"x-dead-letter-exchange":    "",
		"x-dead-letter-routing-key": "answer-processing-dlq",
		"x-max-delivery-count":      3,
	}); err != nil {
		return fmt.Errorf("answer-processing queue declare: %w", err)
	}
	if err := ch.QueueBind("answer-processing-queue", "answer.submitted", "sx", false, nil); err != nil {
		return fmt.Errorf("answer-processing queue bind: %w", err)
	}

	// match-finished-queue (scoring consumes via consumeMatchFinished).
	if _, err := ch.QueueDeclare("match-finished-queue", true, false, false, false, nil); err != nil {
		return fmt.Errorf("match-finished queue declare: %w", err)
	}
	if err := ch.QueueBind("match-finished-queue", "match.finished", "sx", false, nil); err != nil {
		return fmt.Errorf("match-finished queue bind: %w", err)
	}

	// match-analytics-queue (scoring consumes via consumeAnalytics).
	if _, err := ch.QueueDeclare("match-analytics-queue", true, false, false, false, nil); err != nil {
		return fmt.Errorf("match-analytics queue declare: %w", err)
	}
	if err := ch.QueueBind("match-analytics-queue", "match.finished", "sx", false, nil); err != nil {
		return fmt.Errorf("match-analytics queue bind: %w", err)
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
	//
	// Dead-letter wiring: x-dead-letter-exchange + x-dead-letter-routing-key
	// route any explicitly-rejected delivery (Nack with requeue=false) to
	// referral-event-dlq. That covers the bad-payload path. We do NOT use
	// x-max-delivery-count — it's a quorum-queue-only argument that is
	// silently ignored on classic queues, so a transient-error loop on a
	// classic queue does NOT auto-DLQ after N redeliveries. Migrate to
	// quorum queues + x-delivery-limit later if we want that behaviour.
	if _, err := ch.QueueDeclare("referral-event-dlq", true, false, false, false, nil); err != nil {
		return fmt.Errorf("referral DLQ declare: %w", err)
	}
	if _, err := ch.QueueDeclare("referral-event-queue", true, false, false, false, amqp.Table{
		"x-dead-letter-exchange":    "",
		"x-dead-letter-routing-key": "referral-event-dlq",
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
	// Dead-letter wiring matches referral-event-queue above: explicit
	// Nack(false, false) sends the delivery to tournament-finished-dlq.
	// Transient-error retries (Nack false, true) loop until success; no
	// classic-queue auto-DLQ on redelivery count.
	if _, err := ch.QueueDeclare("tournament-finished-dlq", true, false, false, false, nil); err != nil {
		return fmt.Errorf("tournament-finished DLQ declare: %w", err)
	}
	if _, err := ch.QueueDeclare("tournament-finished-queue", true, false, false, false, amqp.Table{
		"x-dead-letter-exchange":    "",
		"x-dead-letter-routing-key": "tournament-finished-dlq",
	}); err != nil {
		return fmt.Errorf("tournament-finished queue declare: %w", err)
	}
	if err := ch.QueueBind("tournament-finished-queue", "tournament.finished", "sx", false, nil); err != nil {
		return fmt.Errorf("tournament-finished queue bind: %w", err)
	}

	// Phase 3 (4.3): coin-earn-queue. Every earn source (match win,
	// tournament placement, daily streak, referral fulfillment) publishes
	// coins.earn.<source>; this queue funnels them to handleEarnEvent,
	// which dispatches to ledger.Grant.
	//
	// Dead-letter wiring matches the other queues: explicit Nack(false,
	// false) on errBadEarnPayload diverts the delivery to coin-earn-dlq,
	// so a single broken producer can't head-of-line-block healthy
	// events. Transient errors (Mongo down, etc.) retry forever via
	// requeue — with classic queues there is no auto-DLQ on redelivery
	// count, so monitor coin-earn-queue depth as the floor.
	if _, err := ch.QueueDeclare("coin-earn-dlq", true, false, false, false, nil); err != nil {
		return fmt.Errorf("coin-earn DLQ declare: %w", err)
	}
	if _, err := ch.QueueDeclare(coins.EarnQueueName, true, false, false, false, amqp.Table{
		"x-dead-letter-exchange":    "",
		"x-dead-letter-routing-key": "coin-earn-dlq",
	}); err != nil {
		return fmt.Errorf("coin-earn queue declare: %w", err)
	}
	if err := ch.QueueBind(coins.EarnQueueName, coins.EarnBindingPattern, coins.EarnExchange, false, nil); err != nil {
		return fmt.Errorf("coin-earn queue bind: %w", err)
	}

	return nil
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

func main() {
	slog.SetDefault(log.Init("scoring"))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	cfg := config.MustCommon(ctx)

	// Redis
	rdb := redis.NewClient(&redis.Options{Addr: cfg.RedisAddr})
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatal(ctx, "redis connect failed", "err", err)
	}
	log.FromContext(ctx).Info("connected to Redis")

	// RabbitMQ
	conn, err := amqp.Dial(cfg.RabbitMQURL)
	if err != nil {
		log.Fatal(ctx, "rabbitmq connect failed", "err", err)
	}

	amqpCh, err := conn.Channel()
	if err != nil {
		log.Fatal(ctx, "rabbitmq channel failed", "err", err)
	}

	if err := setupRabbitMQ(amqpCh); err != nil {
		log.Fatal(ctx, "rabbitmq setup failed", "err", err)
	}
	log.FromContext(ctx).Info("connected to RabbitMQ")

	// MongoDB
	mongoClient, err := mongo.Connect(options.Client().ApplyURI(cfg.MongoURI).SetBSONOptions(&options.BSONOptions{
		ObjectIDAsHexString: true,
	}))
	if err != nil {
		log.Fatal(ctx, "mongodb connect failed", "err", err)
	}
	log.FromContext(ctx).Info("connected to MongoDB")

	jwtSecret := config.MustRequired(ctx, "JWT_SECRET")

	mongoDB := mongoClient.Database(coins.DefaultDBName)
	ledger := coins.NewLedger(mongoClient, coins.DefaultDBName)
	srv := &scoringServer{
		rdb:             rdb,
		amqpConn:        conn,
		amqpCh:          amqpCh,
		mongoClient:     mongoClient,
		mongoDB:         mongoDB,
		ledger:          ledger,
		purchase:        shop.NewPurchase(mongoClient, mongoDB, ledger),
		jwtSecret:       jwtSecret,
		referralLimiter: ratelimit.New(rdb, "referral_apply", 3, 10*time.Minute),
		purchaseLimiter: ratelimit.New(rdb, "purchase_shop_item", purchaseRateLimit, time.Minute),
		// §4.7 PR-A1: 10/hour caps the FCM-token churn vector. Real
		// clients touch this RPC once per install; 10/h leaves room for
		// dev-mode reinstalls and one accidental loop without blocking.
		fcmTokenLimiter: ratelimit.New(rdb, "fcm_token", 10, time.Hour),
	}

	// gRPC server — CalculateScore is called internally by the scoring worker
	// via loopback, so it must bypass JWT auth
	skipMethods := []string{
		"/quiz.ScoringService/CalculateScore",
	}
	m := metrics.New("scoring")
	metricsSrv := m.Serve(ctx, ":2112")
	srv.metrics = m

	// TLS opt-in via pkg/tlsutil — see docs/deployment-tls.md.
	grpcOpts := tlsutil.GRPCServerOptions(ctx)
	grpcOpts = append(grpcOpts,
		grpc.ChainUnaryInterceptor(
			log.UnaryServerInterceptor(),
			m.UnaryServerInterceptor(),
			auth.UnaryInterceptor(jwtSecret, skipMethods),
		),
		grpc.ChainStreamInterceptor(
			log.StreamServerInterceptor(),
			m.StreamServerInterceptor(),
			auth.StreamInterceptor(jwtSecret, skipMethods),
		),
	)
	grpcServer := grpc.NewServer(grpcOpts...)
	pb.RegisterScoringServiceServer(grpcServer, srv)

	// Bind to all interfaces so the docker-compose port forward
	// (50053:50053) actually delivers traffic to the listener — without
	// this the Flutter client's calls to scoring (GetHomeScreenData,
	// GetCoinBalance, GetMatchHistory, GetGlobalLeaderboard, the entire
	// coins/shop/friends/profile surface) NAT through docker to a port
	// nobody is listening on inside the container and surface to the
	// client as HTTP/2 errorCode 10 ("connection forcibly terminated").
	// Every other Go service in this repo binds the same way; scoring
	// is no different in deployment topology — production puts an API
	// gateway in front of the public RPCs and never exposes :50053
	// directly.
	//
	// TODO(security): CalculateScore is in skipMethods above because
	// the in-process selfClient calls it without a JWT. A prior
	// hardening (§4.7 PR-B/C7) bound this listener to 127.0.0.1 to
	// keep the answer-oracle attack surface off the container's eth0,
	// but it did so by silently breaking the Flutter app's access to
	// every other scoring RPC. The clean fix is to either (a) mint a
	// service JWT at scoring startup and have selfClient inject it via
	// a client interceptor so CalculateScore can drop out of
	// skipMethods, or (b) split scoring into a public listener on
	// :50053 (auth'd RPCs) and an internal Unix-socket / 127.0.0.1
	// listener that only registers CalculateScore. Tracking as a
	// follow-up — for now we trust the deployment to not expose 50053
	// publicly, the same trust every other gRPC service in this repo
	// already relies on.
	const grpcAddr = ":50053"
	lis, err := net.Listen("tcp", grpcAddr)
	if err != nil {
		log.Fatal(ctx, "listen failed", "addr", grpcAddr, "err", err)
	}

	// Start gRPC server in background, then set up self-client for CalculateScore
	go func() {
		log.FromContext(ctx).Info("gRPC serving", "addr", grpcAddr)
		if err := grpcServer.Serve(lis); err != nil {
			log.Fatal(ctx, "grpc serve failed", "err", err)
		}
	}()

	// Create gRPC loopback client so the scoring worker calls CalculateScore via gRPC
	selfConn, err := grpc.NewClient("localhost:50053",
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithChainUnaryInterceptor(log.UnaryClientInterceptor()),
		grpc.WithChainStreamInterceptor(log.StreamClientInterceptor()),
	)
	if err != nil {
		log.Fatal(ctx, "self-client create failed", "err", err)
	}
	srv.selfClient = pb.NewScoringServiceClient(selfConn)

	// Start RabbitMQ consumers — each goroutine selects on ctx.Done()
	// and exits cleanly when the root ctx is cancelled below.
	go srv.consumeAnswers(ctx)            // 9.5: answer scoring
	go srv.consumeMatchFinished(ctx)      // 9.6: persistence worker
	go srv.consumeAnalytics(ctx)          // 9.6 note: analytics stub
	go srv.consumePaymentCaptured(ctx)    // Phase 2: plan upgrade on payment
	go srv.consumeReferralEvents(ctx)     // Phase 2: referral reward chain (ISSUE-06)
	go srv.consumeTournamentFinished(ctx) // Phase 3 (4.2): tournament prize coin awards
	go srv.consumeCoinEarn(ctx)           // Phase 3 (4.3): coins.earn.* → ledger.Grant
	go srv.drainChallengeNotifOutbox(ctx) // Phase 3 (4.4): retry stuck friend-challenge pushes

	// Block until SIGINT / SIGTERM, then drain gracefully.
	lifecycle.WaitForSignal(ctx)
	log.FromContext(ctx).Info("graceful shutdown starting")

	// Cancel root ctx so consumer goroutines exit their selects.
	cancel()

	// GracefulStop drains in-flight RPCs and blocks until they finish.
	grpcServer.GracefulStop()

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := metricsSrv.Shutdown(shutdownCtx); err != nil {
		log.FromContext(ctx).Warn("metrics shutdown", "err", err)
	}
	if err := selfConn.Close(); err != nil {
		log.FromContext(ctx).Warn("self gRPC conn close", "err", err)
	}
	if err := amqpCh.Close(); err != nil {
		log.FromContext(ctx).Warn("amqp channel close", "err", err)
	}
	if err := conn.Close(); err != nil {
		log.FromContext(ctx).Warn("amqp conn close", "err", err)
	}
	if err := mongoClient.Disconnect(shutdownCtx); err != nil {
		log.FromContext(ctx).Warn("mongo disconnect", "err", err)
	}
	log.FromContext(ctx).Info("graceful shutdown complete")
}
