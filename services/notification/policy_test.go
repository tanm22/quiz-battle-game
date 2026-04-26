package main

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"quiz-battle/pkg/keys"
)

// policyTestEnv stands up a fresh Mongo database + Redis client and
// returns a policy ready for assertions. Real infra (no fakes): the
// gate's behaviour depends on Redis atomicity and Mongo decode paths
// that are tedious to mock faithfully.
func policyTestEnv(t *testing.T, dailyCap int) (*policy, *mongo.Database, *redis.Client) {
	t.Helper()
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true"
	}
	mc, err := mongo.Connect(options.Client().ApplyURI(mongoURI))
	if err != nil {
		t.Skipf("mongo connect: %v", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := mc.Ping(ctx, nil); err != nil {
		t.Skipf("mongo ping: %v", err)
	}
	dbName := "notif_policy_test_" + bson.NewObjectID().Hex()
	db := mc.Database(dbName)

	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}
	// DB 15 is reserved for tests so FlushDB only nukes test keys —
	// dev stacks running on the default DB 0 are unaffected. Redis
	// ships with 16 logical DBs by default; nothing else in the repo
	// uses 15.
	rdb := redis.NewClient(&redis.Options{Addr: redisAddr, DB: 15})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		t.Skipf("redis ping: %v", err)
	}
	if err := rdb.FlushDB(context.Background()).Err(); err != nil {
		t.Fatalf("redis flushdb: %v", err)
	}

	t.Cleanup(func() {
		_ = db.Drop(context.Background())
		_ = mc.Disconnect(context.Background())
		_ = rdb.Close()
	})

	return newPolicy(rdb, db, dailyCap), db, rdb
}

// seedUser writes the minimal user doc the policy gate reads.
func seedUser(t *testing.T, db *mongo.Database, uid string, mutedTypes []string, tz string) {
	t.Helper()
	doc := bson.M{"_id": uid}
	prefs := bson.M{}
	if mutedTypes != nil {
		prefs["mutedTypes"] = mutedTypes
	}
	if tz != "" {
		prefs["timezone"] = tz
	}
	if len(prefs) > 0 {
		doc["notificationPrefs"] = prefs
	}
	if _, err := db.Collection("users").InsertOne(context.Background(), doc); err != nil {
		t.Fatalf("seed user: %v", err)
	}
}

// CategoryFromEvent is exercised in pkg/notif/categories_test.go —
// the wire contract lives with the package that owns it now.

// ---------------------------------------------------------------------------
// inQuietHours
// ---------------------------------------------------------------------------

func TestInQuietHours_StraddlesMidnight(t *testing.T) {
	utc := time.UTC
	// 23:00, 00:00, 03:00, 07:59 are quiet; 08:00, 12:00, 22:59 are not.
	cases := []struct {
		hour    int
		minute  int
		quiet   bool
		comment string
	}{
		{23, 0, true, "23:00 starts quiet"},
		{23, 30, true, "23:30 is quiet"},
		{0, 0, true, "midnight is quiet"},
		{3, 15, true, "3 AM is quiet"},
		{7, 59, true, "7:59 still quiet"},
		{8, 0, false, "8:00 is the boundary"},
		{12, 0, false, "noon is OK"},
		{22, 59, false, "just before 23:00 is OK"},
	}
	day := time.Date(2026, 5, 1, 0, 0, 0, 0, utc)
	for _, c := range cases {
		now := day.Add(time.Duration(c.hour)*time.Hour + time.Duration(c.minute)*time.Minute)
		if got := inQuietHours(now, utc); got != c.quiet {
			t.Errorf("%s: inQuietHours(%v) = %v, want %v", c.comment, now, got, c.quiet)
		}
	}
}

// ---------------------------------------------------------------------------
// allow() integration cases
// ---------------------------------------------------------------------------

// noonUTC returns 12:00 today UTC, comfortably outside all quiet-hour
// windows for any timezone the test uses.
func noonUTCNotInQuiet(t *testing.T, tzName string) {
	t.Helper()
	loc, err := time.LoadLocation(tzName)
	if err != nil {
		t.Fatalf("LoadLocation: %v", err)
	}
	if inQuietHours(time.Now(), loc) {
		t.Skipf("test not safe to run during quiet hours in %s", tzName)
	}
}

func TestPolicyAllow_HappyPath(t *testing.T) {
	noonUTCNotInQuiet(t, "UTC")
	p, db, rdb := policyTestEnv(t, 10)
	seedUser(t, db, "alice", nil, "UTC")

	res := p.allow(context.Background(), "alice", "notif.match.invite")
	if !res.Allowed || res.Category != "match_invite" {
		t.Fatalf("first allow: %+v, want allowed=match_invite", res)
	}

	// Sent counter incremented.
	day := time.Now().UTC().Format("2006-01-02")
	sent, _ := rdb.Get(context.Background(), keys.NotifMetricSent("match_invite", day)).Int()
	if sent != 1 {
		t.Errorf("sent counter: got %d, want 1", sent)
	}

	// Daily-cap counter incremented.
	cap, _ := rdb.Get(context.Background(), keys.NotifDailyCap("alice", day)).Int()
	if cap != 1 {
		t.Errorf("cap counter: got %d, want 1", cap)
	}
}

