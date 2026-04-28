package ratelimit

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
)

// testRedis dials the local redis on DB 14 (reserved for ratelimit
// tests) so the FlushDB at setup doesn't nuke a co-tenant's keys.
func testRedis(t *testing.T) *redis.Client {
	t.Helper()
	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		addr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: addr, DB: 14})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		t.Skipf("redis ping: %v", err)
	}
	if err := rdb.FlushDB(context.Background()).Err(); err != nil {
		t.Fatalf("flushdb: %v", err)
	}
	t.Cleanup(func() { _ = rdb.Close() })
	return rdb
}

func TestAllow_BelowLimit(t *testing.T) {
	rdb := testRedis(t)
	l := New(rdb, "test_below", 5, time.Minute)
	for i := 0; i < 5; i++ {
		ok, err := l.Allow(context.Background(), "alice")
		if err != nil {
			t.Fatalf("call %d err: %v", i, err)
		}
		if !ok {
			t.Errorf("call %d denied; should be under limit", i)
		}
	}
}

func TestAllow_DeniesPastLimit(t *testing.T) {
	rdb := testRedis(t)
	l := New(rdb, "test_past", 3, time.Minute)
	for i := 0; i < 3; i++ {
		_, _ = l.Allow(context.Background(), "alice")
	}
	ok, _ := l.Allow(context.Background(), "alice")
	if ok {
		t.Errorf("4th call should be denied (limit=3)")
	}
}

func TestAllow_PerSubjectIsolation(t *testing.T) {
	// Alice burning her quota must not affect Bob — same name, distinct
	// subjects map to distinct keys.
	rdb := testRedis(t)
	l := New(rdb, "test_iso", 2, time.Minute)
	_, _ = l.Allow(context.Background(), "alice")
	_, _ = l.Allow(context.Background(), "alice")
	if ok, _ := l.Allow(context.Background(), "alice"); ok {
		t.Error("alice should be denied at 3rd call")
	}
	if ok, _ := l.Allow(context.Background(), "bob"); !ok {
		t.Error("bob should be allowed; alice's quota shouldn't bleed")
	}
}

func TestAllow_PerNameIsolation(t *testing.T) {
	// Login limit and referral limit are separate concerns — same user
	// hitting both shouldn't share a counter.
	rdb := testRedis(t)
	loginLim := New(rdb, "login", 1, time.Minute)
	refLim := New(rdb, "referral_apply", 1, time.Minute)
	_, _ = loginLim.Allow(context.Background(), "alice")
	if ok, _ := refLim.Allow(context.Background(), "alice"); !ok {
		t.Error("referral limiter shouldn't see login's count")
	}
}

func TestAllow_DeniedCallStillIncrements(t *testing.T) {
	// A flood past the limit must not be able to "queue up" for the
	// next window — denied calls still increment so the steady-state
	// flood remains denied.
	rdb := testRedis(t)
	l := New(rdb, "test_denied_inc", 2, time.Minute)
	for i := 0; i < 5; i++ {
		_, _ = l.Allow(context.Background(), "alice")
	}
	// 5 calls fired, only 2 allowed. The counter is now at 5.
	// A 6th call must still be denied.
	if ok, _ := l.Allow(context.Background(), "alice"); ok {
		t.Error("6th call should still be denied")
	}
}

func TestAllow_WindowRollover(t *testing.T) {
	// Use a 1-second window so the test rolls within a reasonable time.
	// After the window passes, the counter resets and the user is
	// allowed again. This is the property that brute-force protection
	// relies on — the gate eventually opens for legitimate users.
	rdb := testRedis(t)
	l := New(rdb, "test_rollover", 1, 1*time.Second)
	if ok, _ := l.Allow(context.Background(), "alice"); !ok {
		t.Fatal("first call should be allowed")
	}
	if ok, _ := l.Allow(context.Background(), "alice"); ok {
		t.Fatal("second call within window should be denied")
	}
	// Wait for the window to roll over. 1.2s gives a small cushion past
	// the 1s window without being slow enough to bother CI.
	time.Sleep(1200 * time.Millisecond)
	if ok, _ := l.Allow(context.Background(), "alice"); !ok {
		t.Error("call after window rollover should be allowed")
	}
}

func TestAllow_NilOrZeroLimitIsPassthrough(t *testing.T) {
	// A misconfigured limiter (nil, zero limit, zero window) must not
	// accidentally block traffic. Default to allow.
	var nilL *Limiter
	if ok, _ := nilL.Allow(context.Background(), "alice"); !ok {
		t.Error("nil limiter should pass through")
	}
	rdb := testRedis(t)
	zeroLim := New(rdb, "test_zero", 0, time.Minute)
	if ok, _ := zeroLim.Allow(context.Background(), "alice"); !ok {
		t.Error("zero-limit limiter should pass through")
	}
	zeroWin := New(rdb, "test_zerowin", 5, 0)
	if ok, _ := zeroWin.Allow(context.Background(), "alice"); !ok {
		t.Error("zero-window limiter should pass through")
	}
}

func TestAllow_EmptySubjectIsPassthrough(t *testing.T) {
	// Empty subject would collapse every caller onto the same key —
	// almost always a programming bug, refuse to limit rather than
	// rate-limit the entire user base by accident.
	rdb := testRedis(t)
	l := New(rdb, "test_empty", 1, time.Minute)
	for i := 0; i < 5; i++ {
		if ok, _ := l.Allow(context.Background(), ""); !ok {
			t.Errorf("empty subject call %d should pass through", i)
		}
	}
}

func TestAllow_RedisErrorFailsOpen(t *testing.T) {
	// Documented contract (limiter.go L52–L57): on Redis error, return
	// (true, err) — failing CLOSED would let a brief Redis blip take
	// down login. Pin it with a test so a future refactor can't silently
	// flip the polarity. Dial a port nothing is listening on; the
	// short timeout keeps the test under a second.
	rdb := redis.NewClient(&redis.Options{
		Addr:        "127.0.0.1:1",
		DialTimeout: 200 * time.Millisecond,
	})
	t.Cleanup(func() { _ = rdb.Close() })

	l := New(rdb, "test_fail_open", 1, time.Minute)
	ok, err := l.Allow(context.Background(), "alice")
	if err == nil {
		t.Fatal("expected redis error, got nil")
	}
	if !ok {
		t.Error("limiter must fail open on Redis error; got denied")
	}
}
