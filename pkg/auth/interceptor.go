package auth

import (
	"context"
	"strings"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// UnaryInterceptor returns a gRPC unary interceptor that verifies JWT tokens.
// Methods listed in skipMethods bypass authentication (e.g., Register, Login).
func UnaryInterceptor(secret string, skipMethods []string) grpc.UnaryServerInterceptor {
	skip := make(map[string]bool, len(skipMethods))
	for _, m := range skipMethods {
		skip[m] = true
	}

	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
		if skip[info.FullMethod] {
			return handler(ctx, req)
		}

		claims, err := extractClaims(ctx, secret)
		if err != nil {
			return nil, status.Errorf(codes.Unauthenticated, "auth: %v", err)
		}

		return handler(ContextWithClaims(ctx, claims), req)
	}
}

// StreamInterceptor returns a gRPC stream interceptor that verifies JWT tokens.
func StreamInterceptor(secret string, skipMethods []string) grpc.StreamServerInterceptor {
	skip := make(map[string]bool, len(skipMethods))
	for _, m := range skipMethods {
		skip[m] = true
	}

	return func(srv interface{}, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		if skip[info.FullMethod] {
			return handler(srv, ss)
		}

		claims, err := extractClaims(ss.Context(), secret)
		if err != nil {
			return status.Errorf(codes.Unauthenticated, "auth: %v", err)
		}

		return handler(srv, &wrappedStream{ServerStream: ss, ctx: ContextWithClaims(ss.Context(), claims)})
	}
}

// extractClaims pulls the Bearer token from gRPC metadata and verifies it.
func extractClaims(ctx context.Context, secret string) (*Claims, error) {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing metadata")
	}

	vals := md.Get("authorization")
	if len(vals) == 0 {
		return nil, status.Error(codes.Unauthenticated, "missing authorization header")
	}

	token := vals[0]
	if strings.HasPrefix(token, "Bearer ") {
		token = token[7:]
	}

	return VerifyToken(token, secret)
}

// wrappedStream overrides Context() to return the authenticated context.
type wrappedStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (w *wrappedStream) Context() context.Context {
	return w.ctx
}