func TestPolicyAllow_MutedCategoryDropped(t *testing.T) {
	noonUTCNotInQuiet(t, "UTC")
	p, db, rdb := policyTestEnv(t, 10)
	seedUser(t, db, "alice", []string{"streak"}, "UTC")

	res := p.allow(context.Background(), "alice", "notif.streak.warning")
	if res.Allowed || res.Reason != "muted" {
		t.Fatalf("got %+v, want dropped/muted", res)
	}
	// Mute drop must NOT consume a daily-cap slot.
	day := time.Now().UTC().Format("2006-01-02")
	cap, _ := rdb.Get(context.Background(), keys.NotifDailyCap("alice", day)).Int()
	if cap != 0 {
		t.Errorf("cap consumed by muted push: got %d, want 0", cap)
	}
	// Dropped(reason="muted") metric incremented.
	dropped, _ := rdb.Get(context.Background(), keys.NotifMetricDropped("streak", "muted", day)).Int()
	if dropped != 1 {
		t.Errorf("dropped(muted) metric: got %d, want 1", dropped)
	}
}

func TestPolicyAllow_QuietHoursDropsAllCategories(t *testing.T) {
	// Force "now" to inside quiet hours by picking a timezone where
	// the user's local clock is currently 02:00. Skip if the math
	// doesn't land us in quiet hours (rare — covers the whole world).
	tz := pickQuietTimezone(t)
	p, db, _ := policyTestEnv(t, 10)
	seedUser(t, db, "alice", nil, tz.String())

	res := p.allow(context.Background(), "alice", "notif.friend.challenge")
	if res.Allowed || res.Reason != "quiet_hours" {
		t.Fatalf("got %+v, want dropped/quiet_hours (tz=%s)", res, tz)
	}
}

// pickQuietTimezone scans IANA candidates and returns one where the
// current local hour falls inside the quiet window. This avoids
// freezing time and keeps the test honest about tz arithmetic.
func pickQuietTimezone(t *testing.T) *time.Location {
	t.Helper()
	candidates := []string{
		"UTC", "Asia/Kolkata", "America/New_York", "America/Los_Angeles",
		"Europe/London", "Asia/Tokyo", "Australia/Sydney", "Pacific/Auckland",
		"Asia/Dubai", "America/Sao_Paulo", "Africa/Nairobi", "Pacific/Honolulu",
	}
	for _, name := range candidates {
		loc, err := time.LoadLocation(name)
		if err != nil {
			continue
		}
		if inQuietHours(time.Now(), loc) {
			return loc
		}
	}
	t.Skipf("no candidate timezone is currently in quiet hours — skipping")
	return nil
}

func TestPolicyAllow_DedupSuppressesRepeat(t *testing.T) {
	noonUTCNotInQuiet(t, "UTC")
	p, db, _ := policyTestEnv(t, 10)
	seedUser(t, db, "alice", nil, "UTC")

	first := p.allow(context.Background(), "alice", "notif.friend.challenge")
	if !first.Allowed {
		t.Fatalf("first allow: %+v", first)
	}
	second := p.allow(context.Background(), "alice", "notif.friend.challenge")
	if second.Allowed || second.Reason != "deduped" {
		t.Fatalf("second allow: %+v, want dropped/deduped", second)
	}
}

func TestPolicyAllow_DailyCapStopsExtras(t *testing.T) {
	noonUTCNotInQuiet(t, "UTC")
	// Use a tiny cap so we don't have to fire 11 events. Use distinct
	// categories so dedup doesn't kick in before the cap.
	p, db, _ := policyTestEnv(t, 3)
	seedUser(t, db, "alice", nil, "UTC")

	allowed := []string{
		"notif.friend.challenge",
		"notif.match.invite",
		"notif.streak.warning",
	}
	for _, e := range allowed {
		res := p.allow(context.Background(), "alice", e)
		if !res.Allowed {
			t.Fatalf("event %q dropped before cap: %+v", e, res)
		}
	}
	res := p.allow(context.Background(), "alice", "notif.daily.reward")
	if res.Allowed || res.Reason != "capped" {
		t.Fatalf("4th event: got %+v, want dropped/capped", res)
	}
}

func TestPolicyAllow_MissingPrefsUsesDefaults(t *testing.T) {
	// User exists but has never set notificationPrefs — the gate must
	// still process them (at default tz, no mutes) rather than fail.
	noonUTCNotInQuiet(t, "Asia/Kolkata")
	p, db, _ := policyTestEnv(t, 10)
	if _, err := db.Collection("users").InsertOne(context.Background(),
		bson.M{"_id": "alice"}); err != nil {
		t.Fatalf("seed bare user: %v", err)
	}
	res := p.allow(context.Background(), "alice", "notif.friend.challenge")
	if !res.Allowed {
		t.Fatalf("got %+v, want allowed (default tz, no mutes)", res)
	}
}
