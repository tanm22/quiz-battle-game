package main

import (
	"context"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/keys"
	pb "quiz-battle/proto"
)

// ---------------------------------------------------------------------------
// GetNotificationPrefs
// ---------------------------------------------------------------------------

func TestGetNotificationPrefs_RejectsUnauthenticated(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	if _, err := srv.GetNotificationPrefs(context.Background(),
		&pb.GetNotificationPrefsRequest{}); status.Code(err) != codes.Unauthenticated {
		t.Errorf("got %v, want Unauthenticated", err)
	}
}

func TestGetNotificationPrefs_DefaultsForUserWithoutPrefs(t *testing.T) {
	// User exists but has never set notificationPrefs. We must surface a
	// useful response (default tz, empty mutes) rather than an error so
	// the Flutter settings screen can render its initial state.
	srv, c, dbName := scoringTestEnv(t)
	seedScoringUser(t, c, dbName, "alice", 0)

	resp, err := srv.GetNotificationPrefs(authedCtx("alice"), &pb.GetNotificationPrefsRequest{})
	if err != nil {
		t.Fatalf("GetNotificationPrefs: %v", err)
	}
	if resp.Timezone != "Asia/Kolkata" {
		t.Errorf("timezone: got %q, want Asia/Kolkata", resp.Timezone)
	}
	if len(resp.MutedTypes) != 0 {
		t.Errorf("mutedTypes: got %v, want []", resp.MutedTypes)
	}
}

func TestGetNotificationPrefs_ReturnsStoredValues(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedScoringUserWithPrefs(t, srv, "alice", []string{"streak", "tournament"}, "America/New_York")

	resp, err := srv.GetNotificationPrefs(authedCtx("alice"), &pb.GetNotificationPrefsRequest{})
	if err != nil {
		t.Fatalf("GetNotificationPrefs: %v", err)
	}
	if resp.Timezone != "America/New_York" {
		t.Errorf("timezone: got %q, want America/New_York", resp.Timezone)
	}
	// Sorted for determinism.
	if len(resp.MutedTypes) != 2 || resp.MutedTypes[0] != "streak" || resp.MutedTypes[1] != "tournament" {
		t.Errorf("mutedTypes: got %v, want [streak tournament]", resp.MutedTypes)
	}
}

// ---------------------------------------------------------------------------
// UpdateNotificationPrefs
// ---------------------------------------------------------------------------

func TestUpdateNotificationPrefs_RejectsUnknownCategory(t *testing.T) {
	srv, c, dbName := scoringTestEnv(t)
	seedScoringUser(t, c, dbName, "alice", 0)

	_, err := srv.UpdateNotificationPrefs(authedCtx("alice"),
		&pb.UpdateNotificationPrefsRequest{MutedTypes: []string{"streak", "made_up_kind"}})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("got %v, want InvalidArgument", err)
	}
}

func TestUpdateNotificationPrefs_RejectsBadTimezone(t *testing.T) {
	srv, c, dbName := scoringTestEnv(t)
	seedScoringUser(t, c, dbName, "alice", 0)

	_, err := srv.UpdateNotificationPrefs(authedCtx("alice"),
		&pb.UpdateNotificationPrefsRequest{Timezone: "Mars/Olympus_Mons"})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("got %v, want InvalidArgument", err)
	}
}

func TestUpdateNotificationPrefs_PersistsAndDedups(t *testing.T) {
	srv, c, dbName := scoringTestEnv(t)
	seedScoringUser(t, c, dbName, "alice", 0)

	// Send dups to confirm set semantics.
	resp, err := srv.UpdateNotificationPrefs(authedCtx("alice"),
		&pb.UpdateNotificationPrefsRequest{
			MutedTypes: []string{"streak", "streak", "tournament"},
			Timezone:   "America/Los_Angeles",
		})
	if err != nil || !resp.Success {
		t.Fatalf("update: resp=%+v err=%v", resp, err)
	}

	got, err := srv.GetNotificationPrefs(authedCtx("alice"), &pb.GetNotificationPrefsRequest{})
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.Timezone != "America/Los_Angeles" {
		t.Errorf("timezone: got %q, want America/Los_Angeles", got.Timezone)
	}
	if len(got.MutedTypes) != 2 || got.MutedTypes[0] != "streak" || got.MutedTypes[1] != "tournament" {
		t.Errorf("mutedTypes (deduped+sorted): got %v, want [streak tournament]", got.MutedTypes)
	}
}

