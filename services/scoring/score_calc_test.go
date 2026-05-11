package main

import "testing"

// TestComputeRoundScore covers the pure scoring math used by
// CalculateScore. The function is extracted from the RPC body so we
// can test the formula without standing up Mongo for isCorrect.
//
// Every branch and bracket boundary is exercised: fast/medium/slow on
// both correct and wrong, with explicit cases at the 5000ms and 13000ms
// edges so the strict-inequality boundaries don't silently flip.
func TestComputeRoundScore(t *testing.T) {
	cases := []struct {
		name           string
		correct        bool
		answerTimeMs   int64
		wantBase       float64
		wantMultiplier float64
		wantScore      float64
	}{
		// Correct answers across the three speed brackets.
		{"correct + fast (0 ms)", true, 0, 100, 1.5, 150},
		{"correct + fast (just under 5s)", true, 4999, 100, 1.5, 150},
		{"correct + medium (exactly 5s — boundary)", true, 5000, 100, 1.0, 100},
		{"correct + medium (mid-range)", true, 9000, 100, 1.0, 100},
		{"correct + medium (exactly 13s — boundary)", true, 13000, 100, 1.0, 100},
		{"correct + slow (just over 13s)", true, 13001, 100, 0.8, 80},
		{"correct + slow (large value)", true, 60000, 100, 0.8, 80},

		// Wrong answers: base is 0, score is 0, but multiplier is still
		// reported back so the client can show "fast but wrong" telemetry.
		{"wrong + fast", false, 1000, 0, 1.5, 0},
		{"wrong + medium", false, 8000, 0, 1.0, 0},
		{"wrong + slow", false, 20000, 0, 0.8, 0},
		{"wrong at fast boundary", false, 4999, 0, 1.5, 0},
		{"wrong at slow boundary", false, 13001, 0, 0.8, 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			gotBase, gotMult, gotScore := computeRoundScore(tc.correct, tc.answerTimeMs)
			if gotBase != tc.wantBase {
				t.Errorf("base: want %v, got %v", tc.wantBase, gotBase)
			}
			if gotMult != tc.wantMultiplier {
				t.Errorf("multiplier: want %v, got %v", tc.wantMultiplier, gotMult)
			}
			if gotScore != tc.wantScore {
				t.Errorf("score: want %v, got %v", tc.wantScore, gotScore)
			}
		})
	}
}

// TestComputeRoundScore_NegativeAnswerTimeClampedFast covers the edge
// where a buggy client (or a clock-skew incident) sends a negative
// answerTimeMs. The function does NOT panic; it falls into the fast
// bracket because negative is "<5000". This documents the current
// behaviour — the SubmitAnswer handler already validates roomId/round/
// optionIndex bounds, but answerTimeMs is currently unbounded, so the
// formula's robustness to negative input is load-bearing.
func TestComputeRoundScore_NegativeAnswerTimeFalsIntoFastBracket(t *testing.T) {
	_, mult, score := computeRoundScore(true, -42)
	if mult != 1.5 {
		t.Errorf("negative answerTimeMs should map to fast bracket (1.5); got %v", mult)
	}
	if score != 150 {
		t.Errorf("score for correct + negative time: want 150, got %v", score)
	}
}
