package keys

import (
	"context"
	"testing"
)

// TestBumpStreak_IncrementsAndResets covers the streak counter's two
// states: INCR on each correct answer (returns the new level for the
// scoring service to map to a bonus) and DEL on a wrong answer so the
// next correct starts a fresh streak at level 1.
func TestBumpStreak_IncrementsAndResets(t *testing.T) {
	rdb := testRedis(t)
	ctx := context.Background()
	roomID, userID := "room-A", "alice"

	for i := int64(1); i <= 3; i++ {
		got, err := BumpStreak(ctx, rdb, roomID, userID)
		if err != nil {
			t.Fatalf("BumpStreak #%d: %v", i, err)
		}
		if got != i {
			t.Errorf("BumpStreak #%d: want %d, got %d", i, i, got)
		}
	}

	if err := ResetStreak(ctx, rdb, roomID, userID); err != nil {
		t.Fatalf("ResetStreak: %v", err)
	}

	got, err := BumpStreak(ctx, rdb, roomID, userID)
	if err != nil {
		t.Fatalf("BumpStreak after reset: %v", err)
	}
	if got != 1 {
		t.Errorf("BumpStreak after reset: want fresh level 1, got %d", got)
	}
}

// TestBumpStreak_PerUserIsolation guards against a key-name typo that
// would make two players share a streak counter inside the same room.
func TestBumpStreak_PerUserIsolation(t *testing.T) {
	rdb := testRedis(t)
	ctx := context.Background()

	for i := 0; i < 3; i++ {
		if _, err := BumpStreak(ctx, rdb, "room-A", "alice"); err != nil {
			t.Fatalf("alice bump: %v", err)
		}
	}
	bob, err := BumpStreak(ctx, rdb, "room-A", "bob")
	if err != nil {
		t.Fatalf("bob bump: %v", err)
	}
	if bob != 1 {
		t.Errorf("bob's first bump must be 1, got %d (alice's counter leaked?)", bob)
	}
}

// TestBumpStreak_PerRoomIsolation guards against a stale match's
// streak bleeding into a fresh challenge between the same two players.
func TestBumpStreak_PerRoomIsolation(t *testing.T) {
	rdb := testRedis(t)
	ctx := context.Background()

	for i := 0; i < 4; i++ {
		if _, err := BumpStreak(ctx, rdb, "room-A", "alice"); err != nil {
			t.Fatalf("room-A bump: %v", err)
		}
	}
	got, err := BumpStreak(ctx, rdb, "room-B", "alice")
	if err != nil {
		t.Fatalf("room-B bump: %v", err)
	}
	if got != 1 {
		t.Errorf("alice's first bump in room-B must be 1, got %d (room-A leaked?)", got)
	}
}

// TestIncrCorrectOrder_ReturnsArrivalRank covers the per-round
// first-correct ordering — three players answering correctly in
// sequence must get ranks 1, 2, 3 so the scoring service can map
// them to the firstCorrectBonusByRank slice.
func TestIncrCorrectOrder_ReturnsArrivalRank(t *testing.T) {
	rdb := testRedis(t)
	ctx := context.Background()
	roomID, round := "room-A", 1

	for i := int64(1); i <= 3; i++ {
		got, err := IncrCorrectOrder(ctx, rdb, roomID, round)
		if err != nil {
			t.Fatalf("IncrCorrectOrder #%d: %v", i, err)
		}
		if got != i {
			t.Errorf("IncrCorrectOrder #%d: want rank %d, got %d", i, i, got)
		}
	}
}

// TestIncrCorrectOrder_PerRoundIsolation guards against a stale
// previous-round counter bleeding into the next round's rank — that
// would silently strip the first-correct bonus from round 2's actual
// first correct answerer.
func TestIncrCorrectOrder_PerRoundIsolation(t *testing.T) {
	rdb := testRedis(t)
	ctx := context.Background()

	for i := 0; i < 2; i++ {
		if _, err := IncrCorrectOrder(ctx, rdb, "room-A", 1); err != nil {
			t.Fatalf("round 1 bump: %v", err)
		}
	}
	got, err := IncrCorrectOrder(ctx, rdb, "room-A", 2)
	if err != nil {
		t.Fatalf("round 2 bump: %v", err)
	}
	if got != 1 {
		t.Errorf("first correct in round 2 must be rank 1, got %d (round 1 leaked?)", got)
	}
}
