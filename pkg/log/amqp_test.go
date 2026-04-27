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

// TestStampRequestID_AttachesHeader exercises the header-set logic on
// the production code path. stampRequestID is the small free function
// PublishWithContext delegates to before invoking ch.PublishWithContext,
// so a future refactor that drops the header stamp inside the helper
// will fail this test.
func TestStampRequestID_AttachesHeader(t *testing.T) {
	ctx := ContextWithRequestID(context.Background(), "rid-publish-test")
	in := amqp.Publishing{Body: []byte("hello")}

	out := stampRequestID(ctx, in)

	got, ok := out.Headers[AMQPRequestIDHeader].(string)
	if !ok {
		t.Fatalf("header not a string: %T %v", out.Headers[AMQPRequestIDHeader], out.Headers[AMQPRequestIDHeader])
	}
	if got != "rid-publish-test" {
		t.Errorf("header = %q, want rid-publish-test", got)
	}
}

func TestStampRequestID_NoopWhenCtxHasNoID(t *testing.T) {
	in := amqp.Publishing{Body: []byte("hello")}
	out := stampRequestID(context.Background(), in)
	if out.Headers != nil {
		t.Errorf("headers should remain nil when ctx has no rid, got %v", out.Headers)
	}
}

func TestStampRequestID_PreservesExistingHeaders(t *testing.T) {
	// A caller that pre-populated msg.Headers with their own keys must
	// not lose them when stampRequestID adds the rid.
	ctx := ContextWithRequestID(context.Background(), "rid-pre")
	in := amqp.Publishing{
		Body:    []byte("hello"),
		Headers: amqp.Table{"x-app-key": "value-a"},
	}
	out := stampRequestID(ctx, in)
	if out.Headers["x-app-key"] != "value-a" {
		t.Errorf("pre-existing header lost: %v", out.Headers)
	}
	if out.Headers[AMQPRequestIDHeader] != "rid-pre" {
		t.Errorf("rid not stamped: %v", out.Headers)
	}
}
