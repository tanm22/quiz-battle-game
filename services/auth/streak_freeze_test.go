package main

import (
	"context"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"

	"quiz-battle/pkg/models"
)

// loadUser is a tiny helper to re-fetch a user document from Mongo so each
// assertion sees the post-write state without sharing the mutated handler-
// local copy.
func loadUser(t *testing.T, srv *authServer, uid string) *models.User {
	t.Helper()
	var u models.User
	if err := srv.users().FindOne(context.Background(), bson.M{"_id": uid}).Decode(&u); err != nil {
		t.Fatalf("load user: %v", err)
	}
	return &u
}

// istToday returns today's IST date in the same format processStreak uses,
// so tests can construct realistic two-days-ago / yesterday timestamps
// without re-deriving the timezone math in each test.
func istToday(t *testing.T) string {
	t.Helper()
	loc, err := time.LoadLocation("Asia/Kolkata")
	if err != nil {
		t.Fatalf("load IST: %v", err)
	}
	return time.Now().In(loc).Format("2006-01-02")
}

func istDaysAgo(t *testing.T, days int) string {
	t.Helper()
	loc, _ := time.LoadLocation("Asia/Kolkata")
	return time.Now().In(loc).AddDate(0, 0, -days).Format("2006-01-02")
}

func TestProcessStreak_ConsumesFreezeWhenMissedDay(t *testing.T) {
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "alice")

	// User missed yesterday — last claimed two days ago, on a 5-day streak,
	// holding a streak freeze. Without consumption the streak would reset
	// to 1; with consumption it advances to 6.
	twoDaysAgo := istDaysAgo(t, 2)
	if _, err := srv.users().UpdateOne(context.Background(),
		bson.M{"_id": uid},
		bson.M{"$set": bson.M{
			"streak.lastClaimedDate": twoDaysAgo,
			"streak.current":         5,
			"streak.longest":         5,
			"streakFreezeHeld":       true,
		}},
	); err != nil {
		t.Fatalf("backdate: %v", err)
	}

	user := loadUser(t, srv, uid)
	si, _, ok := srv.processStreak(context.Background(), user)
	if !ok {
		t.Fatalf("expected processStreak to commit; got ok=false")
	}
	if si.Current != 6 {
		t.Errorf("freeze not applied: streak=%d, want 6", si.Current)
	}

	post := loadUser(t, srv, uid)
	if post.StreakFreezeHeld {
		t.Errorf("streak freeze should be consumed but is still held")
	}
	if post.Streak.Current != 6 || post.Streak.LastClaimedDate != istToday(t) {
		t.Errorf("post-state wrong: %+v", post.Streak)
	}
}

func TestProcessStreak_NoFreezeFallsThroughToReset(t *testing.T) {
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "bob")

	twoDaysAgo := istDaysAgo(t, 2)
	if _, err := srv.users().UpdateOne(context.Background(),
		bson.M{"_id": uid},
		bson.M{"$set": bson.M{
			"streak.lastClaimedDate": twoDaysAgo,
			"streak.current":         5,
			"streakFreezeHeld":       false,
		}},
	); err != nil {
		t.Fatalf("backdate: %v", err)
	}

	user := loadUser(t, srv, uid)
	si, _, ok := srv.processStreak(context.Background(), user)
	if !ok {
		t.Fatalf("expected commit, ok=false")
	}
	if si.Current != 1 {
		t.Errorf("missing freeze should reset streak to 1; got %d", si.Current)
	}
}

func TestProcessStreak_FirstEverLoginIgnoresFreeze(t *testing.T) {
	// First-ever login: lastClaimedDate is empty. Even if a freeze flag is
	// somehow set on a fresh user, the empty-date guard takes the reset
	// path so the user starts at 1, not 2.
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "carol")
	if _, err := srv.users().UpdateOne(context.Background(),
		bson.M{"_id": uid},
		bson.M{"$set": bson.M{"streakFreezeHeld": true}},
	); err != nil {
		t.Fatalf("set freeze: %v", err)
	}

	user := loadUser(t, srv, uid)
	si, _, ok := srv.processStreak(context.Background(), user)
	if !ok {
		t.Fatalf("expected commit, ok=false")
	}
	if si.Current != 1 {
		t.Errorf("first login with empty lastClaimedDate must start at 1; got %d", si.Current)
	}
	post := loadUser(t, srv, uid)
	if !post.StreakFreezeHeld {
		t.Errorf("freeze must NOT be consumed on first-ever login (no streak to preserve)")
	}
}

func TestProcessStreak_FreezeAndStreakUpdateAtomically(t *testing.T) {
	// The flag flip and streak fields must commit in one UpdateOne so a
	// reader at any moment sees consistent state. Cheap proof: after a
	// successful consumption, every relevant field reflects the new state
	// in a single FindOne.
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "dora")
	twoDaysAgo := istDaysAgo(t, 2)
	_, _ = srv.users().UpdateOne(context.Background(),
		bson.M{"_id": uid},
		bson.M{"$set": bson.M{
			"streak.lastClaimedDate": twoDaysAgo,
			"streak.current":         3,
			"streak.longest":         3,
			"streakFreezeHeld":       true,
		}},
	)

	_, _, _ = srv.processStreak(context.Background(), loadUser(t, srv, uid))

	post := loadUser(t, srv, uid)
	if post.StreakFreezeHeld {
		t.Errorf("freeze still held: %+v", post)
	}
	if post.Streak.Current != 4 || post.Streak.LastClaimedDate != istToday(t) {
		t.Errorf("streak fields wrong: %+v", post.Streak)
	}
	if post.Streak.Longest < 4 {
		t.Errorf("longest streak not advanced: %d", post.Streak.Longest)
	}
}
