package main

import (
	"context"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	pb "quiz-battle/proto"
)

// seedAnswerLog inserts one answer_log row. Helper for the analytics
// tests so the per-test seeding stays terse.
func seedAnswerLog(t *testing.T, c *mongo.Client, dbName, userID, topic string, correct bool, responseMs int64, when time.Time) {
	t.Helper()
	_, err := c.Database(dbName).Collection("answer_log").InsertOne(context.Background(), bson.M{
		"userId":         userID,
		"matchId":        "m-" + bson.NewObjectID().Hex(),
		"topic":          topic,
		"correct":        correct,
		"responseTimeMs": responseMs,
		"createdAt":      when,
	})
	if err != nil {
		t.Fatalf("seed answer_log: %v", err)
	}
}

func seedRatingHistory(t *testing.T, c *mongo.Client, dbName, userID string, rating, delta int32, when time.Time) {
	t.Helper()
	_, err := c.Database(dbName).Collection("rating_history").InsertOne(context.Background(), bson.M{
		"userId":      userID,
		"matchId":     "m-" + bson.NewObjectID().Hex(),
		"rating":      rating,
		"ratingDelta": delta,
		"createdAt":   when,
	})
	if err != nil {
		t.Fatalf("seed rating_history: %v", err)
	}
}

func seedMatchHistoryRow(t *testing.T, c *mongo.Client, dbName, roomID, winnerID string, players []string, when time.Time) {
	t.Helper()
	playersDoc := make([]bson.M, len(players))
	for i, uid := range players {
		playersDoc[i] = bson.M{"userId": uid, "username": uid, "rank": int32(i + 1)}
	}
	_, err := c.Database(dbName).Collection("match_history").InsertOne(context.Background(), bson.M{
		"roomId":    roomID,
		"winner":    winnerID,
		"players":   playersDoc,
		"createdAt": when,
	})
	if err != nil {
		t.Fatalf("seed match_history: %v", err)
	}
}

// authedCtx mirrors the helper in equip_test.go but defined here to
// avoid cross-test-file fragility.
func analyticsAuthedCtx(uid string) context.Context {
	return auth.ContextWithClaims(context.Background(),
		&auth.Claims{UserID: uid, Username: uid})
}

func TestGetUserAnalytics_RequiresAuth(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	_, err := srv.GetUserAnalytics(context.Background(), &pb.GetUserAnalyticsRequest{})
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("got %v, want Unauthenticated", err)
	}
}

func TestGetUserAnalytics_EmptyState(t *testing.T) {
	// User with zero answers logged — has_data=false, all panels empty,
	// no NaN from divide-by-zero, no spurious percentile values.
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	resp, err := srv.GetUserAnalytics(analyticsAuthedCtx("alice"), &pb.GetUserAnalyticsRequest{})
	if err != nil {
		t.Fatalf("GetUserAnalytics: %v", err)
	}
	if resp.HasData {
		t.Errorf("HasData should be false for empty answer_log")
	}
	if len(resp.TopicAccuracy) != 0 {
		t.Errorf("expected zero topic rows, got %d", len(resp.TopicAccuracy))
	}
	if resp.ResponseTime == nil || resp.ResponseTime.SampleCount != 0 {
		t.Errorf("sample count should be 0 for empty user, got %+v", resp.ResponseTime)
	}
	if resp.ResponseTime.P50Ms != 0 {
		t.Errorf("p50 should be 0 below sample-count floor, got %v", resp.ResponseTime.P50Ms)
	}
}

func TestGetUserAnalytics_TopicAccuracy_GroupsAndOrders(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	// 3 sci correct + 1 sci wrong → 75% in sci, 4 total.
	// 1 hist correct + 2 hist wrong → 33% in hist, 3 total.
	// sci has more answers so it must come first.
	when := time.Now().UTC()
	for i := 0; i < 3; i++ {
		seedAnswerLog(t, c, db, "alice", "science", true, 3000, when)
	}
	seedAnswerLog(t, c, db, "alice", "science", false, 8000, when)
	seedAnswerLog(t, c, db, "alice", "history", true, 4000, when)
	for i := 0; i < 2; i++ {
		seedAnswerLog(t, c, db, "alice", "history", false, 9000, when)
	}

	resp, err := srv.GetUserAnalytics(analyticsAuthedCtx("alice"), &pb.GetUserAnalyticsRequest{})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if !resp.HasData {
		t.Fatalf("expected has_data=true")
	}
	if len(resp.TopicAccuracy) != 2 {
		t.Fatalf("got %d topic rows, want 2", len(resp.TopicAccuracy))
	}
	// First row must be the most-played topic.
	if resp.TopicAccuracy[0].Topic != "science" {
		t.Errorf("first topic should be most-played (science), got %q", resp.TopicAccuracy[0].Topic)
	}
	if resp.TopicAccuracy[0].Total != 4 || resp.TopicAccuracy[0].Correct != 3 {
		t.Errorf("science totals: %+v", resp.TopicAccuracy[0])
	}
	if want := 3.0 / 4.0; resp.TopicAccuracy[0].AccuracyRatio != want {
		t.Errorf("science accuracy_ratio=%v, want %v", resp.TopicAccuracy[0].AccuracyRatio, want)
	}
	if resp.TopicAccuracy[1].Topic != "history" {
		t.Errorf("second topic = %q, want history", resp.TopicAccuracy[1].Topic)
	}
}

