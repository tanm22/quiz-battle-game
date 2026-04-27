package main

import (
	"context"
	"errors"
	"fmt"
	"math"
	"sort"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/log"
	pb "quiz-battle/proto"
)

// §4.5 Deeper analytics RPCs.
//
// Both endpoints aggregate `answer_log` and `rating_history` rows that
// the persistMatch consumer writes after each finished match. Nothing is
// computed from `users.matchesPlayed` / `users.wins` for time-windowed
// numbers — those counters are lifetime-only, and using them for monthly
// recaps would mix in matches outside the requested month.

const (
	analyticsRatingDays      = 30 // rating-graph window length
	analyticsMinPercentile   = 5  // need ≥5 answers before percentiles are meaningful
	analyticsTopicLabelEmpty = "(unknown)"
)

// GetUserAnalytics implements §4.5's profile-screen panels. Lifetime
// per-topic accuracy + lifetime response-time percentiles + the last
// 30 days of daily rating snapshots, all in one round trip so the
// Flutter screen renders without staggered loading states.
func (s *scoringServer) GetUserAnalytics(ctx context.Context, _ *pb.GetUserAnalyticsRequest) (*pb.GetUserAnalyticsResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	out := &pb.GetUserAnalyticsResponse{
		ResponseTime: &pb.ResponseTimePercentiles{},
	}

	// Per-topic accuracy. Empty topic strings (rare — only when
	// loadTopicsForMatch couldn't resolve the question) collapse into
	// "(unknown)" so they're visible in the chart rather than silently
	// dropped.
	topicAccuracy, totalAnswers, err := s.aggregateTopicAccuracy(ctx, userID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "topic accuracy: %v", err)
	}
	out.TopicAccuracy = topicAccuracy
	out.HasData = totalAnswers > 0

	// Response-time percentiles — only emit values once we have enough
	// samples for the percentile to mean anything. Below the floor the
	// client renders an empty-state copy ("N answers logged — keep
	// playing").
	if totalAnswers >= analyticsMinPercentile {
		percentiles, err := s.aggregatePercentiles(ctx, userID)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "percentiles: %v", err)
		}
		percentiles.SampleCount = totalAnswers
		out.ResponseTime = percentiles
	} else {
		out.ResponseTime.SampleCount = totalAnswers
	}

	// Rating history (last 30 days, oldest-first, one entry per UTC day).
	ratingPoints, err := s.aggregateRatingHistory(ctx, userID, analyticsRatingDays)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "rating history: %v", err)
	}
	out.RatingHistory = ratingPoints

	// Lifetime headline — read straight off the user document. The
	// analytics screen's hero strip needs these alongside the panels;
	// surfacing them here saves a separate GetHomeScreenData call.
	matches, wins, err := s.lifetimeMatchTotals(ctx, userID)
	if err != nil {
		// Lifetime totals are useful but not load-bearing — the rest of
		// the response is already populated. Log and zero them.
		out.LifetimeMatches = 0
		out.LifetimeWins = 0
	} else {
		out.LifetimeMatches = matches
		out.LifetimeWins = wins
	}

	return out, nil
}

