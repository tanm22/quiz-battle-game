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
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