func TestGetUserAnalytics_PercentilesGatedByMinSamples(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	// 19 answers — one under the 20-sample floor, so percentile fields
	// must stay zero. The average is always populated when N > 0 since
	// the mean is meaningful at any sample size.
	when := time.Now().UTC()
	for i := int64(1); i <= 19; i++ {
		seedAnswerLog(t, c, db, "alice", "science", true, i*100, when)
	}
	resp, _ := srv.GetUserAnalytics(analyticsAuthedCtx("alice"), &pb.GetUserAnalyticsRequest{})
	if resp.ResponseTime.P50Ms != 0 || resp.ResponseTime.P99Ms != 0 {
		t.Errorf("percentile fields must be zero below the sample floor: %+v", resp.ResponseTime)
	}
	if resp.ResponseTime.SampleCount != 19 {
		t.Errorf("sample_count = %d, want 19", resp.ResponseTime.SampleCount)
	}
	// Mean of 100, 200, ..., 1900 = 1000ms exactly.
	if resp.ResponseTime.AvgMs != 1000 {
		t.Errorf("avg_ms = %v, want 1000 (mean of 100..1900)", resp.ResponseTime.AvgMs)
	}
}

func TestGetUserAnalytics_PercentilesAtAndAboveFloor(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	when := time.Now().UTC()
	// 20 evenly-spaced response times: 500, 1000, …, 10000 (ms). At the
	// minimum-sample floor, nearest-rank gives distinct indices for
	// p50/p90/p95/p99 — values[9], values[17], values[18], values[19]
	// respectively (1000ms apart but small enough that pinning indices,
	// not exact ms, keeps the test stable if the seed values change).
	for i := int64(1); i <= 20; i++ {
		seedAnswerLog(t, c, db, "alice", "science", true, i*500, when)
	}

	resp, _ := srv.GetUserAnalytics(analyticsAuthedCtx("alice"), &pb.GetUserAnalyticsRequest{})
	rt := resp.ResponseTime
	if rt.SampleCount != 20 {
		t.Errorf("sample_count=%d, want 20", rt.SampleCount)
	}
	// Nearest-rank at N=20 picks distinct indices, so p50 < p90 < p95 < p99
	// strictly. Catching a regression to <=-only would let percentile
	// collapse (the bug the higher floor was supposed to prevent) sneak
	// back in.
	if !(rt.P50Ms > 0 && rt.P50Ms < rt.P90Ms && rt.P90Ms < rt.P95Ms && rt.P95Ms < rt.P99Ms) {
		t.Errorf("percentiles must be strictly increasing at N=20: %+v", rt)
	}
	// Avg of 500, 1000, …, 10000 = 5250ms. Pinning the exact value
	// guards against an accidental switch to median/mode if someone
	// later refactors this code path.
	if rt.AvgMs != 5250 {
		t.Errorf("avg_ms = %v, want 5250 (mean of 500..10000 step 500)", rt.AvgMs)
	}
}

