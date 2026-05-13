package keys

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
)

// testRedis dials a local redis on DB 13 (reserved for quota tests) so a
// FlushDB at setup doesn't nuke a co-tenant's keys. Mirrors the pattern
// in pkg/ratelimit so a single Redis instance can host both suites.
func testRedis(t *testing.T) *redis.Client {
	t.Helper()
	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		addr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: addr, DB: 13})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		t.Skipf("redis ping: %v", err)
	}
	if err := rdb.FlushDB(context.Background()).Err(); err != nil {
		t.Fatalf("flushdb: %v", err)
	}
	t.Cleanup(func() { _ = rdb.Close() })
	return rdb
}

// TestCheckQuota_AllowsUpToLimit covers the §4 free-tier guarantee: the
// first N calls in a window must all succeed, where N is the configured
// daily limit.
func TestCheckQuota_AllowsUpToLimit(t *testing.T) {
	rdb := testRedis(t)
	ctx := context.Background()
	const limit = 5
	for i := 1; i <= limit; i++ {
		ok, err := CheckQuota(ctx, rdb, "alice", limit)
		if err != nil {
			t.Fatalf("call %d: %v", i, err)
		}
		if !ok {
			t.Fatalf("call %d denied; should be under the cap", i)
		}
	}
	used, _ := GetQuotaUsed(ctx, rdb, "alice")
	if used != int64(limit) {
		t.Errorf("GetQuotaUsed = %d, want %d", used, limit)
	}
}

// TestCheckQuota_DeniesPastLimit guarantees the (N+1)th call returns
// false AND the underlying counter doesn't drift past the limit — the
// Lua script DECRs on the over-quota branch so the visible "used"
// matches the cap, not cap+1.
func TestCheckQuota_DeniesPastLimit(t *testing.T) {
	rdb := testRedis(t)
	ctx := context.Background()
	const limit = 3
	for i := 0; i < limit; i++ {
		_, _ = CheckQuota(ctx, rdb, "bob", limit)
	}
	ok, err := CheckQuota(ctx, rdb, "bob", limit)
	if err != nil {
		t.Fatalf("over-cap call: %v", err)
	}
	if ok {
		t.Errorf("call %d allowed; should be over the cap", limit+1)
	}
	// Visible counter must be exactly limit (Lua DECRs on the deny
	// branch so a denied call doesn't leak quota).
	used, _ := GetQuotaUsed(ctx, rdb, "bob")
	if used != int64(limit) {
		t.Errorf("GetQuotaUsed after deny = %d, want %d (DECR-on-deny invariant)", used, limit)
	}
}

// TestCheckQuota_PerUserIsolation — alice burning her quota must not
// affect bob. Same daily-limit pool, distinct keys.
func TestCheckQuota_PerUserIsolation(t *testing.T) {
	rdb := testRedis(t)
	ctx := context.Background()
	const limit = 2
	_, _ = CheckQuota(ctx, rdb, "alice", limit)
	_, _ = CheckQuota(ctx, rdb, "alice", limit)
	denied, _ := CheckQuota(ctx, rdb, "alice", limit)
	if denied {
		t.Errorf("alice should be over cap after 2 calls (limit=2)")
	}
	// Bob's first call must still succeed.
	ok, _ := CheckQuota(ctx, rdb, "bob", limit)
	if !ok {
		t.Errorf("bob's first call denied; alice's quota shouldn't bleed into bob's bucket")
	}
}

// TestRefundQuota_ReversesPriorCheck — when a user joins matchmaking
// and bails before a match starts, RefundQuota must give the slot back
// so the next legitimate Play action succeeds.
func TestRefundQuota_ReversesPriorCheck(t *testing.T) {
	rdb := testRedis(t)
	ctx := context.Background()
	const limit = 1

	// Burn the only slot.
	ok, _ := CheckQuota(ctx, rdb, "carol", limit)
	if !ok {
		t.Fatalf("first call should succeed")
	}
	// Next call denied — quota at cap.
	denied, _ := CheckQuota(ctx, rdb, "carol", limit)
	if denied {
		t.Fatalf("second call should be denied")
	}
	// Refund the original INCR.
	refunded, err := RefundQuota(ctx, rdb, "carol")
	if err != nil {
		t.Fatalf("refund: %v", err)
	}
	if !refunded {
		t.Errorf("RefundQuota = false; expected true (counter was at 1)")
	}
	// Now another Play succeeds.
	again, _ := CheckQuota(ctx, rdb, "carol", limit)
	if !again {
		t.Errorf("post-refund call denied; refund didn't restore the slot")
	}
}

// TestRefundQuota_NoUnderflow — RefundQuota on a fresh key (key
// missing, or counter already at 0 because EXPIREAT fired and the slot
// was reset) must be a no-op. Without the Lua guard, a stray refund
// after IST-midnight reset would produce a negative counter and effect-
// ively grant an extra match the next day.
func TestRefundQuota_NoUnderflow(t *testing.T) {
	rdb := testRedis(t)
	ctx := context.Background()

	// User has never played today: key doesn't exist.
	refunded, err := RefundQuota(ctx, rdb, "dave")
	if err != nil {
		t.Fatalf("refund on missing key: %v", err)
	}
	if refunded {
		t.Errorf("RefundQuota = true on missing key; expected false (no-op)")
	}
	used, _ := GetQuotaUsed(ctx, rdb, "dave")
	if used != 0 {
		t.Errorf("counter = %d after refund-on-missing; want 0 (no underflow)", used)
	}

	// Counter at zero: also a no-op.
	rdb.Set(ctx, DailyQuota("eve"), "0", time.Hour)
	refunded, _ = RefundQuota(ctx, rdb, "eve")
	if refunded {
		t.Errorf("RefundQuota = true on zero counter; expected false")
	}
}

// TestISTMidnightUnix_AlwaysFuture — the EXPIREAT timestamp the Lua
// script uses must always be strictly in the future, otherwise Redis
// would expire the key immediately and the quota would visibly reset
// to 0 inside the same window. A bug here would mean a free user can
// retry their quiz immediately after being denied.
func TestISTMidnightUnix_AlwaysFuture(t *testing.T) {
	got := ISTMidnightUnix()
	now := time.Now().Unix()
	if got <= now {
		t.Errorf("ISTMidnightUnix() = %d, now = %d; want strictly future", got, now)
	}
	// Sanity: ceiling at 24 hours + 1 hour buffer (the call right after
	// IST midnight should produce a timestamp ~24h away, never longer).
	const maxAhead = 25 * 3600
	if got-now > maxAhead {
		t.Errorf("ISTMidnightUnix() = %d is more than 25h ahead of now (%d)", got, now)
	}
}
