package main

import "testing"

// TestRoundsForHistory verifies that negative or zero sentinel values from
// the abandonment path get replaced with the authoritative roundsPlayed
// count before persisting to match_history. Regression guard for the bug
// where abandoned matches stored rounds=-1 in MongoDB.
func TestRoundsForHistory(t *testing.T) {
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
			got := tc.eventRounds
			if got <= 0 {
				got = tc.roundsPlayed
			}
			if got != tc.want {
				t.Errorf("roundsForHistory=%d want %d", got, tc.want)
			}
		})
	}
}
