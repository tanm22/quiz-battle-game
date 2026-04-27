package log

import (
	"context"
	"testing"

	"github.com/google/uuid"
)

func TestRequestIDRoundTrip(t *testing.T) {
	ctx := ContextWithRequestID(context.Background(), "rid-abc")
	if got := RequestIDFromContext(ctx); got != "rid-abc" {
		t.Errorf("RequestIDFromContext = %q, want %q", got, "rid-abc")
	}
}

func TestRequestIDMissing(t *testing.T) {
	if got := RequestIDFromContext(context.Background()); got != "" {
		t.Errorf("RequestIDFromContext on bare ctx = %q, want empty", got)
	}
}

func TestRequestIDOverwrite(t *testing.T) {
	ctx := ContextWithRequestID(context.Background(), "first")
	ctx = ContextWithRequestID(ctx, "second")
	if got := RequestIDFromContext(ctx); got != "second" {
		t.Errorf("got %q, want second", got)
	}
}

func TestNewRequestIDIsUUID(t *testing.T) {
	id := NewRequestID()
	if _, err := uuid.Parse(id); err != nil {
		t.Errorf("NewRequestID() = %q, not a valid UUID: %v", id, err)
	}
}

func TestNewRequestIDIsUnique(t *testing.T) {
	a, b := NewRequestID(), NewRequestID()
	if a == b {
		t.Errorf("NewRequestID returned same value twice: %q", a)
	}
}
