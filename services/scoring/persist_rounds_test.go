package main

import "testing"

// TestResolveRoundsForHistory verifies the guard that prevents the -1/0
// sentinels from finishMatch from landing in match_history. Exercises the
// production helper directly so a regression in the guard flips the test.
func TestResolveRoundsForHistory(t *testing.T) {
	cases := []struct {
		name         string
		eventRounds  int
		roundsPlayed int
		want         int
	}{
		{"positive from all-rounds-done", 5, 5, 5},
		{"zero-connected sentinel", 0, 3, 3},
		{"opponent-abandoned sentinel", -1, 2, 2},
		{"both zero (no one ever answered)", 0, 0, 0},
		{"positive beats roundsPlayed", 5, 2, 5},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := resolveRoundsForHistory(tc.eventRounds, tc.roundsPlayed)
			if got != tc.want {
				t.Errorf("resolveRoundsForHistory(%d, %d) = %d, want %d",
					tc.eventRounds, tc.roundsPlayed, got, tc.want)
			}
		})
	}
}
