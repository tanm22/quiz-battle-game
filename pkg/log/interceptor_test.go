package log

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"strings"
	"testing"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

func newTestLogger(t *testing.T) *bytes.Buffer {
	t.Helper()
	var buf bytes.Buffer
	prev := slog.Default()
	t.Cleanup(func() { slog.SetDefault(prev) })
	slog.SetDefault(newLogger("test", slog.LevelDebug, &buf))
	return &buf
}

func decodeLines(t *testing.T, buf *bytes.Buffer) []map[string]any {
	t.Helper()
	var out []map[string]any
	for _, line := range strings.Split(strings.TrimRight(buf.String(), "\n"), "\n") {
		if line == "" {
			continue
		}
		var m map[string]any
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			t.Fatalf("not JSON: %v\n%s", err, line)
		}
		out = append(out, m)
	}
	return out
}

func TestUnaryServerInterceptor_GeneratesRequestIDWhenMissing(t *testing.T) {
	buf := newTestLogger(t)
	interceptor := UnaryServerInterceptor()

	var observedRID string
	handler := func(ctx context.Context, req any) (any, error) {
		observedRID = RequestIDFromContext(ctx)
		return "ok", nil
	}

	resp, err := interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: "/test.Service/Method"}, handler)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp != "ok" {
		t.Errorf("resp = %v, want ok", resp)
	}
	if observedRID == "" {
		t.Error("handler did not receive a request_id on ctx")
	}

	lines := decodeLines(t, buf)
	if len(lines) != 1 {
		t.Fatalf("expected 1 log line, got %d", len(lines))
	}
	if lines[0]["msg"] != "rpc finished" {
		t.Errorf("msg = %v", lines[0]["msg"])
	}
	if lines[0]["request_id"] != observedRID {
		t.Errorf("log request_id = %v, handler saw %v", lines[0]["request_id"], observedRID)
	}
	if lines[0]["code"] != "OK" {
		t.Errorf("code = %v, want OK", lines[0]["code"])
	}
}

func TestUnaryServerInterceptor_PreservesInboundRequestID(t *testing.T) {
	buf := newTestLogger(t)
	interceptor := UnaryServerInterceptor()

	md := metadata.Pairs(RequestIDMetadataKey, "rid-from-upstream")
	ctx := metadata.NewIncomingContext(context.Background(), md)

	var observedRID string
	handler := func(ctx context.Context, req any) (any, error) {
		observedRID = RequestIDFromContext(ctx)
		return nil, nil
	}

	if _, err := interceptor(ctx, nil, &grpc.UnaryServerInfo{FullMethod: "/test/M"}, handler); err != nil {
		t.Fatal(err)
	}
	if observedRID != "rid-from-upstream" {
		t.Errorf("request_id = %q, want rid-from-upstream", observedRID)
	}
	lines := decodeLines(t, buf)
	if lines[0]["request_id"] != "rid-from-upstream" {
		t.Errorf("log request_id = %v", lines[0]["request_id"])
	}
}

func TestUnaryServerInterceptor_LogsErrorCode(t *testing.T) {
	buf := newTestLogger(t)
	interceptor := UnaryServerInterceptor()

	handler := func(ctx context.Context, req any) (any, error) {
		return nil, status.Error(codes.NotFound, "missing")
	}
	_, err := interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: "/test/M"}, handler)
	if status.Code(err) != codes.NotFound {
		t.Fatalf("err = %v, want NotFound", err)
	}
	lines := decodeLines(t, buf)
	if lines[0]["code"] != "NotFound" {
		t.Errorf("code = %v, want NotFound", lines[0]["code"])
	}
}

func TestUnaryServerInterceptor_RecoversPanic(t *testing.T) {
	buf := newTestLogger(t)
	interceptor := UnaryServerInterceptor()

	handler := func(ctx context.Context, req any) (any, error) {
		panic("boom")
	}
	_, err := interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: "/test/M"}, handler)
	if status.Code(err) != codes.Internal {
		t.Fatalf("err = %v, want Internal", err)
	}
	lines := decodeLines(t, buf)
	if len(lines) != 1 {
		t.Fatalf("expected 1 log line (the panic), got %d", len(lines))
	}
	if lines[0]["msg"] != "rpc panic recovered" {
		t.Errorf("msg = %v", lines[0]["msg"])
	}
}