// GetMonthlyRecap implements §4.5's recap card. Year + month pair; the
// month is treated in UTC (the `match_history.createdAt` and
// `answer_log.createdAt` writers both use server-UTC `time.Now()`).
func (s *scoringServer) GetMonthlyRecap(ctx context.Context, req *pb.GetMonthlyRecapRequest) (*pb.GetMonthlyRecapResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if req.Year < 2020 || req.Year > 2100 || req.Month < 1 || req.Month > 12 {
		return nil, status.Errorf(codes.InvalidArgument,
			"year (got %d) must be 2020-2100 and month (got %d) must be 1-12", req.Year, req.Month)
	}

	monthStart := time.Date(int(req.Year), time.Month(req.Month), 1, 0, 0, 0, 0, time.UTC)
	monthEnd := monthStart.AddDate(0, 1, 0) // exclusive upper bound

	// Matches played + wins for the month — read from match_history
	// because users.matchesPlayed/wins are lifetime counters with no
	// month dimension. The user joins through players.userId; we
	// distinguish wins by checking the match's winner string.
	matches, wins, err := s.matchTotalsInWindow(ctx, userID, monthStart, monthEnd)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "month totals: %v", err)
	}

	// Favorite topic — most-answered topic in the month from answer_log.
	// Empty string when the user logged no answers (e.g. they played
	// matches that pre-dated the §4.5 producer landing, or no matches
	// at all that month).
	favoriteTopic, err := s.favoriteTopicInWindow(ctx, userID, monthStart, monthEnd)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "favorite topic: %v", err)
	}

	// Longest streak — lifetime value off the user document. We don't
	// track per-month streak history (would need a dedicated
	// collection); the proto comment says so explicitly. Surfacing the
	// lifetime number is honest about what we measure.
	longest, err := s.lifetimeLongestStreak(ctx, userID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "longest streak: %v", err)
	}

	out := &pb.GetMonthlyRecapResponse{
		Year:                  req.Year,
		Month:                 req.Month,
		MatchesPlayed:         matches,
		Wins:                  wins,
		FavoriteTopic:         favoriteTopic,
		LongestStreakLifetime: longest,
		HasData:               matches > 0,
	}
	if matches > 0 {
		out.WinRate = float64(wins) / float64(matches)
	}
	return out, nil
}

// ---------------------------------------------------------------------------
// Aggregation helpers
// ---------------------------------------------------------------------------

// aggregateTopicAccuracy groups answer_log by topic and returns one
// TopicAccuracy per topic, sorted by total questions answered (desc) so
// the user's most-played topic always shows first. Also returns the
// total answer count which the caller uses to gate percentile emission.
func (s *scoringServer) aggregateTopicAccuracy(ctx context.Context, userID string) ([]*pb.TopicAccuracy, int64, error) {
	pipeline := mongo.Pipeline{
		{{Key: "$match", Value: bson.M{"userId": userID}}},
		{{Key: "$group", Value: bson.M{
			"_id":     "$topic",
			"total":   bson.M{"$sum": 1},
			"correct": bson.M{"$sum": bson.M{"$cond": []any{"$correct", 1, 0}}},
		}}},
		{{Key: "$sort", Value: bson.D{{Key: "total", Value: -1}}}},
	}
	cursor, err := s.mongoDB.Collection("answer_log").Aggregate(ctx, pipeline)
	if err != nil {
		return nil, 0, fmt.Errorf("aggregate: %w", err)
	}
	defer cursor.Close(ctx)

	var rows []*pb.TopicAccuracy
	var grandTotal int64
	for cursor.Next(ctx) {
		var doc struct {
			Topic   string `bson:"_id"`
			Total   int64  `bson:"total"`
			Correct int64  `bson:"correct"`
		}
		if err := cursor.Decode(&doc); err != nil {
			// Schema drift would otherwise produce empty/partial results
			// indistinguishable from a real empty account — log so the
			// anomaly is debuggable.
			log.FromContext(ctx).Warn("aggregateTopicAccuracy decode error",
				"component", "analytics", "user_id", userID, "err", err)
			continue
		}
		topic := doc.Topic
		if topic == "" {
			topic = analyticsTopicLabelEmpty
		}
		var pct float64
		if doc.Total > 0 {
			pct = float64(doc.Correct) / float64(doc.Total)
		}
		rows = append(rows, &pb.TopicAccuracy{
			Topic:       topic,
			Total:       int32(doc.Total),
			Correct:     int32(doc.Correct),
			AccuracyPct: pct,
		})
		grandTotal += doc.Total
	}
	if err := cursor.Err(); err != nil {
		return nil, 0, fmt.Errorf("cursor: %w", err)
	}
	return rows, grandTotal, nil
}

