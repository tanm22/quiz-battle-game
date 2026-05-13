# ADR-0010 — Server-side notification policy gate (quiet hours, daily cap, per-category dedup)

## Status
Accepted — 2026-05-02.

## Context

We send users push notifications for several discrete events: streak warnings, daily reward reminders, tournament countdowns, premium-trial activation, premium-trial expiry, match invites, friend challenges. Each producer fires events into RabbitMQ; a single notification consumer turns them into FCM pushes.

Without policy, a user could receive a streak warning at 03:00 local time, a daily reward push three times in an hour because three producers raced, or 12 pushes in a day because we have many event categories. Push spam is the single fastest way to make a user disable notifications — and once they're off, every other feature that relies on them silently degrades.

We chose to enforce policy on the **server**, not the client:

- **Server-side is the only honest place.** A client-side filter would still pay the FCM delivery cost and still show the system notification before the app dismisses it.
- **Per-user fatigue protection is a product invariant, not a preference.** Quiet hours and the daily cap are not toggleable; only per-category opt-out is.

## Decision

Add a **policy gate** in `services/notification` that every push passes through before FCM dispatch. Implementation lives in `services/notification/policy.go` + `pkg/notif/`. Backed by Redis.

### Gate stages, in order

1. **Per-user opt-out.** If the user has muted this category in `notification_prefs`, drop with reason `muted`.
2. **Quiet hours.** If the current time in the user's timezone is in `[23:00, 08:00)`, drop with reason `quiet_hours`.
3. **Daily cap.** Increment `notif:dailycap:{userId}:{YYYY-MM-DD}` (in user's timezone). If the post-increment value exceeds the cap (default 5), drop with reason `daily_cap`. The 48-hour TTL absorbs timezone drift and clock skew without bothering with timezone-aware key names.
4. **Per-category dedup.** `SETNX notif:dedup:{userId}:{category}` with category-specific TTL. If the key existed, drop with reason `dedup`. Example windows: streak warning 1 h, tournament reminder 5 min, premium expiry 24 h.
5. **Dispatch via FCM** (or stub mode if no service-account JSON).

Each drop increments `notif:metric:dropped:{category}:{reason}:{day}` (7-day TTL) so we can compute drop-rate by reason after the fact.

### Metrics

- `notif:metric:sent:{category}:{day}` — successful dispatches.
- `notif:metric:opened:{category}:{day}` — opens (from `ScoringService.MarkNotificationOpened`, gated by per-user dedup so a misbehaving client can't game the count).
- `notif:metric:dropped:{category}:{reason}:{day}` — drops by reason.

Open rate = `opened / sent`. Drop rate = `dropped / (sent + dropped)`. Both are computable from redis-cli without standing up Prometheus.

### Stub mode

Without `secrets/firebase-admin.json`, `firebase.NewApp` fails at startup and the worker falls back to stub mode (logs only, no FCM traffic). Policy gate and counters still execute, so we can develop and test the policy without a real Firebase setup.

### Why we don't expose quiet hours / cap to the user

Two reasons:

1. **Anti-pattern signal.** A user toggling "disable quiet hours" is a strong signal we'd rather they not — they're about to dislike us. Best to remove the foot-gun.
2. **Universal invariant.** "Don't push during sleep" is true for almost every user. The few who genuinely want pings at 03:00 can mute everything and use in-app activity instead.

Timezone, however, *is* user-configurable, because we can't reliably infer it from the device alone.

## Consequences

### Positive
- Push spam is not possible by accident. Two producers racing on the same category collapse via the SETNX dedup.
- Operators can audit policy effectiveness: "we dropped 23% of tournament reminders to quiet hours yesterday" is one redis-cli call away.
- Adding a new push category means picking a sensible dedup TTL — that's the entire integration. The cap and quiet-hours logic stays untouched.

### Negative
- The cap of 5/day is a product hyperparameter we'll need to revisit with usage data.
- Drops are not retried — if a push hits the cap, the user just doesn't see that event. Acceptable for the categories we have (none of which are critical). A critical category (e.g., security alert) would need to bypass the cap, which we'd implement as a `bypass_cap` flag on the event.
- Per-category dedup TTLs live in code, not config. Lift to a config collection when ops need to tune.

## Alternatives considered

- **Client-side filtering.** Already discussed — too late in the funnel.
- **One dedup window for all categories.** Too crude; streak warnings need a different window than tournament reminders.
- **Per-user cap that respects quota tiers (e.g., premium users get more pushes).** Surprising in the wrong direction — premium shouldn't equal "we bother you more". Rejected.

## References
- `services/notification/policy.go`, `policy_test.go`.
- `pkg/notif/` — shared policy primitives.
- `pkg/keys/keys.go` — `NotifDailyCapKey`, `NotifDedupKey`, `NotifMetricSentKey`, etc.
- `proto/quiz.proto` — `ScoringService.GetNotificationPrefs`, `UpdateNotificationPrefs`, `MarkNotificationOpened`.
- FCM docs on best practices for notification frequency: https://firebase.google.com/docs/cloud-messaging
