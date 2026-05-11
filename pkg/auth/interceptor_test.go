package auth

import (
	"context"
	"errors"
	"testing"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

const testSecret = "interceptor-test-secret"

// noopHandler is the gRPC handler stub used in every interceptor test.
// It records the context it was called with so assertions can verify
// that the interceptor injected claims correctly.
type noopHandler struct {
	called  bool
	gotCtx  context.Context
	gotResp interface{}
}

func (h *noopHandler) handle(ctx context.Context, req interface{}) (interface{}, error) {
	h.called = true
	h.gotCtx = ctx
	h.gotResp = "ok"
	return "ok", nil
}

// fakeStream is the minimal grpc.ServerStream the StreamInterceptor
// wraps. We only care that Context() returns what the interceptor
// installed, so the rest of the interface is left to default panics.
type fakeStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (s *fakeStream) Context() context.Context { return s.ctx }

// authMD builds a gRPC incoming context with a Bearer token attached.
func authMD(token string) context.Context {
	md := metadata.Pairs("authorization", "Bearer "+token)
	return metadata.NewIncomingContext(context.Background(), md)
}

func TestUnaryInterceptor_ValidTokenPassesThroughWithClaims(t *testing.T) {
	tok, err := GenerateToken("u-1", "alice", testSecret)
	if err != nil {
		t.Fatalf("generate: %v", err)
	}
	h := &noopHandler{}
	interceptor := UnaryInterceptor(testSecret, nil)

	_, err = interceptor(authMD(tok), nil, &grpc.UnaryServerInfo{FullMethod: "/quiz.AuthService/GetProfile"}, h.handle)
	if err != nil {
		t.Fatalf("interceptor rejected valid token: %v", err)
	}
	if !h.called {
		t.Fatal("handler was never invoked despite valid token")
	}
	uid, err := UserIDFromContext(h.gotCtx)
	if err != nil || uid != "u-1" {
		t.Errorf("user id in handler context: want u-1, got %q (err=%v)", uid, err)
	}
}

func TestUnaryInterceptor_MissingMetadataRejected(t *testing.T) {
	h := &noopHandler{}
	interceptor := UnaryInterceptor(testSecret, nil)

	_, err := interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: "/x.Y/Z"}, h.handle)
	if err == nil {
		t.Fatal("interceptor accepted call with no metadata")
	}
	if got := status.Code(err); got != codes.Unauthenticated {
		t.Errorf("want Unauthenticated, got %v", got)
	}
	if h.called {
		t.Error("handler was invoked despite missing metadata")
	}
}

func TestUnaryInterceptor_MissingAuthHeaderRejected(t *testing.T) {
	// Metadata present, but no `authorization` key.
	ctx := metadata.NewIncomingContext(context.Background(), metadata.Pairs("x-other", "v"))
	h := &noopHandler{}
	interceptor := UnaryInterceptor(testSecret, nil)

	_, err := interceptor(ctx, nil, &grpc.UnaryServerInfo{FullMethod: "/x.Y/Z"}, h.handle)
	if err == nil {
		t.Fatal("interceptor accepted call without authorization header")
	}
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("want Unauthenticated, got %v", status.Code(err))
	}
}

func TestUnaryInterceptor_BadTokenRejected(t *testing.T) {
	h := &noopHandler{}
	interceptor := UnaryInterceptor(testSecret, nil)

	_, err := interceptor(authMD("not-a-real-jwt"), nil, &grpc.UnaryServerInfo{FullMethod: "/x.Y/Z"}, h.handle)
	if err == nil {
		t.Fatal("interceptor accepted garbage token")
	}
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("want Unauthenticated, got %v", status.Code(err))
	}
	if h.called {
		t.Error("handler was invoked despite bad token")
	}
}

func TestUnaryInterceptor_WrongSecretRejected(t *testing.T) {
	tok, err := GenerateToken("u-1", "alice", "different-secret")
	if err != nil {
		t.Fatalf("generate: %v", err)
	}
	h := &noopHandler{}
	interceptor := UnaryInterceptor(testSecret, nil)

	_, err = interceptor(authMD(tok), nil, &grpc.UnaryServerInfo{FullMethod: "/x.Y/Z"}, h.handle)
	if err == nil {
		t.Fatal("interceptor accepted token signed with wrong secret")
	}
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("want Unauthenticated, got %v", status.Code(err))
	}
}