// TestGetUserAnalytics_LifetimeMatchTotalsFromHistory pins the fix for
// the "Stats says 2 matches, History shows 6" bug. lifetimeMatchTotals
// must aggregate from match_history (the same source the History
// screen pages through), not from users.matchesPlayed which is
// undercounted when persistMatch's leaderboard-entry loop skips
// score-zero participants.
func TestGetUserAnalytics_LifetimeMatchTotalsFromHistory(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	// Seed user with deliberately-stale counter values — the analytics
	// endpoint must IGNORE these and count from match_history.
	seedScoringUser(t, c, db, "alice", 0)
	_, _ = c.Database(db).Collection("users").UpdateOne(context.Background(),
		bson.M{"_id": "alice"},
		bson.M{"$set": bson.M{"matchesPlayed": int32(2), "wins": int32(1)}},
	)
	when := time.Now().UTC()
	// Six match_history rows: alice wins one, the other five are
	// score-zero participations (the case that breaks the stale
	// counter).
	seedMatchHistoryRow(t, c, db, "m1", "alice", []string{"alice", "bob"}, when)
	seedMatchHistoryRow(t, c, db, "m2", "bob", []string{"alice", "bob"}, when)
	seedMatchHistoryRow(t, c, db, "m3", "", []string{"alice", "bob"}, when) // no winner (both 0)
	seedMatchHistoryRow(t, c, db, "m4", "", []string{"alice", "bob"}, when)
	seedMatchHistoryRow(t, c, db, "m5", "", []string{"alice", "bob"}, when)
	seedMatchHistoryRow(t, c, db, "m6", "", []string{"alice", "bob"}, when)

	resp, err := srv.GetUserAnalytics(analyticsAuthedCtx("alice"), &pb.GetUserAnalyticsRequest{})
	if err != nil {
		t.Fatalf("GetUserAnalytics: %v", err)
	}
	if resp.LifetimeMatches != 6 {
		t.Errorf("lifetime_matches = %d, want 6 (must reflect match_history, not the stale users.matchesPlayed=2)", resp.LifetimeMatches)
	}
	if resp.LifetimeWins != 1 {
		t.Errorf("lifetime_wins = %d, want 1 (alice won m1 only)", resp.LifetimeWins)
	}
}

func TestGetUserAnalytics_RatingHistory_OldestFirstAndDayBucketed(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	// 3 separate UTC days, with the middle day having TWO matches at
	// different times of day — the LATER match's rating must win that
	// bucket. Build absolute UTC midnights N days back so both matches
	// on day-2 land in the same calendar date.
	now := time.Now().UTC()
	midnightNDaysBack := func(n int) time.Time {
		t := now.AddDate(0, 0, -n)
		return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
	}
	day1Mid := midnightNDaysBack(3).Add(12 * time.Hour)  // d-3 12:00
	day2Early := midnightNDaysBack(2).Add(4 * time.Hour) // d-2 04:00
	day2Late := midnightNDaysBack(2).Add(22 * time.Hour) // d-2 22:00 (same UTC date)
	day3Mid := midnightNDaysBack(1).Add(9 * time.Hour)   // d-1 09:00

	seedRatingHistory(t, c, db, "alice", 1200, +20, day1Mid)
	seedRatingHistory(t, c, db, "alice", 1180, -20, day2Early)
	seedRatingHistory(t, c, db, "alice", 1230, +50, day2Late)
	seedRatingHistory(t, c, db, "alice", 1240, +10, day3Mid)

	resp, err := srv.GetUserAnalytics(analyticsAuthedCtx("alice"), &pb.GetUserAnalyticsRequest{})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if len(resp.RatingHistory) != 3 {
		t.Fatalf("expected 3 daily buckets, got %d (%+v)", len(resp.RatingHistory), resp.RatingHistory)
	}
	// Oldest first.
	if !(resp.RatingHistory[0].UnixDay < resp.RatingHistory[1].UnixDay &&
		resp.RatingHistory[1].UnixDay < resp.RatingHistory[2].UnixDay) {
		t.Errorf("rating_history not oldest-first: %+v", resp.RatingHistory)
	}
	// Middle day picks the later match's rating.
	if resp.RatingHistory[1].Rating != 1230 {
		t.Errorf("day-2 rating = %d, want 1230 (later match)", resp.RatingHistory[1].Rating)
	}
}

func TestGetUserAnalytics_RatingHistory_30DayCutoff(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	// 60-day-old row must NOT appear; 5-day-old row must appear.
	old := time.Now().UTC().AddDate(0, 0, -60)
	recent := time.Now().UTC().AddDate(0, 0, -5)
	seedRatingHistory(t, c, db, "alice", 1100, +10, old)
	seedRatingHistory(t, c, db, "alice", 1200, +20, recent)

	resp, _ := srv.GetUserAnalytics(analyticsAuthedCtx("alice"), &pb.GetUserAnalyticsRequest{})
	if len(resp.RatingHistory) != 1 {
		t.Fatalf("expected 1 point inside 30-day window, got %d", len(resp.RatingHistory))
	}
	if resp.RatingHistory[0].Rating != 1200 {
		t.Errorf("kept the wrong row: %+v", resp.RatingHistory[0])
	}
}

func TestGetUserAnalytics_EmptyTopicCollapsesToUnknown(t *testing.T) {
	// loadTopicsForMatch returns "" when a question doc was missing.
	// The analytics surface must show those rows as "(unknown)" instead
	// of a blank chip — debuggable in the UI rather than silently lost.
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	when := time.Now().UTC()
	seedAnswerLog(t, c, db, "alice", "", true, 2000, when)
	seedAnswerLog(t, c, db, "alice", "", false, 5000, when)

	resp, _ := srv.GetUserAnalytics(analyticsAuthedCtx("alice"), &pb.GetUserAnalyticsRequest{})
	if len(resp.TopicAccuracy) != 1 || resp.TopicAccuracy[0].Topic != "(unknown)" {
		t.Errorf("expected one (unknown) row, got %+v", resp.TopicAccuracy)
	}
}

