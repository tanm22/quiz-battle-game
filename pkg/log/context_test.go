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

func TestContextWithAttrsRoundTrip(t *testing.T) {
	ctx := ContextWithAttrs(context.Background(), "k1", "v1", "k2", 42)
	got := AttrsFromContext(ctx)
	if len(got) != 4 {
		t.Fatalf("attrs len = %d, want 4: %v", len(got), got)
	}
	if got[0] != "k1" || got[1] != "v1" || got[2] != "k2" || got[3] != 42 {
		t.Errorf("attrs round-trip wrong: %v", got)
	}
}

func TestContextWithAttrsAccumulates(t *testing.T) {
	ctx := ContextWithAttrs(context.Background(), "k1", "v1")
	ctx = ContextWithAttrs(ctx, "k2", "v2")
	got := AttrsFromContext(ctx)
	if len(got) != 4 {
		t.Fatalf("attrs len = %d, want 4: %v", len(got), got)
	}
	if got[0] != "k1" || got[1] != "v1" || got[2] != "k2" || got[3] != "v2" {
		t.Errorf("accumulated attrs wrong: %v", got)
	}
}

func TestContextWithAttrsEmpty(t *testing.T) {
	parent := context.Background()
	ctx := ContextWithAttrs(parent /* no args */)
	if got := AttrsFromContext(ctx); got != nil {
		t.Errorf("empty ContextWithAttrs should not store; got %v", got)
	}
}

func TestAttrsFromContextMissing(t *testing.T) {
	if got := AttrsFromContext(context.Background()); got != nil {
		t.Errorf("AttrsFromContext on bare ctx = %v, want nil", got)
	}
}

func TestDetachContextCarriesRequestIDAndAttrs(t *testing.T) {
	parent, cancel := context.WithCancel(context.Background())
	parent = ContextWithRequestID(parent, "rid-detach")
	parent = ContextWithAttrs(parent, "consumer", "test")
	cancel() // parent is now cancelled

	detached := DetachContext(parent)

	if rid := RequestIDFromContext(detached); rid != "rid-detach" {
		t.Errorf("request_id not carried: got %q", rid)
	}
	attrs := AttrsFromContext(detached)
	if len(attrs) != 2 || attrs[0] != "consumer" || attrs[1] != "test" {
		t.Errorf("attrs not carried: %v", attrs)
	}
	// Parent cancelled but detached must NOT be cancelled.
	if detached.Err() != nil {
		t.Errorf("detached.Err() = %v, want nil (cancellation should not propagate)", detached.Err())
	}
}

func TestDetachContextEmpty(t *testing.T) {
	detached := DetachContext(context.Background())
	if rid := RequestIDFromContext(detached); rid != "" {
		t.Errorf("request_id leaked: %q", rid)
	}
	if attrs := AttrsFromContext(detached); attrs != nil {
		t.Errorf("attrs leaked: %v", attrs)
	}
	if detached.Err() != nil {
		t.Errorf("detached.Err() = %v", detached.Err())
	}
}
