// Package log wraps log/slog with project conventions: JSON handler, service
// attr, request-id context helpers, and a Fatal helper for startup aborts.
package log

import (
	"log/slog"
	"strings"
)

// ParseLevel returns the slog.Level matching s. Recognised: debug, info, warn,
// warning, error (case-insensitive). Unknown or empty values default to INFO.
func ParseLevel(s string) slog.Level {
	level, _ := parseLevel(s)
	return level
}

// parseLevel is the internal helper that also reports whether s matched a
// known level. Init uses the ok flag to warn on typos like LOG_LEVEL=warining
// instead of silently defaulting to INFO.
func parseLevel(s string) (slog.Level, bool) {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "debug":
		return slog.LevelDebug, true
	case "info":
		return slog.LevelInfo, true
	case "warn", "warning":
		return slog.LevelWarn, true
	case "error":
		return slog.LevelError, true
	}
	return slog.LevelInfo, false
}
