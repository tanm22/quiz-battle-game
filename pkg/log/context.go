package log

import (
	"context"

	"github.com/google/uuid"
)

// ctxKey is unexported so external packages cannot inject values under
// pkg/log's key by accident. One key per piece of context state.
type ctxKey int

const (
	requestIDKey ctxKey = iota
	attrsKey
)

// NewRequestID returns a fresh UUID v4 string. Used at gRPC/HTTP boundaries
// when no upstream request-id was supplied.
func NewRequestID() string {
	return uuid.NewString()
}

// ContextWithRequestID stores id in ctx for downstream lookup by
// RequestIDFromContext and FromContext.
func ContextWithRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, requestIDKey, id)
}

// RequestIDFromContext returns the request-id stored in ctx, or "" if none.
func RequestIDFromContext(ctx context.Context) string {
	if v, ok := ctx.Value(requestIDKey).(string); ok {
		return v
	}
	return ""
}

// ContextWithAttrs stores additional logging attributes on ctx that
// FromContext will attach to every emitted log line. args follows slog's
// variadic key/value pattern. Multiple calls accumulate (later wins on
// duplicate keys, since slog.With's order semantics put the rightmost
// duplicate last and slog handlers prefer the last occurrence).
//
// Use this at the top of consumer goroutines / worker loops to set a
// constant `consumer=` / `worker=` / `component=` attr once instead of
// repeating it on every log line in the function.
func ContextWithAttrs(ctx context.Context, args ...any) context.Context {
	if len(args) == 0 {
		return ctx
	}
	existing := AttrsFromContext(ctx)
	merged := make([]any, 0, len(existing)+len(args))
	merged = append(merged, existing...)
	merged = append(merged, args...)
	return context.WithValue(ctx, attrsKey, merged)
}

// AttrsFromContext returns the accumulated attrs stored on ctx via
// ContextWithAttrs, or nil if none. Returned slice is shared; callers
// must not mutate it.
func AttrsFromContext(ctx context.Context) []any {
	if v, ok := ctx.Value(attrsKey).([]any); ok {
		return v
	}
	return nil
}

// DetachContext returns a fresh context.Background() that carries the
// request_id and accumulated attrs from parent — but NOT parent's
// cancellation, deadline, or other values.
//
// Use this when spawning cleanup goroutines that must outlive the parent
// request context (e.g., async cache pulls after an RPC returns). The
// goroutine gets its own independent lifecycle, but its log lines still
// correlate to the originating request via the same request_id.
func DetachContext(parent context.Context) context.Context {
	out := context.Background()
	if rid := RequestIDFromContext(parent); rid != "" {
		out = ContextWithRequestID(out, rid)
	}
	if attrs := AttrsFromContext(parent); len(attrs) > 0 {
		out = ContextWithAttrs(out, attrs...)
	}
	return out
}
