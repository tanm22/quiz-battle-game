package log

import (
	"log/slog"
	"testing"
)

func TestParseLevel(t *testing.T) {
	tests := []struct {
		in   string
		want slog.Level
	}{
		{"debug", slog.LevelDebug},
		{"DEBUG", slog.LevelDebug},
		{"Debug", slog.LevelDebug},
		{"info", slog.LevelInfo},
		{"warn", slog.LevelWarn},
		{"warning", slog.LevelWarn},
		{"error", slog.LevelError},
		{"", slog.LevelInfo},
		{"garbage", slog.LevelInfo},
	}
	for _, tc := range tests {
		t.Run(tc.in, func(t *testing.T) {
			if got := ParseLevel(tc.in); got != tc.want {
				t.Errorf("ParseLevel(%q) = %v, want %v", tc.in, got, tc.want)
			}
		})
	}
}

func TestParseLevelKnownFlag(t *testing.T) {
	tests := []struct {
		in    string
		known bool
	}{
		{"debug", true},
		{"INFO", true},
		{"warn", true},
		{"warning", true},
		{"error", true},
		{"", false},
		{"warining", false},
		{"trace", false},
	}
	for _, tc := range tests {
		t.Run(tc.in, func(t *testing.T) {
			if _, got := parseLevel(tc.in); got != tc.known {
				t.Errorf("parseLevel(%q) known = %v, want %v", tc.in, got, tc.known)
			}
		})
	}
}
