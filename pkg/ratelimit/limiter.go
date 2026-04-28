// Package ratelimit provides a per-name fixed-window rate limiter backed
// by Redis INCR + ExpireNX. Used to slow brute-force login attempts,
// referral-code apply spam, payment retries, and answer-submission
// floods (problem-03 §4.7 item 4).
//
// Design choice: fixed-window over token-bucket. Fixed-window is one
// INCR + one ExpireNX per call (cheap, atomic), produces one key per
// (name, subject, window) — bounded cardinality — and is correct
// enough for "block obvious abuse." Token bucket would smooth bursts
// at the window boundary but adds the complexity of tracking last-
// fill time per subject; the fixed-window's worst-case burst is 2N
// requests in two adjacent windows, which is acceptable for the
// targeted abuse cases (login, referral, payment, answer submit).
package ratelimit

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"

	"quiz-battle/pkg/log"
)

// Limiter rate-limits (name, subject) tuples to limit requests per
// window. Subject is whatever string the caller chooses — userID for
// authenticated rate limits, username for login (where the caller
// isn't yet authenticated), peer IP for per-source limits, etc.
type Limiter struct {
	rdb    *redis.Client
	name   string
	limit  int
	window time.Duration
}

// New constructs a Limiter. limit and window must both be > 0; New
// will not panic on invalid values but Allow will refuse to limit if
// they're <= 0 (returns true so the caller's traffic isn't accidentally
// blocked by a zero-config limiter).
func New(rdb *redis.Client, name string, limit int, window time.Duration) *Limiter {
	return &Limiter{rdb: rdb, name: name, limit: limit, window: window}
}

// Allow returns true if the (name, subject) tuple is under the limit
// in the current window, false otherwise. The counter is incremented
// regardless of the return value — a denied call still consumes a
// slot, which means a steady stream of attempts past the limit cannot
// "queue up" for next-window approval. That matches operator intent
// for brute-force-style abuse.
//
// Failure mode: on Redis error (connection drop, timeout), returns
// true with the underlying error. Rate limiting is a best-effort
// abuse mitigation — failing closed would make a brief Redis blip
// take down the whole login surface, which is worse than letting the
// abuser through for those few seconds. Caller should log the error
// at WARN but not fail the user-facing operation.
func (l *Limiter) Allow(ctx context.Context, subject string) (bool, error) {
	if l == nil || l.limit <= 0 || l.window <= 0 {
		return true, nil
	}
	if subject == "" {
		// Empty subject would collapse every caller onto the same key.
		// That's almost always a programming bug — refuse to limit
		// rather than accidentally rate-limit the entire user base.
		return true, nil
	}

	// Fixed window: bucket = floor(now / window). Same window for the
	// duration of l.window, then rolls forward. UnixNano / Nanoseconds
	// (not Unix / Seconds) so any positive window is safe — Seconds()
	// truncates a sub-1s duration to 0 and the divide would panic.
	windowStart := time.Now().UnixNano() / l.window.Nanoseconds()
	key := fmt.Sprintf("ratelimit:%s:%s:%d", l.name, subject, windowStart)

	pipe := l.rdb.TxPipeline()
	incr := pipe.Incr(ctx, key)
	// ExpireNX (Redis 7+) sets TTL only on the first call of the
	// window — subsequent calls don't reset it. The +1s cushion
	// absorbs clock skew between the limiter and Redis.
	pipe.ExpireNX(ctx, key, l.window+time.Second)
	if _, err := pipe.Exec(ctx); err != nil {
		return true, err
	}
	return incr.Val() <= int64(l.limit), nil
}

// AllowWithLog wraps Allow + logs the Redis-error path at WARN.
// Convenience for callers that want fail-open behaviour without
// having to pattern-match on the error themselves.
func (l *Limiter) AllowWithLog(ctx context.Context, subject string) bool {
	allowed, err := l.Allow(ctx, subject)
	if err != nil {
		log.FromContext(ctx).Warn("ratelimit redis failed; failing open",
			"name", l.name, "subject", subject, "err", err)
	}
	return allowed
}
