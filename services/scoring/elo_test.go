package main

import (
	"math"
	"testing"
)

// computeEloDelta is a pure function — these tests pin the rating
// contract that persistMatch relies on. The integration test of
// persistMatch itself would need a full Redis + Mongo + RabbitMQ
// harness; isolating the math here keeps the contract verifiable
// without that scaffolding.

func TestComputeEloDelta_TwoPlayersEqualRatingsWinner(t *testing.T) {
	ratings := map[string]float64{"alice": 1200, "bob": 1200}
	parts := []string{"alice", "bob"}

	// Alice wins. Expected = 0.5 (equal ratings), actual = 1.0, K = 32.
	// delta = round(32 * (1 - 0.5)) = +16.
	d, isWinner, applied := computeEloDelta("alice", parts, ratings, "alice", eloK)
	if !applied || !isWinner || d != 16 {
		t.Errorf("winner: got d=%d isWinner=%v applied=%v, want d=16 isWinner=true applied=true", d, isWinner, applied)
	}

	d, isWinner, applied = computeEloDelta("bob", parts, ratings, "alice", eloK)
	if !applied || isWinner || d != -16 {
		t.Errorf("loser: got d=%d isWinner=%v applied=%v, want d=-16 isWinner=false applied=true", d, isWinner, applied)
	}
}

func TestComputeEloDelta_TwoPlayersNoWinnerIsDraw(t *testing.T) {
	// Both players scored zero — match has no winner. Treat as a draw:
	// actual = 0.5 for everyone, sum of deltas = 0 (rating conservation).
	ratings := map[string]float64{"alice": 1200, "bob": 1200}
	parts := []string{"alice", "bob"}

	for _, uid := range parts {
		d, isWinner, applied := computeEloDelta(uid, parts, ratings, "", eloK)
		if !applied {
			t.Errorf("%s: applied=false, want true (2 participants is not solo)", uid)
		}
		if isWinner {
			t.Errorf("%s: isWinner=true but winnerID is empty", uid)
		}
		if d != 0 {
			t.Errorf("%s: d=%d, want 0 (equal ratings + draw)", uid, d)
		}
	}
}

func TestComputeEloDelta_NoWinnerUnequalRatingsStillConserves(t *testing.T) {
	// Pin rating conservation under draw with unequal ratings: the
	// underdog gains a little and the favourite loses the same.
	ratings := map[string]float64{"underdog": 1100, "favourite": 1300}
	parts := []string{"underdog", "favourite"}

	dU, _, _ := computeEloDelta("underdog", parts, ratings, "", eloK)
	dF, _, _ := computeEloDelta("favourite", parts, ratings, "", eloK)

	if dU+dF != 0 {
		t.Errorf("draw must conserve rating: dU=%d dF=%d sum=%d", dU, dF, dU+dF)
	}
	if dU <= 0 || dF >= 0 {
		t.Errorf("underdog should gain on a draw vs higher-rated: dU=%d dF=%d", dU, dF)
	}
}

func TestComputeEloDelta_UnderdogWinTakesMoreRating(t *testing.T) {
	// 1100 beating 1500 should swing harder than 1200 beating 1200.
	even := map[string]float64{"a": 1200, "b": 1200}
	upset := map[string]float64{"underdog": 1100, "favourite": 1500}

	dEven, _, _ := computeEloDelta("a", []string{"a", "b"}, even, "a", eloK)
	dUpset, _, _ := computeEloDelta("underdog", []string{"underdog", "favourite"}, upset, "underdog", eloK)
	if dUpset <= dEven {
		t.Errorf("upset win should yield bigger delta than even win: even=%d upset=%d", dEven, dUpset)
	}
}

func TestComputeEloDelta_SoloRoomNotApplied(t *testing.T) {
	// A room with one participant has no opponents. Caller still bumps
	// matchesPlayed; we just don't do rating math.
	ratings := map[string]float64{"alice": 1200}
	d, isWinner, applied := computeEloDelta("alice", []string{"alice"}, ratings, "alice", eloK)
	if applied {
		t.Errorf("applied=true for solo room, want false")
	}
	if d != 0 {
		t.Errorf("solo d=%d, want 0", d)
	}
	if !isWinner {
		// winnerID matches userID — that flag is still set; the caller
		// decides what to do with it (incrementing wins for a solo
		// match would be silly; matchesPlayed alone is the right call).
		t.Errorf("solo room: isWinner=false, expected true since userID == winnerID — caller handles this")
	}
}

func TestComputeEloDelta_ThreePlayersSymmetricLossesAndBoundedDelta(t *testing.T) {
	// 3-player room with two interchangeable favourites and one
	// underdog winner. Tests two properties that DO hold under
	// averaged-expected Elo (used here because each player's expected
	// score is the mean of pairwise expectations, not a sum):
	//   (a) symmetric losers get identical deltas
	//   (b) every per-player delta stays within ±K (32 here) — the
	//       averaging guarantees |delta| <= K regardless of how many
	//       opponents the player has.
	// Rating conservation is NOT a property of averaged-expected Elo
	// for >2 players; the helper is fine for 1v1 (the actual matchmaking
	// shape) and acceptably approximate for the rare multi-player case
	// (tournaments use a different scoring system anyway).
	ratings := map[string]float64{
		"underdog": 1100,
		"foe1":     1400,
		"foe2":     1400,
	}
	parts := []string{"foe1", "foe2", "underdog"}

	dU, _, _ := computeEloDelta("underdog", parts, ratings, "underdog", eloK)
	d1, _, _ := computeEloDelta("foe1", parts, ratings, "underdog", eloK)
	d2, _, _ := computeEloDelta("foe2", parts, ratings, "underdog", eloK)

	if d1 != d2 {
		t.Errorf("symmetric foes should get identical deltas: foe1=%d foe2=%d", d1, d2)
	}
	for name, d := range map[string]int32{"underdog": dU, "foe1": d1, "foe2": d2} {
		if math.Abs(float64(d)) > eloK {
			t.Errorf("%s delta |%d| > K (%v) — averaging should clamp to ±K", name, d, eloK)
		}
	}
	if dU <= 0 {
		t.Errorf("underdog won — delta must be positive, got %d", dU)
	}
}