func TestUnaryInterceptor_SkipListBypassesAuth(t *testing.T) {
	// Methods on the skip list (e.g. Register, Login, GuestLogin) must
	// be invokable without any auth metadata at all.
	const method = "/quiz.AuthService/Register"
	h := &noopHandler{}
	interceptor := UnaryInterceptor(testSecret, []string{method})

	_, err := interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: method}, h.handle)
	if err != nil {
		t.Fatalf("interceptor rejected skip-listed method: %v", err)
	}
	if !h.called {
		t.Fatal("handler not called for skip-listed method")
	}
	// Skip-listed handlers don't get a user-ID context — verify the
	// extractor errors so handlers know to treat the caller as anonymous.
	if _, err := UserIDFromContext(h.gotCtx); err == nil {
		t.Error("user id was populated on skip-listed call; should be anonymous")
	}
}

func TestUnaryInterceptor_SkipListDoesNotBypassOtherMethods(t *testing.T) {
	// Register is skip-listed, but GetProfile is not. Calling GetProfile
	// without auth must still be rejected — the skip set is per-method,
	// not per-service.
	h := &noopHandler{}
	interceptor := UnaryInterceptor(testSecret, []string{"/quiz.AuthService/Register"})

	_, err := interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: "/quiz.AuthService/GetProfile"}, h.handle)
	if err == nil {
		t.Fatal("interceptor bypassed auth for non-skip-listed method")
	}
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("want Unauthenticated, got %v", status.Code(err))
	}
	if h.called {
		t.Error("handler was invoked for non-skip-listed method without auth")
	}
}

func TestStreamInterceptor_ValidTokenPassesThroughWithClaims(t *testing.T) {
	tok, err := GenerateToken("u-stream", "carol", testSecret)
	if err != nil {
		t.Fatalf("generate: %v", err)
	}
	stream := &fakeStream{ctx: authMD(tok)}
	interceptor := StreamInterceptor(testSecret, nil)

	var seenCtx context.Context
	handler := func(srv interface{}, ss grpc.ServerStream) error {
		seenCtx = ss.Context()
		return nil
	}

	err = interceptor(nil, stream, &grpc.StreamServerInfo{FullMethod: "/quiz.QuizService/StreamGameEvents"}, handler)
	if err != nil {
		t.Fatalf("stream interceptor rejected valid token: %v", err)
	}
	uid, err := UserIDFromContext(seenCtx)
	if err != nil || uid != "u-stream" {
		t.Errorf("user id in handler ctx: want u-stream, got %q (err=%v)", uid, err)
	}
}

func TestStreamInterceptor_MissingTokenRejected(t *testing.T) {
	stream := &fakeStream{ctx: context.Background()}
	interceptor := StreamInterceptor(testSecret, nil)
	called := false
	handler := func(srv interface{}, ss grpc.ServerStream) error {
		called = true
		return nil
	}
	err := interceptor(nil, stream, &grpc.StreamServerInfo{FullMethod: "/x.Y/Z"}, handler)
	if err == nil {
		t.Fatal("stream interceptor accepted call with no metadata")
	}
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("want Unauthenticated, got %v", status.Code(err))
	}
	if called {
		t.Error("stream handler invoked despite missing auth")
	}
}

// TestUnaryInterceptor_BareTokenWithoutBearerAccepted documents the
// (slightly lenient) behaviour where the interceptor accepts both
// "Bearer <token>" and "<token>" forms. Some test harnesses send the
// raw token; the production Flutter client always sends Bearer.
func TestUnaryInterceptor_BareTokenWithoutBearerAccepted(t *testing.T) {
	tok, err := GenerateToken("u-1", "alice", testSecret)
	if err != nil {
		t.Fatalf("generate: %v", err)
	}
	ctx := metadata.NewIncomingContext(context.Background(), metadata.Pairs("authorization", tok))
	h := &noopHandler{}
	interceptor := UnaryInterceptor(testSecret, nil)
	if _, err := interceptor(ctx, nil, &grpc.UnaryServerInfo{FullMethod: "/x.Y/Z"}, h.handle); err != nil {
		t.Fatalf("bare token rejected (regression — handler logic depends on this leniency): %v", err)
	}
	if !h.called {
		t.Fatal("handler not invoked for bare token")
	}
}

// sanity: the test secret never accidentally matches an empty secret
// path (which would mask real failures).
func init() {
	if testSecret == "" {
		panic(errors.New("test secret must be non-empty"))
	}
}