func TestUpdateNotificationPrefs_EmptyTimezonePreservesExisting(t *testing.T) {
	// A client that only wants to change mutes can omit timezone (empty
	// string). The stored timezone must NOT be cleared.
	srv, _, _ := scoringTestEnv(t)
	seedScoringUserWithPrefs(t, srv, "alice", []string{"streak"}, "America/New_York")

	_, err := srv.UpdateNotificationPrefs(authedCtx("alice"),
		&pb.UpdateNotificationPrefsRequest{MutedTypes: []string{"tournament"}})
	if err != nil {
		t.Fatalf("update: %v", err)
	}

	got, _ := srv.GetNotificationPrefs(authedCtx("alice"), &pb.GetNotificationPrefsRequest{})
	if got.Timezone != "America/New_York" {
		t.Errorf("timezone wiped by empty update: got %q, want America/New_York", got.Timezone)
	}
}

// ---------------------------------------------------------------------------
// MarkNotificationOpened
// ---------------------------------------------------------------------------

func TestMarkNotificationOpened_BumpsRedisCounter(t *testing.T) {
	srv, c, dbName := scoringTestEnv(t)
	attachRedis(t, srv)
	seedScoringUser(t, c, dbName, "alice", 0)

	if _, err := srv.MarkNotificationOpened(authedCtx("alice"),
		&pb.MarkNotificationOpenedRequest{Category: "friend_challenge"}); err != nil {
		t.Fatalf("MarkNotificationOpened: %v", err)
	}
	day := time.Now().UTC().Format("2006-01-02")
	got, err := srv.rdb.Get(context.Background(),
		keys.NotifMetricOpened("friend_challenge", day)).Int()
	if err != nil {
		t.Fatalf("redis get: %v", err)
	}
	if got != 1 {
		t.Errorf("opened counter: got %d, want 1", got)
	}
}

func TestMarkNotificationOpened_DedupsRepeatsWithinDay(t *testing.T) {
	// A misbehaving client calling MarkNotificationOpened in a loop
	// must not be able to inflate the global open counter — that would
	// poison the open-rate metric. Per-(user, category, day) SETNX
	// gates the increment.
	srv, c, dbName := scoringTestEnv(t)
	attachRedis(t, srv)
	seedScoringUser(t, c, dbName, "alice", 0)

	for i := 0; i < 5; i++ {
		if _, err := srv.MarkNotificationOpened(authedCtx("alice"),
			&pb.MarkNotificationOpenedRequest{Category: "friend_challenge"}); err != nil {
			t.Fatalf("call #%d: %v", i, err)
		}
	}
	day := time.Now().UTC().Format("2006-01-02")
	got, err := srv.rdb.Get(context.Background(),
		keys.NotifMetricOpened("friend_challenge", day)).Int()
	if err != nil {
		t.Fatalf("redis get: %v", err)
	}
	if got != 1 {
		t.Errorf("opened counter inflated by repeats: got %d, want 1", got)
	}
}

func TestMarkNotificationOpened_RejectsUnknownCategory(t *testing.T) {
	srv, c, dbName := scoringTestEnv(t)
	attachRedis(t, srv)
	seedScoringUser(t, c, dbName, "alice", 0)

	_, err := srv.MarkNotificationOpened(authedCtx("alice"),
		&pb.MarkNotificationOpenedRequest{Category: "bogus"})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("got %v, want InvalidArgument", err)
	}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// seedScoringUserWithPrefs writes a user that already has stored
// notification prefs — useful for "Get returns existing" tests that
// shouldn't go through Update first.
func seedScoringUserWithPrefs(t *testing.T, srv *scoringServer, uid string, muted []string, tz string) {
	t.Helper()
	doc := bson.M{
		"_id":      uid,
		"username": uid,
		"coins":    int64(0),
		"notificationPrefs": bson.M{
			"mutedTypes": muted,
			"timezone":   tz,
		},
	}
	if _, err := srv.mongoDB.Collection("users").InsertOne(context.Background(), doc); err != nil {
		t.Fatalf("seed user with prefs: %v", err)
	}
}
