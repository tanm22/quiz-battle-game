package log

import (
	"context"

	amqp "github.com/rabbitmq/amqp091-go"
)

// AMQPRequestIDHeader is the AMQP message header carrying a request_id
// across event publishes for cross-service correlation. Same name as
// the gRPC metadata key on purpose — a single grep in logs works for
// both transports.
const AMQPRequestIDHeader = "x-request-id"

// PublishWithContext wraps amqp.Channel.PublishWithContext, attaching
// the request_id from ctx (if present) as an AMQP header so the
// consumer can extract it via ContextFromDelivery and continue the
// correlation chain. If ctx has no request_id, this behaves identically
// to the underlying ch.PublishWithContext — the consumer will mint a
// fresh id of its own.
//
// Use this for every cross-service publish that originates from an RPC
// handler or a consumer (which already has a request_id on its ctx via
// ContextFromDelivery). Direct ch.PublishWithContext calls remain valid
// for cron / startup paths that have no inbound ctx.
func PublishWithContext(ctx context.Context, ch *amqp.Channel, exchange, key string, mandatory, immediate bool, msg amqp.Publishing) error {
	return ch.PublishWithContext(ctx, exchange, key, mandatory, immediate, stampRequestID(ctx, msg))
}

// stampRequestID returns msg with the AMQPRequestIDHeader set when ctx
// carries a request_id, otherwise returns msg unchanged. Extracted
// from PublishWithContext as a free function so tests can exercise the
// header-set logic without constructing a real *amqp.Channel.
func stampRequestID(ctx context.Context, msg amqp.Publishing) amqp.Publishing {
	rid := RequestIDFromContext(ctx)
	if rid == "" {
		return msg
	}
	if msg.Headers == nil {
		msg.Headers = amqp.Table{}
	}
	msg.Headers[AMQPRequestIDHeader] = rid
	return msg
}

// ContextFromDelivery returns parent with a request_id attached: either
// the value of the AMQPRequestIDHeader on the delivery, or a freshly
// minted UUID if the publisher did not set the header (legacy publisher,
// external producer, etc.). The consumer's logs always have *some*
// correlation id — never empty.
func ContextFromDelivery(parent context.Context, d amqp.Delivery) context.Context {
	if d.Headers != nil {
		if v, ok := d.Headers[AMQPRequestIDHeader]; ok {
			if s, ok := v.(string); ok && s != "" {
				return ContextWithRequestID(parent, s)
			}
		}
	}
	return ContextWithRequestID(parent, NewRequestID())
}
