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
