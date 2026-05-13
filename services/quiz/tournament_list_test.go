package main

import (
	"context"
	"strings"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"

	pb "quiz-battle/proto"
)

// TestGetTournamentList_ReturnsTimeMillisAndStringID guards the two bugs
// that motivated the fix:
//
//   - StartTime / EndTime had previously decoded into a bson.M as
//     bson.DateTime (int64 ms), not time.Time, so the type assertion in
//     the old handler always failed and the wire field stayed at 0 —
//     Flutter then rendered "Starts 20585d ago" (Unix epoch).
//   - _id stringified via fmt.Sprintf("%v", …) returned the wrapped
//     literal ObjectID("…hex…") rather than bare hex, so the round-tripped
//     id passed back into JoinTournament failed its _id lookup.
//
// Both regress trivially without a real Mongo round-trip, hence the
// integration-style test against a per-test database. Falls through to
// t.Skip when Mongo isn't reachable via newTestQuizServer's check.
func TestGetTournamentList_ReturnsTimeMillisAndStringID(t *testing.T) {
	srv := newTestQuizServer(t)
	id := bson.NewObjectID().Hex()
	now := time.Now().UTC()
	startAt := now.Add(time.Hour)
	endAt := now.Add(24 * time.Hour)
	if _, err := srv.mongoDB.Collection("tournaments").InsertOne(context.Background(), bson.M{
		"_id":              id,
		"name":             "Weekend Warriors",
		"startTime":        startAt,
		"endTime":          endAt,
		"status":           "upcoming",
		"requiredPlan":     "free",
		"prizeDescription": "Top 3 win 500/300/100 coins",
		"prizePool":        []int64{500, 300, 100},
		"participants":     []string{"alice", "bob", "carol"},
	}); err != nil {
		t.Fatalf("seed: %v", err)
	}

	resp, err := srv.GetTournamentList(authedCtx("alice"), &pb.GetTournamentListRequest{})
	if err != nil {
		t.Fatalf("GetTournamentList: %v", err)
	}
	if len(resp.Tournaments) != 1 {
		t.Fatalf("tournaments len = %d, want 1", len(resp.Tournaments))
	}
	got := resp.Tournaments[0]

	if got.Id != id {
		t.Errorf("Id = %q, want %q (no ObjectID(...) wrapper)", got.Id, id)
	}
	if strings.Contains(got.Id, "ObjectID(") {
		t.Errorf("Id %q still has the ObjectID wrapper", got.Id)
	}
	if got.Name != "Weekend Warriors" {
		t.Errorf("Name = %q, want Weekend Warriors", got.Name)
	}
	if got.ParticipantCount != 3 {
		t.Errorf("ParticipantCount = %d, want 3", got.ParticipantCount)
	}
	if got.StartTime <= 0 {
		t.Errorf("StartTime = %d, want > 0 (the Unix-epoch bug)", got.StartTime)
	}
	if got.EndTime <= got.StartTime {
		t.Errorf("EndTime (%d) should be after StartTime (%d)", got.EndTime, got.StartTime)
	}
	// Round-trip the times within a ms tolerance — Go's time.Time is
	// nanosecond precision, BSON is millisecond, and tests can lose the
	// sub-ms remainder. Anything farther than 2ms apart indicates we're
	// emitting seconds (or zero) rather than millis.
	if delta := got.StartTime - startAt.UnixMilli(); delta < -2 || delta > 2 {
		t.Errorf("StartTime delta = %dms (got %d, want ~%d)", delta, got.StartTime, startAt.UnixMilli())
	}
	if delta := got.EndTime - endAt.UnixMilli(); delta < -2 || delta > 2 {
		t.Errorf("EndTime delta = %dms (got %d, want ~%d)", delta, got.EndTime, endAt.UnixMilli())
	}
}

// TestGetTournamentList_FiltersByStatus pins the lobby contract: only
// "upcoming" and "active" tournaments appear; "completed" ones are
// excluded. Without this, a status-filter regression (e.g. someone
// flips the $in to a broader set or removes it) would only surface
// once the finalization worker had populated completed docs.
func TestGetTournamentList_FiltersByStatus(t *testing.T) {
	srv := newTestQuizServer(t)
	upcomingID := bson.NewObjectID().Hex()
	activeID := bson.NewObjectID().Hex()
	completedID := bson.NewObjectID().Hex()
	now := time.Now().UTC()
	if _, err := srv.mongoDB.Collection("tournaments").InsertMany(context.Background(), []any{
		bson.M{
			"_id":              upcomingID,
			"name":             "Upcoming Show",
			"startTime":        now.Add(time.Hour),
			"endTime":          now.Add(2 * time.Hour),
			"status":           "upcoming",
			"requiredPlan":     "free",
			"prizeDescription": "x",
			"participants":     []string{},
		},
		bson.M{
			"_id":              activeID,
			"name":             "Active Now",
			"startTime":        now.Add(-time.Hour),
			"endTime":          now.Add(time.Hour),
			"status":           "active",
			"requiredPlan":     "free",
			"prizeDescription": "y",
			"participants":     []string{},
		},
		bson.M{
			"_id":              completedID,
			"name":             "Already Done",
			"startTime":        now.Add(-3 * time.Hour),
			"endTime":          now.Add(-time.Hour),
			"status":           "completed",
			"requiredPlan":     "free",
			"prizeDescription": "z",
			"participants":     []string{},
		},
	}); err != nil {
		t.Fatalf("seed: %v", err)
	}

	resp, err := srv.GetTournamentList(authedCtx("alice"), &pb.GetTournamentListRequest{})
	if err != nil {
		t.Fatalf("GetTournamentList: %v", err)
	}
	if len(resp.Tournaments) != 2 {
		t.Fatalf("tournaments len = %d, want 2 (upcoming + active only)", len(resp.Tournaments))
	}
	seen := map[string]bool{}
	for _, x := range resp.Tournaments {
		seen[x.Id] = true
	}
	if !seen[upcomingID] {
		t.Errorf("upcoming tournament %s missing from result", upcomingID)
	}
	if !seen[activeID] {
		t.Errorf("active tournament %s missing from result", activeID)
	}
	if seen[completedID] {
		t.Errorf("completed tournament %s should not appear in lobby list", completedID)
	}
}
