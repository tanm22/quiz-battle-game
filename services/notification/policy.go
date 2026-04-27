package main

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"

	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/log"
	"quiz-battle/pkg/models"
	"quiz-battle/pkg/notif"
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
//
// Soft cap: the gate INCRs first and checks second, and a Redis
// failure during the cap check fails open (logs + allows). Under
// concurrent over-cap attempts the counter can therefore reach
// dailyCap+N before a single drop lands; an INCR error during a burst
// can also push past. The trade-off is deliberate — decrementing on
// cap-hit would let tomorrow's first push see N=10 and allow N+1
// pushes after rollover, which is the worse failure mode.
const notifDailyCap = 10

// policy holds the dependencies the gate needs. Constructed once in
// main.go and passed by reference into the dispatch loop. The cap is
// SOFT — see the const above for the exact bound. Categories live in
// pkg/notif so this gate, scoring/notif_prefs.go, and the Flutter
// settings UI can't drift apart.
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
	// Set component=policy on ctx once; every log line in allow,
	// dropped, and loadPrefs (which all receive this ctx) will inherit
	// the attr via FromContext, replacing the per-line `"component",
	// "policy"` repetition that used to appear at every callsite.
	ctx = log.ContextWithAttrs(ctx, "component", "policy")

	category := notif.CategoryFromEvent(event)
	// now is captured in UTC up front so every metric/dedup helper
	// below sees the same day boundary. Per-user daily cap is the only
	// thing that re-projects into the user's local timezone — see the
	// explicit userLocalDay call at gate 4.
	now := time.Now().UTC()
	metricDay := now.Format("2006-01-02") // global metrics: UTC

	prefs := p.loadPrefs(ctx, userID)

	// Gate 1: per-type mute.
	if isMuted(prefs, category) {
		p.dropped(ctx, category, "muted", metricDay)
		return allowResult{Allowed: false, Category: category, Reason: "muted"}
	}

	// Gate 2: quiet hours in the user's local time.
	if inQuietHours(now, prefs.tz) {
		p.dropped(ctx, category, "quiet_hours", metricDay)
		return allowResult{Allowed: false, Category: category, Reason: "quiet_hours"}
	}

	// Gate 3: per-user-per-category dedup. SETNX failure means a recent
	// push of the same category is still inside NotifDedupTTL.
	if category != notif.CategoryOther {
		first, err := keys.TrySetNotifDedup(ctx, p.rdb, userID, category)
		if err != nil {
			// Redis unavailable — fail open rather than drop the push.
			// We'd rather risk a duplicate than swallow a real-time
			// challenge notif because Redis is degraded.
			log.FromContext(ctx).Warn("dedup SETNX failed", "user_id", userID, "category", category, "err", err)
		} else if !first {
			p.dropped(ctx, category, "deduped", metricDay)
			return allowResult{Allowed: false, Category: category, Reason: "deduped"}
		}
	}

	// Gate 4: per-user daily cap. Day bucket is in the user's timezone
	// so the rollover lines up with their midnight, not UTC. This is
	// deliberately different from the metric bucket above: caps are a
	// user-facing fairness guarantee ("no more than 10 today"), so
	// "today" must mean "in your day."
	capDay := userLocalDay(now, prefs.tz)
	count, err := keys.IncrNotifDailyCap(ctx, p.rdb, userID, capDay)
	if err != nil {
		// Same fail-open posture as dedup. Logged so an operator notices.
		log.FromContext(ctx).Warn("daily-cap INCR failed; allowing", "user_id", userID, "err", err)
	} else if count > int64(p.dailyCap) {
		// We've already incremented; don't decrement on cap hit because
		// the next day's first push would otherwise see count=10 and
		// allow N+1 pushes. The bumped counter at the boundary is the
		// safer side of the trade. See newPolicy doc for the soft-cap
		// contract this implies.
		p.dropped(ctx, category, "capped", metricDay)
		return allowResult{Allowed: false, Category: category, Reason: "capped"}
	}

	// Allowed. Bump the global sent counter for offline open-rate math.
	// MUST share the day-bucket convention with MarkNotificationOpened
	// in services/scoring/notif_prefs.go (UTC) — opened/sent ratios
	// across timezone boundaries are otherwise meaningless.
	if err := keys.IncrNotifMetricSent(ctx, p.rdb, category, metricDay); err != nil {
		log.FromContext(ctx).Warn("sent metric INCR failed", "category", category, "err", err)
	}
	return allowResult{Allowed: true, Category: category}
}

func (p *policy) dropped(ctx context.Context, category, reason, metricDay string) {
	if err := keys.IncrNotifMetricDropped(ctx, p.rdb, category, reason, metricDay); err != nil {
		log.FromContext(ctx).Warn("dropped metric INCR failed", "err", err)
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
		log.FromContext(ctx).Warn("load prefs failed; using defaults", "user_id", userID, "err", err)
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
			log.FromContext(ctx).Warn("bad timezone; using default",
				"timezone", doc.Prefs.Timezone, "user_id", userID, "err", err)
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
