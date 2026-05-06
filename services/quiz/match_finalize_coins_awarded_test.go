package main

import (
	"testing"

	pb "quiz-battle/proto"
)

// buildPlayerResults is the pure-logic step that turns ranked rooms into
// pb.PlayerResult slices with coins_awarded populated. Locating this as a
// pure function (rather than threading rooms through the whole finalizer)
// keeps the test fast and free of mongo/rabbitmq dependencies.
func TestBuildPlayerResults_RankOneGetsMatchWinReward(t *testing.T) {
	ranked := []rankedPlayer{
		{UserID: "winner", Username: "alice", FinalScore: 1000, Rank: 1, AnswersCorrect: 5, AvgRespMs: 500, Plan: "premium"},
		{UserID: "loser", Username: "bob", FinalScore: 800, Rank: 2, AnswersCorrect: 4, AvgRespMs: 700, Plan: "free"},
	}
	got := buildPlayerResults(ranked)
	if len(got) != 2 {
		t.Fatalf("len=%d, want 2", len(got))
	}
	if got[0].CoinsAwarded != matchWinCoinReward {
		t.Errorf("rank-1 coins_awarded=%d, want %d", got[0].CoinsAwarded, matchWinCoinReward)
	}
	if got[1].CoinsAwarded != 0 {
		t.Errorf("rank-2 coins_awarded=%d, want 0", got[1].CoinsAwarded)
	}
}

func TestBuildPlayerResults_EmptyInput(t *testing.T) {
	got := buildPlayerResults(nil)
	if len(got) != 0 {
		t.Errorf("len=%d, want 0", len(got))
	}
}

// Smoke test that the proto field exists and is populatable.
func TestPlayerResult_CoinsAwardedField(t *testing.T) {
	p := &pb.PlayerResult{CoinsAwarded: 100}
	if p.CoinsAwarded != 100 {
		t.Fatal("CoinsAwarded field round-trip failed")
	}
}
