package main

import (
	"context"
	"log"
	"time"

	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"

	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/models"
)

// §4.6 Notification policy
//
// A push goes through four gates in this order:
//
//   1. Per-user mute       — user toggled this category off in settings
//   2. Quiet hours         — 23:00–08:00 in the user's local timezone
//   3. Per-category dedup  — same category fired in the last NotifDedupTTL
//   4. Per-user daily cap  — already hit notifDailyCap pushes today
//
// Gates short-circuit on the first miss. Each drop bumps a per-reason
// counter so operators can watch policy effectiveness offline.
//
// "Allow" still does NOT send anything — the caller is responsible
// for the FCM dispatch. That decoupling keeps the gate testable
// without standing up Firebase.

// Quiet hours are product-wide: not exposed in the user settings RPC.
// 23:00–08:00 is a wide enough sleep window for most users; making it
// per-user would let an individual user opt out of fatigue protection,
// which is exactly what §4.6 is trying to prevent.
const (
	quietHourStart = 23 // inclusive: 23:00 → 23:59 quiet
	quietHourEnd   = 8  // exclusive: 00:00 → 07:59 quiet, 08:00 OK
)

// notifDailyCap is the per-user push ceiling. 10 is a soft guess —
// streak warnings + tournament reminders + match invites + premium
// notices over a single day shouldn't realistically hit this. Override
// at startup via NOTIF_DAILY_CAP env var so we don't have to redeploy
// to relax or tighten the gate.
const notifDailyCap = 10

// categoryFromEvent maps a RabbitMQ event string (the value of the
// "event" field in the payload, which mirrors the routing key) to a
// notification category. The category is what users mute and what the
// dedup/cap counters key off.
//
// An unknown event resolves to "other". The policy gate still runs for
// "other" — quiet hours and the daily cap apply — but mute and dedup
// don't have a meaningful category to key off, so unknown events
// effectively bypass those two gates.
func categoryFromEvent(event string) string {
	switch event {
	case "notif.friend.request_received", "notif.friend.request_accepted":
		return "friend_request"
	case "notif.friend.challenge":
		return "friend_challenge"
	case "notif.match.invite":
		return "match_invite"
	case "notif.streak.warning":
		return "streak"
	case "notif.daily.reward":
		return "daily_reward"
	case "notif.referral.converted":
		return "referral"
	case "notif.tournament.remind",
		"notif.tournament.finished",
		"notif.tournament.rank_changed":
		return "tournament"
	case "notif.premium.activated",
		"notif.premium.expired",
		"premium.expired",
		"notif.premium.expiry":
		return "premium"
	}
	return "other"
}

// policy holds the dependencies the gate needs. Constructed once in
// main.go and passed by reference into the dispatch loop.
type policy struct {
	rdb     *redis.Client
	mongoDB *mongo.Database
	// Configurable overrides — populated from env at startup so tests
	// can shorten the daily cap without touching the const.
	dailyCap int
}

func newPolicy(rdb *redis.Client, mongoDB *mongo.Database, dailyCap int) *policy {
	if dailyCap <= 0 {
		dailyCap = notifDailyCap
	}
	return &policy{rdb: rdb, mongoDB: mongoDB, dailyCap: dailyCap}
}

// allowResult is what the gate returns. Allowed=true means dispatch;
// false means drop and the Reason is one of the dropped-counter labels.
type allowResult struct {
	Allowed  bool
	Category string
	Reason   string // "muted" | "quiet_hours" | "deduped" | "capped" | "" when allowed
}