func TestGetMonthlyRecap_RequiresAuth(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	_, err := srv.GetMonthlyRecap(context.Background(), &pb.GetMonthlyRecapRequest{Year: 2026, Month: 4})
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("got %v, want Unauthenticated", err)
	}
}

func TestGetMonthlyRecap_RejectsBadInput(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	for _, tc := range []*pb.GetMonthlyRecapRequest{
		{Year: 1999, Month: 5},  // year too low
		{Year: 2200, Month: 5},  // year too high
		{Year: 2026, Month: 0},  // month too low
		{Year: 2026, Month: 13}, // month too high
	} {
		_, err := srv.GetMonthlyRecap(analyticsAuthedCtx("alice"), tc)
		if status.Code(err) != codes.InvalidArgument {
			t.Errorf("input %+v should fail with InvalidArgument, got %v", tc, err)
		}
	}
}

func TestGetMonthlyRecap_EmptyMonth(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	resp, err := srv.GetMonthlyRecap(analyticsAuthedCtx("alice"),
		&pb.GetMonthlyRecapRequest{Year: 2026, Month: 4})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if resp.HasData {
		t.Errorf("HasData should be false for an empty month")
	}
	if resp.MatchesPlayed != 0 || resp.Wins != 0 || resp.WinRate != 0 {
		t.Errorf("zero counters expected, got %+v", resp)
	}
	if resp.FavoriteTopic != "" {
		t.Errorf("favorite should be empty when no answers logged, got %q", resp.FavoriteTopic)
	}
}

func TestGetMonthlyRecap_HappyPath(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)
	// Seed lifetime longest streak so the recap can surface it.
	_, _ = c.Database(db).Collection("users").UpdateOne(context.Background(),
		bson.M{"_id": "alice"},
		bson.M{"$set": bson.M{"streak.longest": int32(7)}},
	)

	monthStart := time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC)
	insideMonth := monthStart.AddDate(0, 0, 5).Add(10 * time.Hour)
	monthBefore := monthStart.AddDate(0, 0, -1)
	monthAfter := monthStart.AddDate(0, 1, 1)

	// 2 wins + 1 loss inside the month, plus matches outside that
	// must NOT be counted.
	seedMatchHistoryRow(t, c, db, "r1", "alice", []string{"alice", "bob"}, insideMonth)
	seedMatchHistoryRow(t, c, db, "r2", "alice", []string{"alice", "bob"}, insideMonth)
	seedMatchHistoryRow(t, c, db, "r3", "bob", []string{"alice", "bob"}, insideMonth)
	seedMatchHistoryRow(t, c, db, "r4", "alice", []string{"alice", "bob"}, monthBefore)
	seedMatchHistoryRow(t, c, db, "r5", "alice", []string{"alice", "bob"}, monthAfter)

	// 5 sci + 3 hist answers inside; 10 hist answers outside (must not
	// influence favorite topic for the month).
	for i := 0; i < 5; i++ {
		seedAnswerLog(t, c, db, "alice", "science", true, 3000, insideMonth)
	}
	for i := 0; i < 3; i++ {
		seedAnswerLog(t, c, db, "alice", "history", false, 4000, insideMonth)
	}
	for i := 0; i < 10; i++ {
		seedAnswerLog(t, c, db, "alice", "history", true, 3000, monthBefore)
	}

	resp, err := srv.GetMonthlyRecap(analyticsAuthedCtx("alice"),
		&pb.GetMonthlyRecapRequest{Year: 2026, Month: 4})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if !resp.HasData {
		t.Errorf("HasData should be true")
	}
	if resp.MatchesPlayed != 3 {
		t.Errorf("matches=%d, want 3 (only inside-month matches)", resp.MatchesPlayed)
	}
	if resp.Wins != 2 {
		t.Errorf("wins=%d, want 2", resp.Wins)
	}
	if want := 2.0 / 3.0; resp.WinRate != want {
		t.Errorf("win_rate=%v, want %v", resp.WinRate, want)
	}
	if resp.FavoriteTopic != "science" {
		t.Errorf("favorite=%q, want science (most-answered inside month)", resp.FavoriteTopic)
	}
	if resp.LongestStreakLifetime != 7 {
		t.Errorf("longest_streak_lifetime=%d, want 7", resp.LongestStreakLifetime)
	}
}
