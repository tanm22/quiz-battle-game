package main

import (
	"context"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/ratelimit"
	pb "quiz-battle/proto"
)

// Auto-close-round tests. These exercise the per-round answered-set
// bookkeeping that lets SubmitAnswer cancel the deadline timer the
// instant every player has submitted. Reuses attachRedisForMembership
// from room_membership_test.go for the skip-on-no-Redis pattern.

// seedRoom registers `userIDs` as players in `roomID`'s player hash so
// HLEN(Players) returns len(userIDs). The exact JSON payload doesn't
// matter for the early-close path — it only counts members.
func seedRoom(t *testing.T, rdb *redis.Client, roomID string, userIDs ...string) {
	t.Helper()
	for _, uid := range userIDs {
		if err := keys.SetPlayer(context.Background(), rdb, roomID, uid, `{"username":"u","plan":"free"}`); err != nil {
			t.Fatalf("seed player %s: %v", uid, err)
		}
	}
}

// waitForCloseGuard polls the RoundClosed SETNX key for up to `timeout`.
// Used because maybeEarlyCloseRound dispatches closeRound on a goroutine
// — the SETNX inside closeRound is the visible side-effect proving the
// early-close path ran. Returns true if observed within the budget.
func waitForCloseGuard(t *testing.T, rdb *redis.Client, roomID string, round int, timeout time.Duration) bool {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		n, err := rdb.Exists(context.Background(), keys.RoundClosed(roomID, round)).Result()
		if err == nil && n > 0 {
			return true
		}
		time.Sleep(5 * time.Millisecond)
	}
	return false
}

// TestMaybeEarlyCloseRound_AllPlayersAnswered drives the helper twice
// (once per player) and asserts both the answered-set cardinality and
// that closeRound actually fired — the visible side effect is the
// RoundClosed SETNX guard being set.
func TestMaybeEarlyCloseRound_AllPlayersAnswered(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{rdb: rdb}
	const (
		roomID  = "r-early-close-all"
		round   = 1
		playerA = "u-alice"
		playerB = "u-bob"
	)
	seedRoom(t, rdb, roomID, playerA, playerB)

	ctx := context.Background()

	// First player answers — set has 1 of 2 → no early close.
	srv.maybeEarlyCloseRound(ctx, roomID, round, playerA)

	n, err := rdb.SCard(ctx, keys.AnsweredSet(roomID, round)).Result()
	if err != nil {
		t.Fatalf("SCard after first answer: %v", err)
	}
	if n != 1 {
		t.Fatalf("answered set size after one player = %d, want 1", n)
	}

	// Guard must NOT be set yet — closeRound shouldn't have been called.
	exists, _ := rdb.Exists(ctx, keys.RoundClosed(roomID, round)).Result()
	if exists > 0 {
		t.Fatalf("closeRound fired after only one of two answers")
	}

	// Second player answers — set fills, expect early close.
	srv.maybeEarlyCloseRound(ctx, roomID, round, playerB)

	n, err = rdb.SCard(ctx, keys.AnsweredSet(roomID, round)).Result()
	if err != nil {
		t.Fatalf("SCard after second answer: %v", err)
	}
	if n != 2 {
		t.Fatalf("answered set size after two players = %d, want 2", n)
	}

	if !waitForCloseGuard(t, rdb, roomID, round, time.Second) {
		t.Fatalf("expected closeRound to have set RoundClosed guard within 1s")
	}
}

// TestMaybeEarlyCloseRound_PartialAnswerKeepsTimer asserts the early-
// close path stays dormant when only some players have answered — the
// 15s deadline timer (set in startRound) remains the round's only
// close trigger.
func TestMaybeEarlyCloseRound_PartialAnswerKeepsTimer(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{rdb: rdb}
	const (
		roomID  = "r-early-close-partial"
		round   = 1
		playerA = "u-alice"
		playerB = "u-bob"
	)
	seedRoom(t, rdb, roomID, playerA, playerB)

	ctx := context.Background()
	srv.maybeEarlyCloseRound(ctx, roomID, round, playerA)

	n, err := rdb.SCard(ctx, keys.AnsweredSet(roomID, round)).Result()
	if err != nil {
		t.Fatalf("SCard: %v", err)
	}
	if n != 1 {
		t.Fatalf("answered set size = %d, want 1 (only one player answered)", n)
	}

	// Give any errant goroutine a tick to misbehave — the assertion
	// is that NO close happened, so we want a small grace period to
	// catch a stray closeRound spawn instead of asserting immediately.
	time.Sleep(50 * time.Millisecond)
	exists, _ := rdb.Exists(ctx, keys.RoundClosed(roomID, round)).Result()
	if exists > 0 {
		t.Fatalf("closeRound fired on partial-answer set; should wait for timer")
	}
}