// allow runs all four gates against a single (userId, event) pair and
// returns whether the push should proceed. Side effects on every call:
//   - sent metric is incremented when allowed
//   - dropped(reason) metric is incremented when not allowed
//   - dedup key is set when allowed
//   - daily-cap counter is incremented when allowed
//
// Note the order: dedup runs BEFORE the cap so a deduped event doesn't
// burn one of the user's 10 daily slots. The cap is the last gate so
// every counted push is actually dispatched.
func (p *policy) allow(ctx context.Context, userID, event string) allowResult {
	category := categoryFromEvent(event)
	now := time.Now().UTC()

	prefs := p.loadPrefs(ctx, userID)

	// Gate 1: per-type mute.
	if isMuted(prefs, category) {
		p.dropped(ctx, category, "muted", now)
		return allowResult{Allowed: false, Category: category, Reason: "muted"}
	}

	// Gate 2: quiet hours in the user's local time.
	if inQuietHours(now, prefs.tz) {
		p.dropped(ctx, category, "quiet_hours", now)
		return allowResult{Allowed: false, Category: category, Reason: "quiet_hours"}
	}

	// Gate 3: per-user-per-category dedup. SETNX failure means a recent
	// push of the same category is still inside NotifDedupTTL.
	if category != "other" {
		first, err := keys.TrySetNotifDedup(ctx, p.rdb, userID, category)
		if err != nil {
			// Redis unavailable — fail open rather than drop the push.
			// We'd rather risk a duplicate than swallow a real-time
			// challenge notif because Redis is degraded.
			log.Printf("[notif-policy] dedup SETNX failed for user=%s category=%s: %v", userID, category, err)
		} else if !first {
			p.dropped(ctx, category, "deduped", now)
			return allowResult{Allowed: false, Category: category, Reason: "deduped"}
		}
	}

	// Gate 4: per-user daily cap. Day bucket is in the user's timezone
	// so the rollover lines up with their midnight, not UTC.
	day := userLocalDay(now, prefs.tz)
	count, err := keys.IncrNotifDailyCap(ctx, p.rdb, userID, day)
	if err != nil {
		// Same fail-open posture as dedup. Logged so an operator notices.
		log.Printf("[notif-policy] daily-cap INCR failed for user=%s: %v — allowing", userID, err)
	} else if count > int64(p.dailyCap) {
		// We've already incremented; don't decrement on cap hit because
		// the next day's first push would otherwise see count=10 and
		// allow N+1 pushes. The bumped counter at the boundary is the
		// safer side of the trade.
		p.dropped(ctx, category, "capped", now)
		return allowResult{Allowed: false, Category: category, Reason: "capped"}
	}

	// Allowed. Bump the global sent counter for offline open-rate math.
	if err := keys.IncrNotifMetricSent(ctx, p.rdb, category, now.Format("2006-01-02")); err != nil {
		log.Printf("[notif-policy] sent metric INCR failed for category=%s: %v", category, err)
	}
	return allowResult{Allowed: true, Category: category}
}

func (p *policy) dropped(ctx context.Context, category, reason string, now time.Time) {
	if err := keys.IncrNotifMetricDropped(ctx, p.rdb, category, reason, now.Format("2006-01-02")); err != nil {
		log.Printf("[notif-policy] dropped metric INCR failed: %v", err)
	}
}

// userPrefs is the policy gate's internal view of a user's settings.
// Carries the *resolved* timezone (a *time.Location) rather than the
// stored IANA string so each allow() call doesn't re-parse it.
type userPrefs struct {
	mutedTypes []string
	tz         *time.Location
}

func (p *policy) loadPrefs(ctx context.Context, userID string) userPrefs {
	defaults := userPrefs{tz: defaultNotifLocation()}

	var doc struct {
		Prefs *models.NotificationPrefs `bson:"notificationPrefs"`
	}
	if err := p.mongoDB.Collection("users").
		FindOne(ctx, bson.M{"_id": userID}).Decode(&doc); err != nil {
		// Missing user shouldn't normally happen — the consumer wouldn't
		// have a userId in the payload otherwise — but if it does, fall
		// through to defaults rather than fail the dispatch.
		log.Printf("[notif-policy] load prefs for user=%s failed: %v — using defaults", userID, err)
		return defaults
	}
	if doc.Prefs == nil {
		return defaults
	}
	out := userPrefs{mutedTypes: doc.Prefs.MutedTypes, tz: defaults.tz}
	if doc.Prefs.Timezone != "" {
		if loc, err := time.LoadLocation(doc.Prefs.Timezone); err == nil {
			out.tz = loc
		} else {
			log.Printf("[notif-policy] bad timezone %q on user=%s: %v — using default",
				doc.Prefs.Timezone, userID, err)
		}
	}
	return out
}

// defaultNotifLocation is "Asia/Kolkata" with a UTC fallback. Matches
// scoring/notif_prefs.go's default — kept consistent so a user who
// hasn't set a timezone gets the same quiet-hours window in both
// services.
func defaultNotifLocation() *time.Location {
	if loc, err := time.LoadLocation("Asia/Kolkata"); err == nil {
		return loc
	}
	return time.UTC
}

func isMuted(prefs userPrefs, category string) bool {
	for _, m := range prefs.mutedTypes {
		if m == category {
			return true
		}
	}
	return false
}

// inQuietHours returns true when `now` (in the user's tz) is inside the
// 23:00–08:00 window. The window straddles midnight, so an OR check
// on the two halves is the simplest form.
func inQuietHours(now time.Time, tz *time.Location) bool {
	if tz == nil {
		tz = time.UTC
	}
	h := now.In(tz).Hour()
	return h >= quietHourStart || h < quietHourEnd
}

// userLocalDay formats the user's local day so the daily-cap counter
// rolls over at their midnight. Without the timezone shift, a user in
// IST would see the cap reset at 5:30 AM their time.
func userLocalDay(now time.Time, tz *time.Location) string {
	if tz == nil {
		tz = time.UTC
	}
	return now.In(tz).Format("2006-01-02")
}