func TestUnaryClientInterceptor_PropagatesRequestID(t *testing.T) {
	interceptor := UnaryClientInterceptor()
	ctx := ContextWithRequestID(context.Background(), "rid-client")

	var observed string
	invoker := func(ctx context.Context, method string, req, reply any, cc *grpc.ClientConn, opts ...grpc.CallOption) error {
		md, _ := metadata.FromOutgoingContext(ctx)
		if vals := md.Get(RequestIDMetadataKey); len(vals) > 0 {
			observed = vals[0]
		}
		return nil
	}
	if err := interceptor(ctx, "/test/M", nil, nil, nil, invoker); err != nil {
		t.Fatal(err)
	}
	if observed != "rid-client" {
		t.Errorf("outgoing request_id = %q, want rid-client", observed)
	}
}

func TestUnaryClientInterceptor_NoopWhenCtxLacksID(t *testing.T) {
	interceptor := UnaryClientInterceptor()

	invoker := func(ctx context.Context, method string, req, reply any, cc *grpc.ClientConn, opts ...grpc.CallOption) error {
		md, _ := metadata.FromOutgoingContext(ctx)
		if vals := md.Get(RequestIDMetadataKey); len(vals) > 0 {
			t.Errorf("expected no x-request-id metadata, got %v", vals)
		}
		return nil
	}
	if err := interceptor(context.Background(), "/test/M", nil, nil, nil, invoker); err != nil {
		t.Fatal(err)
	}
}

// fakeServerStream lets stream-interceptor tests exercise wrappedStream
// without spinning up a real gRPC server.
type fakeServerStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (f *fakeServerStream) Context() context.Context { return f.ctx }

func TestStreamServerInterceptor_GeneratesRequestID(t *testing.T) {
	buf := newTestLogger(t)
	interceptor := StreamServerInterceptor()

	var observed string
	handler := func(srv any, ss grpc.ServerStream) error {
		observed = RequestIDFromContext(ss.Context())
		return nil
	}
	ss := &fakeServerStream{ctx: context.Background()}
	if err := interceptor(nil, ss, &grpc.StreamServerInfo{FullMethod: "/test/Stream"}, handler); err != nil {
		t.Fatal(err)
	}
	if observed == "" {
		t.Error("stream handler did not see a request_id")
	}
	lines := decodeLines(t, buf)
	if lines[0]["msg"] != "stream closed" {
		t.Errorf("msg = %v", lines[0]["msg"])
	}
}

func TestStreamServerInterceptor_LogsHandlerError(t *testing.T) {
	buf := newTestLogger(t)
	interceptor := StreamServerInterceptor()

	handler := func(srv any, ss grpc.ServerStream) error {
		return status.Error(codes.Aborted, "client gone")
	}
	ss := &fakeServerStream{ctx: context.Background()}
	err := interceptor(nil, ss, &grpc.StreamServerInfo{FullMethod: "/test/Stream"}, handler)
	if status.Code(err) != codes.Aborted {
		t.Fatalf("err = %v", err)
	}
	lines := decodeLines(t, buf)
	if lines[0]["code"] != "Aborted" {
		t.Errorf("code = %v, want Aborted", lines[0]["code"])
	}
}

func TestEnsureRequestID_DoesNotOverwriteCtxValue(t *testing.T) {
	ctx := ContextWithRequestID(context.Background(), "rid-existing")
	out := ensureRequestID(ctx)
	if RequestIDFromContext(out) != "rid-existing" {
		t.Errorf("ensureRequestID overwrote existing rid")
	}
}

func TestUnaryServerInterceptor_HandlerErrorOtherThanStatus(t *testing.T) {
	buf := newTestLogger(t)
	interceptor := UnaryServerInterceptor()

	handler := func(ctx context.Context, req any) (any, error) {
		return nil, errors.New("plain error")
	}
	_, err := interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: "/test/M"}, handler)
	if err == nil {
		t.Fatal("expected error to propagate")
	}
	// status.Code on a plain error returns Unknown.
	lines := decodeLines(t, buf)
	if lines[0]["code"] != "Unknown" {
		t.Errorf("code = %v, want Unknown for plain error", lines[0]["code"])
	}
}
