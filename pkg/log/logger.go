package log

import (
	"context"
	"io"
	"log/slog"
	"os"
)

// Init returns a slog.Logger configured for the named service. The logger
// writes JSON to os.Stdout, takes its level from LOG_LEVEL, and pre-attaches
// a `service` attribute. Call slog.SetDefault on the result so the global
// slog package routes through this configuration.
//
// If LOG_LEVEL is set to an unrecognized value, Init emits a one-time WARN
// recording the bad value and falls back to INFO — so typos like
// LOG_LEVEL=warining surface in logs instead of silently masking output.
func Init(serviceName string) *slog.Logger {
	return initWith(serviceName, os.Stdout)
}

// initWith is the writer-injecting variant of Init. Tests pass a bytes.Buffer
// to assert on the unrecognized-LOG_LEVEL warn output without redirecting
// os.Stdout.
func initWith(serviceName string, w io.Writer) *slog.Logger {
	raw := os.Getenv("LOG_LEVEL")
	level, known := parseLevel(raw)
	logger := newLogger(serviceName, level, w)
	if raw != "" && !known {
		logger.Warn("unrecognized LOG_LEVEL; defaulting to INFO", "value", raw)
	}
	return logger
}

// newLogger is the internal factory used by Init and tests. Tests pass a
// bytes.Buffer to capture output without touching stdout.
func newLogger(serviceName string, level slog.Level, w io.Writer) *slog.Logger {
	h := slog.NewJSONHandler(w, &slog.HandlerOptions{Level: level})
	return slog.New(h).With("service", serviceName)
}

// FromContext returns a logger derived from slog.Default() with the
// request-id from ctx attached as `request_id`, plus any attrs stored
// on ctx via ContextWithAttrs. Missing values are omitted (callers can
// still log without them).
//
// RPC handlers should use this in place of slog.InfoContext etc. so every
// log line carries the correlation id without per-callsite plumbing.
func FromContext(ctx context.Context) *slog.Logger {
	logger := slog.Default()
	if rid := RequestIDFromContext(ctx); rid != "" {
		logger = logger.With("request_id", rid)
	}
	if attrs := AttrsFromContext(ctx); len(attrs) > 0 {
		logger = logger.With(attrs...)
	}
	return logger
}
