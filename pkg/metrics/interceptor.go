package metrics

import (
	"context"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/status"
)

// UnaryServerInterceptor returns a gRPC unary server interceptor that
// records:
//   - RPCRequestsTotal{method, code} — incremented on every call
//   - RPCDurationSeconds{method, code} — observed with handler runtime
//
// Install AFTER pkg/log's interceptor in the chain so the panic
// recovery there has already converted panics to codes.Internal —
// that way panic-induced "" status codes don't poison the histogram.
func (m *Metrics) UnaryServerInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		start := time.Now()
		resp, err := handler(ctx, req)
		code := status.Code(err).String()
		m.RPCRequestsTotal.WithLabelValues(info.FullMethod, code).Inc()
		m.RPCDurationSeconds.WithLabelValues(info.FullMethod, code).Observe(time.Since(start).Seconds())
		return resp, err
	}
}

// StreamServerInterceptor returns a gRPC stream server interceptor
// that increments RPCRequestsTotal on stream open (counted as one
// request, since stream open is the inbound event). Stream lifetimes
// are NOT observed — the histogram is unary-only on purpose; a
// 30-minute matchmaking subscription would dominate the p99 of every
// other RPC.
func (m *Metrics) StreamServerInterceptor() grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		err := handler(srv, ss)
		code := status.Code(err).String()
		m.RPCRequestsTotal.WithLabelValues(info.FullMethod, code).Inc()
		return err
	}
}
