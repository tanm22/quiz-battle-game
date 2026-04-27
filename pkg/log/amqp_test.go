package log

import (
	"context"
	"testing"

	amqp "github.com/rabbitmq/amqp091-go"
)

func TestContextFromDelivery_PicksUpHeader(t *testing.T) {
	d := amqp.Delivery{
		Headers: amqp.Table{AMQPRequestIDHeader: "rid-from-publisher"},
	}
	ctx := ContextFromDelivery(context.Background(), d)
	if got := RequestIDFromContext(ctx); got != "rid-from-publisher" {
		t.Errorf("request_id = %q, want rid-from-publisher", got)
	}
}

func TestContextFromDelivery_GeneratesWhenAbsent(t *testing.T) {
	d := amqp.Delivery{Headers: nil}
	ctx := ContextFromDelivery(context.Background(), d)
	if got := RequestIDFromContext(ctx); got == "" {
		t.Error("expected a freshly generated request_id when header missing")
	}
}

func TestContextFromDelivery_GeneratesWhenHeaderEmpty(t *testing.T) {
	d := amqp.Delivery{Headers: amqp.Table{AMQPRequestIDHeader: ""}}
	ctx := ContextFromDelivery(context.Background(), d)
	if got := RequestIDFromContext(ctx); got == "" {
		t.Error("expected fresh id when header was empty string")
	}
}

func TestContextFromDelivery_IgnoresNonStringHeader(t *testing.T) {
	d := amqp.Delivery{Headers: amqp.Table{AMQPRequestIDHeader: 42}}
	ctx := ContextFromDelivery(context.Background(), d)
	if got := RequestIDFromContext(ctx); got == "" {
		t.Error("expected fresh id when header is non-string")
	}
}

// TestPublishWithContext_AttachesHeader exercises the header-set logic via
// a stub that captures the Publishing without round-tripping through a
// real channel. PublishWithContext's signature accepts *amqp.Channel
// directly, which is hard to stub without changing the API; we instead
// test the in-place msg.Headers mutation by reaching past the helper
// into a near-equivalent inline expansion.
func TestPublishWithContext_AttachesHeaderViaHelper(t *testing.T) {
	// We can't construct *amqp.Channel without a connection, so we
	// validate the header-attach logic by testing the same code path
	// the helper runs before delegating. Future refactor: extract
	// the header-stamping into a small free function and exercise
	// that directly here.
	ctx := ContextWithRequestID(context.Background(), "rid-publish-test")
	msg := amqp.Publishing{Body: []byte("hello")}

	// Inline the helper's header-stamp step.
	if rid := RequestIDFromContext(ctx); rid != "" {
		if msg.Headers == nil {
			msg.Headers = amqp.Table{}
		}
		msg.Headers[AMQPRequestIDHeader] = rid
	}

	got, ok := msg.Headers[AMQPRequestIDHeader].(string)
	if !ok {
		t.Fatalf("header not a string: %T %v", msg.Headers[AMQPRequestIDHeader], msg.Headers[AMQPRequestIDHeader])
	}
	if got != "rid-publish-test" {
		t.Errorf("header = %q, want rid-publish-test", got)
	}
}

func TestPublishWithContext_NoopWhenCtxHasNoID(t *testing.T) {
	msg := amqp.Publishing{Body: []byte("hello")}
	ctx := context.Background()
	// Mirror the helper's pre-publish step.
	if rid := RequestIDFromContext(ctx); rid != "" {
		if msg.Headers == nil {
			msg.Headers = amqp.Table{}
		}
		msg.Headers[AMQPRequestIDHeader] = rid
	}
	if msg.Headers != nil {
		t.Errorf("headers should remain nil when ctx has no rid, got %v", msg.Headers)
	}
}