// aggregatePercentiles streams the user's responseTimeMs values
// sorted-ascending and computes nearest-rank percentiles in Go.
//
// We deliberately avoid Mongo's `$percentile` accumulator — it was added
// in 7.0 and the project's docker-compose pins `mongo:6`. With N ≤ a
// few thousand answers per user the in-memory pass is trivial; if the
// dataset ever grows past that we'd prefer a dedicated metrics store
// over server-side approximation anyway.
func (s *scoringServer) aggregatePercentiles(ctx context.Context, userID string) (*pb.ResponseTimePercentiles, error) {
	cursor, err := s.mongoDB.Collection("answer_log").Find(ctx,
		bson.M{"userId": userID},
		options.Find().
			SetSort(bson.D{{Key: "responseTimeMs", Value: 1}}).
			SetProjection(bson.M{"responseTimeMs": 1, "_id": 0}),
	)
	if err != nil {
		return nil, fmt.Errorf("find: %w", err)
	}
	defer cursor.Close(ctx)

	values := make([]float64, 0, 256)
	for cursor.Next(ctx) {
		var doc struct {
			ResponseTimeMs float64 `bson:"responseTimeMs"`
		}
		if err := cursor.Decode(&doc); err != nil {
			log.FromContext(ctx).Warn("aggregatePercentiles decode error",
				"component", "analytics", "user_id", userID, "err", err)
			continue
		}
		values = append(values, doc.ResponseTimeMs)
	}
	if err := cursor.Err(); err != nil {
		return nil, fmt.Errorf("cursor: %w", err)
	}
	if len(values) == 0 {
		return &pb.ResponseTimePercentiles{}, nil
	}

	// Nearest-rank percentile: index = ceil(N * p) - 1, clamped to
	// [0, N-1]. For sorted-ascending arrays this gives the lowest
	// value whose CDF is ≥ p, matching the textbook NIST definition.
	pct := func(p float64) float64 {
		n := float64(len(values))
		idx := int(math.Ceil(n*p)) - 1
		if idx < 0 {
			idx = 0
		}
		if idx >= len(values) {
			idx = len(values) - 1
		}
		return values[idx]
	}
	return &pb.ResponseTimePercentiles{
		P50Ms: pct(0.50),
		P90Ms: pct(0.90),
		P95Ms: pct(0.95),
		P99Ms: pct(0.99),
	}, nil
}

// aggregateRatingHistory pulls the last `days` of rating snapshots for
// the user, oldest-first, collapsed to one entry per UTC day. When a
// day saw multiple matches, the LAST match's post-rating wins (most
// users would expect "rating at end of day"). Days with no matches are
// omitted — the chart can either hold the previous value or interpolate.
func (s *scoringServer) aggregateRatingHistory(ctx context.Context, userID string, days int) ([]*pb.RatingPoint, error) {
	now := time.Now().UTC()
	cutoff := now.AddDate(0, 0, -days)

	cursor, err := s.mongoDB.Collection("rating_history").Find(ctx,
		bson.M{
			"userId":    userID,
			"createdAt": bson.M{"$gte": cutoff},
		},
	)
	if err != nil {
		return nil, fmt.Errorf("find: %w", err)
	}
	defer cursor.Close(ctx)

	// Bucket by (year, month, day) UTC and keep the latest rating per day.
	type dayKey struct{ y, m, d int }
	type entry struct {
		t      time.Time
		rating int32
	}
	byDay := make(map[dayKey]entry)
	for cursor.Next(ctx) {
		var doc struct {
			Rating    int32     `bson:"rating"`
			CreatedAt time.Time `bson:"createdAt"`
		}
		if err := cursor.Decode(&doc); err != nil {
			log.FromContext(ctx).Warn("aggregateRatingHistory decode error",
				"component", "analytics", "user_id", userID, "err", err)
			continue
		}
		t := doc.CreatedAt.UTC()
		k := dayKey{t.Year(), int(t.Month()), t.Day()}
		// Keep the row with the latest createdAt within the day.
		if cur, ok := byDay[k]; !ok || doc.CreatedAt.After(cur.t) {
			byDay[k] = entry{doc.CreatedAt, doc.Rating}
		}
	}
	if err := cursor.Err(); err != nil {
		return nil, fmt.Errorf("cursor: %w", err)
	}

	// Sort by day ascending (oldest first).
	out := make([]*pb.RatingPoint, 0, len(byDay))
	for k, v := range byDay {
		startOfDay := time.Date(k.y, time.Month(k.m), k.d, 0, 0, 0, 0, time.UTC)
		out = append(out, &pb.RatingPoint{UnixDay: startOfDay.Unix(), Rating: v.rating})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].UnixDay < out[j].UnixDay })
	return out, nil
}

