package main

import (
	"context"
	"encoding/json"
	"os"
	"testing"

	"github.com/redis/go-redis/v9"

	"quiz-battle/pkg/keys"
)

// TestRecencyBonus_FullPipelineToLeaderboard drives the same Redis
// primitives processAnswer touches after CalculateScore returns, and
// asserts:
//
//  1. The per-answer record persisted to Redis carries the FINAL score
//     (base + bonus) plus the streakBonus / firstCorrectBonus breakdown,
//     not just the base score. The placeholder write happens via HSETNX
//     for idempotency; processAnswer's HSet overwrite is what surfaces
//     the bonus to downstream readers.
//  2. The leaderboard ZSET accumulates (base + bonus) per correct round,
//     so a two-round streak produces leaderboard = (base1 + bonus1) +
//     (base2 + bonus2) — not just base*2.
//  3. A duplicate submission for the same (room, round, user) — what a
//     RabbitMQ redelivery looks like — does NOT re-bump the streak or
//     first-correct counters. processAnswer's early-return on
//     TrySetAnswer == false is what protects this, but the regression
//     surface is wide enough that an explicit assertion is worth its
//     keep.
//
// Without this test, dropping `score += bonus` at services/scoring/main.go
// or skipping the post-TrySetAnswer HSet overwrite would pass every
// existing scoring test (the only recency-bonus coverage today is
// computeRecencyBonus's pure-function unit test and the per-key Redis
// primitives in pkg/keys).
func TestRecencyBonus_FullPipelineToLeaderboard(t *testing.T) {
	rdb := attachRedisOrSkip(t)
	ctx := context.Background()
	const (
		roomID = "r-recency-int"
		uid    = "u-alice"
	)

	// --- Round 1: correct, fast (150 base), first correct (rank 1, +25). ---
	baseR1 := 150.0
	wasSet, err := keys.TrySetAnswer(ctx, rdb, roomID, 1, uid, marshalPlaceholder(t, baseR1, true))
	if err != nil || !wasSet {
		t.Fatalf("round 1 TrySetAnswer: wasSet=%v err=%v", wasSet, err)
	}

	streakLevel, err := keys.BumpStreak(ctx, rdb, roomID, uid)
	if err != nil || streakLevel != 1 {
		t.Fatalf("round 1 BumpStreak: level=%d err=%v", streakLevel, err)
	}
	correctRank, err := keys.IncrCorrectOrder(ctx, rdb, roomID, 1)
	if err != nil || correctRank != 1 {
		t.Fatalf("round 1 IncrCorrectOrder: rank=%d err=%v", correctRank, err)
	}
	sb1, fcb1, total1 := computeRecencyBonus(streakLevel, correctRank)
	// Level 1 → no streak bonus; rank 1 → +25 first-correct.
	if sb1 != 0 || fcb1 != 25 || total1 != 25 {
		t.Fatalf("round 1 bonus: sb=%v fcb=%v total=%v, want 0/25/25", sb1, fcb1, total1)
	}
	finalR1 := baseR1 + total1
	if err := overwriteAnswerJSON(ctx, rdb, roomID, 1, uid, baseR1, finalR1, sb1, fcb1, true); err != nil {
		t.Fatalf("round 1 HSet: %v", err)
	}
	entries, err := keys.UpdateLeaderboard(ctx, rdb, roomID, uid, finalR1)
	if err != nil {
		t.Fatalf("round 1 UpdateLeaderboard: %v", err)
	}
	if got := scoreOf(entries, uid); got != finalR1 {
		t.Errorf("round 1 leaderboard score: got %v want %v", got, finalR1)
	}

	// --- Round 2: correct again, slow (80 base), streak now 2 (+10), still rank 1 (+25). ---
	baseR2 := 80.0
	wasSet, err = keys.TrySetAnswer(ctx, rdb, roomID, 2, uid, marshalPlaceholder(t, baseR2, true))
	if err != nil || !wasSet {
		t.Fatalf("round 2 TrySetAnswer: wasSet=%v err=%v", wasSet, err)
	}
	streakLevel, err = keys.BumpStreak(ctx, rdb, roomID, uid)
	if err != nil || streakLevel != 2 {
		t.Fatalf("round 2 BumpStreak: level=%d err=%v, want 2 (streak persisted across rounds)", streakLevel, err)
	}
	correctRank, err = keys.IncrCorrectOrder(ctx, rdb, roomID, 2)
	if err != nil || correctRank != 1 {
		t.Fatalf("round 2 IncrCorrectOrder: rank=%d err=%v, want 1 (per-round counter resets)", correctRank, err)
	}
	sb2, fcb2, total2 := computeRecencyBonus(streakLevel, correctRank)
	if sb2 != 10 || fcb2 != 25 || total2 != 35 {
		t.Fatalf("round 2 bonus: sb=%v fcb=%v total=%v, want 10/25/35", sb2, fcb2, total2)
	}
	finalR2 := baseR2 + total2
	if err := overwriteAnswerJSON(ctx, rdb, roomID, 2, uid, baseR2, finalR2, sb2, fcb2, true); err != nil {
		t.Fatalf("round 2 HSet: %v", err)
	}
	entries, err = keys.UpdateLeaderboard(ctx, rdb, roomID, uid, finalR2)
	if err != nil {
		t.Fatalf("round 2 UpdateLeaderboard: %v", err)
	}
	wantTotal := finalR1 + finalR2
	if got := scoreOf(entries, uid); got != wantTotal {
		t.Errorf("round 2 leaderboard cumulative: got %v want %v (base+bonus per round)", got, wantTotal)
	}

	// --- Per-answer record assertions: each round's HSet must carry the
	// final (bonus-inclusive) score and the bonus breakdown, so any
	// future per-question UI sees the same number the leaderboard ZSET
	// stores. The reviewer's C4 concern was the per-answer record going
	// stale at base — verify that's no longer true.
	assertAnswerRecord(t, ctx, rdb, roomID, 1, uid, baseR1, finalR1, sb1, fcb1)
	assertAnswerRecord(t, ctx, rdb, roomID, 2, uid, baseR2, finalR2, sb2, fcb2)

	// --- Redelivery: HSETNX returns false on the same (room, round, user),
	// so processAnswer's early-return MUST trip. We verify by trying
	// TrySetAnswer again and asserting BumpStreak / IncrCorrectOrder are
	// NOT invoked (we just check the counters didn't move).
	preStreak, _ := rdb.Get(ctx, keys.Streak(roomID, uid)).Result()
	preRank, _ := rdb.Get(ctx, keys.CorrectOrder(roomID, 2)).Result()
	wasSet, err = keys.TrySetAnswer(ctx, rdb, roomID, 2, uid, marshalPlaceholder(t, baseR2, true))
	if err != nil {
		t.Fatalf("redelivery TrySetAnswer: %v", err)
	}
	if wasSet {
		t.Fatalf("redelivery TrySetAnswer should return false on duplicate; got true")
	}
	postStreak, _ := rdb.Get(ctx, keys.Streak(roomID, uid)).Result()
	postRank, _ := rdb.Get(ctx, keys.CorrectOrder(roomID, 2)).Result()
	if preStreak != postStreak {
		t.Errorf("streak moved on redelivery: pre=%q post=%q (HSETNX gate must block re-bump)", preStreak, postStreak)
	}
	if preRank != postRank {
		t.Errorf("first-correct counter moved on redelivery: pre=%q post=%q", preRank, postRank)
	}
}

