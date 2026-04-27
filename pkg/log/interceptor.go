package log

import (
	"context"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// RequestIDMetadataKey is the gRPC metadata key carrying a per-request
// correlation ID across service boundaries. Lower-case per gRPC's
// canonicalisation rule for metadata keys.
const RequestIDMetadataKey = "x-request-id"

// UnaryServerInterceptor returns a gRPC unary server interceptor that
// extracts an x-request-id from incoming metadata (or generates one if
// absent), stores it on the request ctx via ContextWithRequestID, and
// emits a structured log line on RPC finish with method, code, and
// duration. Panics in the handler are recovered into a codes.Internal
// status error so a single misbehaving RPC cannot kill the server.
//
// Order matters when chaining: install this BEFORE auth interceptors so
// the request_id is on ctx for any auth-rejected RPC's log line too.
func UnaryServerInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp any, err error) {
		ctx = ensureRequestID(ctx)
		start := time.Now()

		defer func() {
			if r := recover(); r != nil {
				FromContext(ctx).Error("rpc panic recovered",
					"method", info.FullMethod,
					"panic", r,
				)
				err = status.Errorf(codes.Internal, "internal error")
			}
		}()

		resp, err = handler(ctx, req)
		FromContext(ctx).Info("rpc finished",
			"method", info.FullMethod,
			"code", status.Code(err).String(),
			"duration_ms", time.Since(start).Milliseconds(),
		)
		return resp, err
	}
}

// StreamServerInterceptor wraps streaming RPCs the same way: ensures a
// request_id on the stream's ctx and logs open/close with duration. The
// log line on close fires when the handler returns, which for long-lived
// streams (matchmaking subscriptions, quiz game-event streams) means
// only at disconnect — so duration is "stream lifetime", not per-message.
func StreamServerInterceptor() grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) (err error) {
		ctx := ensureRequestID(ss.Context())
		start := time.Now()

		defer func() {
			if r := recover(); r != nil {
				FromContext(ctx).Error("stream panic recovered",
					"method", info.FullMethod,
					"panic", r,
				)
				err = status.Errorf(codes.Internal, "internal error")
			}
		}()

		err = handler(srv, &wrappedStream{ServerStream: ss, ctx: ctx})
		FromContext(ctx).Info("stream closed",
			"method", info.FullMethod,
			"code", status.Code(err).String(),
			"duration_ms", time.Since(start).Milliseconds(),
		)
		return err
	}
}

// UnaryClientInterceptor reads request_id from the calling ctx and
// attaches it as outgoing gRPC metadata, so the downstream server's
// UnaryServerInterceptor sees it in metadata.FromIncomingContext and
// continues the correlation chain. If ctx has no request_id (e.g., the
// caller never went through a server interceptor), this is a no-op —
// the downstream server will mint its own.
func UnaryClientInterceptor() grpc.UnaryClientInterceptor {
	return func(ctx context.Context, method string, req, reply any, cc *grpc.ClientConn, invoker grpc.UnaryInvoker, opts ...grpc.CallOption) error {
		if rid := RequestIDFromContext(ctx); rid != "" {
			ctx = metadata.AppendToOutgoingContext(ctx, RequestIDMetadataKey, rid)
		}
		return invoker(ctx, method, req, reply, cc, opts...)
	}
}

// StreamClientInterceptor — same idea as UnaryClientInterceptor but for
// streams (matchmaking and quiz both have streaming RPCs).
func StreamClientInterceptor() grpc.StreamClientInterceptor {
	return func(ctx context.Context, desc *grpc.StreamDesc, cc *grpc.ClientConn, method string, streamer grpc.Streamer, opts ...grpc.CallOption) (grpc.ClientStream, error) {
		if rid := RequestIDFromContext(ctx); rid != "" {
			ctx = metadata.AppendToOutgoingContext(ctx, RequestIDMetadataKey, rid)
		}
		return streamer(ctx, desc, cc, method, opts...)
	}
}

// ensureRequestID returns ctx with a request_id guaranteed present,
// preferring (in order): an existing ctx-stored id, an inbound gRPC
// metadata header, or a freshly generated UUID.
func ensureRequestID(ctx context.Context) context.Context {
	if RequestIDFromContext(ctx) != "" {
		return ctx
	}
	if md, ok := metadata.FromIncomingContext(ctx); ok {
		if vals := md.Get(RequestIDMetadataKey); len(vals) > 0 && vals[0] != "" {
			return ContextWithRequestID(ctx, vals[0])
		}
	}
	return ContextWithRequestID(ctx, NewRequestID())
}

// wrappedStream replaces ServerStream.Context() with the request-id-bearing
// ctx so downstream stream handler reads of stream.Context() see it.
type wrappedStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (w *wrappedStream) Context() context.Context { return w.ctx }