// TestMaybeEarlyCloseRound_TTLRefreshOnNewAddition asserts the per-
// round answered-set carries a TTL the moment the first member lands
// (mirrors keys.TrySetAnswer's pattern) so a long-running room can't
// leak per-round keys past RoomTTL.
func TestMaybeEarlyCloseRound_TTLRefreshOnNewAddition(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{rdb: rdb}
	const (
		roomID  = "r-early-close-ttl"
		round   = 1
		playerA = "u-alice"
	)
	seedRoom(t, rdb, roomID, playerA, "u-second-for-headroom")

	ctx := context.Background()
	srv.maybeEarlyCloseRound(ctx, roomID, round, playerA)

	ttl, err := rdb.TTL(ctx, keys.AnsweredSet(roomID, round)).Result()
	if err != nil {
		t.Fatalf("TTL: %v", err)
	}
	if ttl <= 0 {
		t.Fatalf("answered set has no TTL after first add; got %v", ttl)
	}
	if ttl > keys.RoomTTL {
		t.Fatalf("answered set TTL %v exceeds RoomTTL %v", ttl, keys.RoomTTL)
	}
}

// TestMaybeEarlyCloseRound_NoPlayersIsNoOp guards the empty-room edge:
// HLEN(Players) == 0 means the room hash never existed or expired.
// In that case the helper must not invoke closeRound — otherwise a
// stray SubmitAnswer past the membership gate could close a phantom
// round in a half-dismantled match.
func TestMaybeEarlyCloseRound_NoPlayersIsNoOp(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{rdb: rdb}
	const (
		roomID = "r-early-close-empty"
		round  = 1
		ghost  = "u-ghost"
	)
	// Intentionally do not seed the room.

	ctx := context.Background()
	srv.maybeEarlyCloseRound(ctx, roomID, round, ghost)

	time.Sleep(50 * time.Millisecond)
	exists, _ := rdb.Exists(ctx, keys.RoundClosed(roomID, round)).Result()
	if exists > 0 {
		t.Fatalf("closeRound fired against a room with no players hash")
	}
}

// TestSubmitAnswer_EarlyCloseEndToEnd drives the full RPC for both
// players and confirms the early-close path is wired in. Without this
// test, a refactor that drops the maybeEarlyCloseRound call from
// SubmitAnswer would still pass the helper-level tests above. The
// nil amqpCh path in publish() makes this work without RabbitMQ.
func TestSubmitAnswer_EarlyCloseEndToEnd(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{
		rdb:           rdb,
		answerLimiter: ratelimit.New(rdb, "submit_answer_test_early", 60, time.Minute),
	}
	const (
		roomID  = "r-rpc-early-close"
		round   = 1
		playerA = "u-alice-rpc"
		playerB = "u-bob-rpc"
	)
	seedRoom(t, rdb, roomID, playerA, playerB)

	mkCtx := func(uid string) context.Context {
		return auth.ContextWithClaims(context.Background(),
			&auth.Claims{UserID: uid, Username: uid})
	}

	req := &pb.SubmitAnswerRequest{RoomId: roomID, Round: int32(round), OptionIndex: 0}

	if _, err := srv.SubmitAnswer(mkCtx(playerA), req); err != nil {
		t.Fatalf("playerA SubmitAnswer: %v", err)
	}
	exists, _ := rdb.Exists(context.Background(), keys.RoundClosed(roomID, round)).Result()
	if exists > 0 {
		t.Fatalf("round closed after only first SubmitAnswer")
	}

	if _, err := srv.SubmitAnswer(mkCtx(playerB), req); err != nil {
		t.Fatalf("playerB SubmitAnswer: %v", err)
	}
	if !waitForCloseGuard(t, rdb, roomID, round, time.Second) {
		t.Fatalf("RoundClosed guard not set within 1s after second SubmitAnswer")
	}
}