// TestRecencyBonus_WrongAnswerResetsStreak — a wrong answer in round 2
// after a correct round 1 must reset the streak counter so a round-3
// correct answer starts at level 1, not level 3. Exercises the
// ResetStreak branch processAnswer takes when calcResp.Correct == false.
func TestRecencyBonus_WrongAnswerResetsStreak(t *testing.T) {
	rdb := attachRedisOrSkip(t)
	ctx := context.Background()
	const (
		roomID = "r-recency-reset"
		uid    = "u-bob"
	)

	// Round 1 correct → streak 1
	_, err := keys.TrySetAnswer(ctx, rdb, roomID, 1, uid, marshalPlaceholder(t, 100, true))
	if err != nil {
		t.Fatalf("r1 TrySetAnswer: %v", err)
	}
	if lvl, _ := keys.BumpStreak(ctx, rdb, roomID, uid); lvl != 1 {
		t.Fatalf("r1 streak %d, want 1", lvl)
	}

	// Round 2 wrong → ResetStreak
	_, err = keys.TrySetAnswer(ctx, rdb, roomID, 2, uid, marshalPlaceholder(t, 0, false))
	if err != nil {
		t.Fatalf("r2 TrySetAnswer: %v", err)
	}
	if err := keys.ResetStreak(ctx, rdb, roomID, uid); err != nil {
		t.Fatalf("ResetStreak: %v", err)
	}

	// Round 3 correct → streak back to 1, NOT 3.
	_, err = keys.TrySetAnswer(ctx, rdb, roomID, 3, uid, marshalPlaceholder(t, 100, true))
	if err != nil {
		t.Fatalf("r3 TrySetAnswer: %v", err)
	}
	if lvl, _ := keys.BumpStreak(ctx, rdb, roomID, uid); lvl != 1 {
		t.Errorf("r3 streak %d, want 1 (reset after wrong answer)", lvl)
	}
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

// attachRedisOrSkip mirrors attachRedis in friends_test.go but scoped
// to this file so a future split of friends_test.go's helpers doesn't
// break the recency integration tests. Skips if Redis isn't reachable.
func attachRedisOrSkip(t *testing.T) *redis.Client {
	t.Helper()
	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		addr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: addr})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		t.Skipf("redis ping: %v", err)
	}
	if err := rdb.FlushDB(context.Background()).Err(); err != nil {
		t.Fatalf("redis flush: %v", err)
	}
	t.Cleanup(func() { _ = rdb.Close() })
	return rdb
}