// lifetimeMatchTotals reads matchesPlayed + wins straight off the user
// document. These are maintained by persistMatch's $inc-per-match
// (existing logic, unchanged).
func (s *scoringServer) lifetimeMatchTotals(ctx context.Context, userID string) (matches, wins int32, err error) {
	var doc struct {
		MatchesPlayed int32 `bson:"matchesPlayed"`
		Wins          int32 `bson:"wins"`
	}
	if err := s.mongoDB.Collection("users").
		FindOne(ctx, bson.M{"_id": userID}).Decode(&doc); err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return 0, 0, nil
		}
		return 0, 0, err
	}
	return doc.MatchesPlayed, doc.Wins, nil
}

func (s *scoringServer) lifetimeLongestStreak(ctx context.Context, userID string) (int32, error) {
	var doc struct {
		Streak struct {
			Longest int32 `bson:"longest"`
		} `bson:"streak"`
	}
	if err := s.mongoDB.Collection("users").
		FindOne(ctx, bson.M{"_id": userID}).Decode(&doc); err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return 0, nil
		}
		return 0, err
	}
	return doc.Streak.Longest, nil
}

// matchTotalsInWindow returns (matchesPlayed, wins) for the user in the
// half-open [start, end) UTC window. Reads match_history rather than
// users.* because the latter is lifetime-only.
func (s *scoringServer) matchTotalsInWindow(ctx context.Context, userID string, start, end time.Time) (int32, int32, error) {
	pipeline := mongo.Pipeline{
		{{Key: "$match", Value: bson.M{
			"players.userId": userID,
			"createdAt":      bson.M{"$gte": start, "$lt": end},
		}}},
		{{Key: "$group", Value: bson.M{
			"_id":     nil,
			"matches": bson.M{"$sum": 1},
			"wins":    bson.M{"$sum": bson.M{"$cond": []any{bson.M{"$eq": []any{"$winner", userID}}, 1, 0}}},
		}}},
	}
	cursor, err := s.mongoDB.Collection("match_history").Aggregate(ctx, pipeline)
	if err != nil {
		return 0, 0, fmt.Errorf("aggregate: %w", err)
	}
	defer cursor.Close(ctx)
	if !cursor.Next(ctx) {
		return 0, 0, nil
	}
	var doc struct {
		Matches int32 `bson:"matches"`
		Wins    int32 `bson:"wins"`
	}
	if err := cursor.Decode(&doc); err != nil {
		return 0, 0, fmt.Errorf("decode: %w", err)
	}
	return doc.Matches, doc.Wins, nil
}

// favoriteTopicInWindow returns the topic with the most answers logged
// in [start, end). Empty string if no rows match.
func (s *scoringServer) favoriteTopicInWindow(ctx context.Context, userID string, start, end time.Time) (string, error) {
	pipeline := mongo.Pipeline{
		{{Key: "$match", Value: bson.M{
			"userId":    userID,
			"createdAt": bson.M{"$gte": start, "$lt": end},
		}}},
		{{Key: "$group", Value: bson.M{"_id": "$topic", "n": bson.M{"$sum": 1}}}},
		{{Key: "$sort", Value: bson.D{{Key: "n", Value: -1}}}},
		{{Key: "$limit", Value: 1}},
	}
	cursor, err := s.mongoDB.Collection("answer_log").Aggregate(ctx, pipeline)
	if err != nil {
		return "", fmt.Errorf("aggregate: %w", err)
	}
	defer cursor.Close(ctx)
	if !cursor.Next(ctx) {
		return "", nil
	}
	var doc struct {
		Topic string `bson:"_id"`
	}
	if err := cursor.Decode(&doc); err != nil {
		return "", fmt.Errorf("decode: %w", err)
	}
	return doc.Topic, nil
}
