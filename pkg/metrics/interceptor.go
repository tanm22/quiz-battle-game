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
// The interceptor is panic-tolerant by design: a deferred recover
// captures the panic, records the metric as code="Internal", then
// re-panics so an outer interceptor (typically pkg/log) can perform
// its own recovery and convert the panic into a gRPC status error.
// This means correctness does not depend on chain order — install
// alongside pkg/log's interceptor in any order; both will record
// every call, including panicked ones.
func (m *Metrics) UnaryServerInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp any, err error) {
		start := time.Now()
		defer func() {
			if r := recover(); r != nil {
				m.RPCRequestsTotal.WithLabelValues(info.FullMethod, "Internal").Inc()
				m.RPCDurationSeconds.WithLabelValues(info.FullMethod, "Internal").Observe(time.Since(start).Seconds())
				panic(r) // re-raise so the outer pkg/log interceptor still recovers + converts to a gRPC error
			}
			code := status.Code(err).String()
			m.RPCRequestsTotal.WithLabelValues(info.FullMethod, code).Inc()
			m.RPCDurationSeconds.WithLabelValues(info.FullMethod, code).Observe(time.Since(start).Seconds())
		}()
		resp, err = handler(ctx, req)
		return
	}
}

// StreamServerInterceptor returns a gRPC stream server interceptor
// that increments RPCRequestsTotal on stream close (one request per
// stream lifetime). Stream lifetimes are NOT observed in
// RPCDurationSeconds — the histogram is unary-only on purpose; a
// 30-minute matchmaking subscription would dominate the p99 of every
// other RPC.
//
// Panic-tolerant via the same defer pattern as UnaryServerInterceptor.
func (m *Metrics) StreamServerInterceptor() grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) (err error) {
		defer func() {
			if r := recover(); r != nil {
				m.RPCRequestsTotal.WithLabelValues(info.FullMethod, "Internal").Inc()
				panic(r)
			}
			code := status.Code(err).String()
			m.RPCRequestsTotal.WithLabelValues(info.FullMethod, code).Inc()
		}()
		err = handler(srv, ss)
		return
	}
}