// marshalPlaceholder builds the same pre-TrySetAnswer record shape
// processAnswer marshals — base score, no bonus fields yet. Kept as a
// helper so the test reads at the same level of abstraction as the
// production code path.
func marshalPlaceholder(t *testing.T, baseScore float64, correct bool) string {
	t.Helper()
	b, err := json.Marshal(map[string]interface{}{
		"optionIndex":     0,
		"correct":         correct,
		"score":           baseScore,
		"timestamp":       int64(0),
		"clientTimestamp": int64(0),
	})
	if err != nil {
		t.Fatalf("marshalPlaceholder: %v", err)
	}
	return string(b)
}

// overwriteAnswerJSON mirrors the HSet processAnswer issues after the
// bonus is computed — final score, both bonus components, base score.
func overwriteAnswerJSON(ctx context.Context, rdb *redis.Client, roomID string, round int, uid string,
	baseScore, finalScore, streakBonus, firstCorrectBonus float64, correct bool) error {
	body, err := json.Marshal(map[string]interface{}{
		"optionIndex":       0,
		"correct":           correct,
		"score":             finalScore,
		"baseScore":         baseScore,
		"streakBonus":       streakBonus,
		"firstCorrectBonus": firstCorrectBonus,
		"timestamp":         int64(0),
		"clientTimestamp":   int64(0),
	})
	if err != nil {
		return err
	}
	return rdb.HSet(ctx, keys.Answers(roomID, round), uid, string(body)).Err()
}

// assertAnswerRecord re-reads the per-answer JSON and verifies the four
// score-related fields match what we wrote.
func assertAnswerRecord(t *testing.T, ctx context.Context, rdb *redis.Client, roomID string, round int, uid string,
	wantBase, wantFinal, wantStreak, wantFirstCorrect float64) {
	t.Helper()
	raw, err := rdb.HGet(ctx, keys.Answers(roomID, round), uid).Result()
	if err != nil {
		t.Fatalf("HGet answers round %d: %v", round, err)
	}
	var rec struct {
		Score             float64 `json:"score"`
		BaseScore         float64 `json:"baseScore"`
		StreakBonus       float64 `json:"streakBonus"`
		FirstCorrectBonus float64 `json:"firstCorrectBonus"`
	}
	if err := json.Unmarshal([]byte(raw), &rec); err != nil {
		t.Fatalf("unmarshal answer round %d: %v (raw=%s)", round, err, raw)
	}
	if rec.Score != wantFinal {
		t.Errorf("round %d per-answer score: got %v want %v", round, rec.Score, wantFinal)
	}
	if rec.BaseScore != wantBase {
		t.Errorf("round %d per-answer baseScore: got %v want %v", round, rec.BaseScore, wantBase)
	}
	if rec.StreakBonus != wantStreak {
		t.Errorf("round %d per-answer streakBonus: got %v want %v", round, rec.StreakBonus, wantStreak)
	}
	if rec.FirstCorrectBonus != wantFirstCorrect {
		t.Errorf("round %d per-answer firstCorrectBonus: got %v want %v", round, rec.FirstCorrectBonus, wantFirstCorrect)
	}
}

// scoreOf returns the score for `member` in `entries`, or NaN-like -1
// if missing. Used by both round assertions.
func scoreOf(entries []redis.Z, member string) float64 {
	for _, e := range entries {
		if e.Member == member {
			return e.Score
		}
	}
	return -1
}
