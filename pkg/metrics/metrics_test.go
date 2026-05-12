package metrics

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestNewRegistersAllCollectors(t *testing.T) {
	m := New("test-svc")

	// Counter / histogram / gauge vectors don't appear in Gather() output
	// until at least one label combination has been observed — that's a
	// client_golang invariant, not a bug in registration. Touch each
	// vector once with a sentinel label set so the family shows up.
	m.RPCRequestsTotal.WithLabelValues("/probe", "OK").Inc()
	m.RPCDurationSeconds.WithLabelValues("/probe", "OK").Observe(0)
	m.AMQPPublishesTotal.WithLabelValues("probe", OutcomeOK).Inc()
	m.AMQPConsumesTotal.WithLabelValues("probe", StatusAck).Inc()
	m.AMQPDispatchedTotal.WithLabelValues("probe").Inc()
	m.WebhookEventsTotal.WithLabelValues("probe", OutcomeOK).Inc()
	m.OutboxPendingTotal.WithLabelValues("test").Set(0)
	m.OutboxOldestAgeSeconds.WithLabelValues("test").Set(0)

	mfs, err := m.Registry().Gather()
	if err != nil {
		t.Fatalf("gather: %v", err)
	}

	want := map[string]bool{
		"rpc_requests_total":        false,
		"rpc_duration_seconds":      false,
		"amqp_publishes_total":      false,
		"amqp_consumes_total":       false,
		"amqp_dispatched_total":     false,
		"webhook_events_total":      false,
		"outbox_pending_total":      false,
		"outbox_oldest_age_seconds": false,
	}
	for _, mf := range mfs {
		if _, ok := want[mf.GetName()]; ok {
			want[mf.GetName()] = true
		}
	}
	for name, found := range want {
		if !found {
			t.Errorf("metric %q missing from registry", name)
		}
	}
}

func TestServiceLabelAttached(t *testing.T) {
	m := New("auth")
	m.RPCRequestsTotal.WithLabelValues("/x/Y", "OK").Inc()

	mfs, err := m.Registry().Gather()
	if err != nil {
		t.Fatalf("gather: %v", err)
	}

	for _, mf := range mfs {
		if mf.GetName() != "rpc_requests_total" {
			continue
		}
		for _, sample := range mf.GetMetric() {
			labels := sample.GetLabel()
			gotService := ""
			for _, l := range labels {
				if l.GetName() == "service" {
					gotService = l.GetValue()
				}
			}
			if gotService != "auth" {
				t.Errorf("expected service=auth label, got %q", gotService)
			}
			return
		}
	}
	t.Fatal("rpc_requests_total not found in registry output")
}

func TestUnaryServerInterceptor_RecordsCounterAndHistogram(t *testing.T) {
	m := New("test")
	interceptor := m.UnaryServerInterceptor()

	handler := func(ctx context.Context, req any) (any, error) {
		time.Sleep(2 * time.Millisecond)
		return "ok", nil
	}

	for i := 0; i < 3; i++ {
		_, _ = interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: "/svc/Method"}, handler)
	}

	got := testutil.ToFloat64(m.RPCRequestsTotal.WithLabelValues("/svc/Method", "OK"))
	if got != 3 {
		t.Errorf("counter = %v, want 3", got)
	}
	if c := testutil.CollectAndCount(m.RPCDurationSeconds, "rpc_duration_seconds"); c == 0 {
		t.Errorf("histogram not observed")
	}
}

func TestUnaryServerInterceptor_RecordsErrorCode(t *testing.T) {
	m := New("test")
	interceptor := m.UnaryServerInterceptor()

	handler := func(ctx context.Context, req any) (any, error) {
		return nil, status.Error(codes.PermissionDenied, "no")
	}
	_, _ = interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: "/svc/Method"}, handler)

	got := testutil.ToFloat64(m.RPCRequestsTotal.WithLabelValues("/svc/Method", "PermissionDenied"))
	if got != 1 {
		t.Errorf("counter for PermissionDenied = %v, want 1", got)
	}
}

type fakeServerStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (f *fakeServerStream) Context() context.Context { return f.ctx }

func TestStreamServerInterceptor_RecordsOnClose(t *testing.T) {
	m := New("test")
	interceptor := m.StreamServerInterceptor()

	handler := func(srv any, ss grpc.ServerStream) error { return nil }
	_ = interceptor(nil, &fakeServerStream{ctx: context.Background()}, &grpc.StreamServerInfo{FullMethod: "/svc/Stream"}, handler)

	got := testutil.ToFloat64(m.RPCRequestsTotal.WithLabelValues("/svc/Stream", "OK"))
	if got != 1 {
		t.Errorf("counter = %v, want 1", got)
	}
}

func TestRecordPublish(t *testing.T) {
	m := New("test")
	m.RecordPublish("match.created", nil)
	m.RecordPublish("match.created", errors.New("boom"))
	m.RecordPublish("match.finished", nil)

	if got := testutil.ToFloat64(m.AMQPPublishesTotal.WithLabelValues("match.created", OutcomeOK)); got != 1 {
		t.Errorf("ok counter = %v, want 1", got)
	}
	if got := testutil.ToFloat64(m.AMQPPublishesTotal.WithLabelValues("match.created", OutcomeError)); got != 1 {
		t.Errorf("error counter = %v, want 1", got)
	}
	if got := testutil.ToFloat64(m.AMQPPublishesTotal.WithLabelValues("match.finished", OutcomeOK)); got != 1 {
		t.Errorf("finished counter = %v, want 1", got)
	}
}

func TestRecordConsume(t *testing.T) {
	m := New("test")
	m.RecordConsume("answer-processing-queue", StatusAck)
	m.RecordConsume("answer-processing-queue", StatusAck)
	m.RecordConsume("answer-processing-queue", StatusNackRequeue)
	m.RecordConsume("coin-earn-queue", StatusNackDrop)

	if got := testutil.ToFloat64(m.AMQPConsumesTotal.WithLabelValues("answer-processing-queue", StatusAck)); got != 2 {
		t.Errorf("ack = %v, want 2", got)
	}
	if got := testutil.ToFloat64(m.AMQPConsumesTotal.WithLabelValues("answer-processing-queue", StatusNackRequeue)); got != 1 {
		t.Errorf("nack_requeue = %v, want 1", got)
	}
	if got := testutil.ToFloat64(m.AMQPConsumesTotal.WithLabelValues("coin-earn-queue", StatusNackDrop)); got != 1 {
		t.Errorf("nack_drop = %v, want 1", got)
	}
}

func TestRecordWebhook(t *testing.T) {
	m := New("test")
	m.RecordWebhook("razorpay", nil)
	m.RecordWebhook("razorpay", errors.New("sig mismatch"))

	if got := testutil.ToFloat64(m.WebhookEventsTotal.WithLabelValues("razorpay", OutcomeOK)); got != 1 {
		t.Errorf("ok = %v, want 1", got)
	}
	if got := testutil.ToFloat64(m.WebhookEventsTotal.WithLabelValues("razorpay", OutcomeError)); got != 1 {
		t.Errorf("error = %v, want 1", got)
	}
}

func TestHandlerExposesEndpoints(t *testing.T) {
	m := New("test")
	// Touch one counter so /metrics has at least one observation of
	// our custom families to assert on.
	m.RPCRequestsTotal.WithLabelValues("/probe", "OK").Inc()

	// Drive the production handler directly. A future change to
	// Handler() — different mux path, different promhttp options — is
	// caught by this test because we exercise the real method, not a
	// hand-rolled near-clone.
	srv := httptest.NewServer(m.Handler())
	defer srv.Close()

	// /metrics must respond with the Prometheus text format and contain
	// our counter family names.
	resp, err := http.Get(srv.URL + "/metrics")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		t.Errorf("metrics status = %d", resp.StatusCode)
	}
	body, _ := io.ReadAll(resp.Body)
	if !strings.Contains(string(body), "rpc_requests_total") {
		t.Errorf("metrics body missing rpc_requests_total: %s", body)
	}

	// /healthz must respond 200 ok.
	resp2, err := http.Get(srv.URL + "/healthz")
	if err != nil {
		t.Fatal(err)
	}
	defer resp2.Body.Close()
	if resp2.StatusCode != 200 {
		t.Errorf("healthz status = %d", resp2.StatusCode)
	}
}

func TestRecordDispatched(t *testing.T) {
	m := New("test")
	m.RecordDispatched("answer-processing-queue")
	m.RecordDispatched("answer-processing-queue")
	m.RecordDispatched("match-finished-queue")

	if got := testutil.ToFloat64(m.AMQPDispatchedTotal.WithLabelValues("answer-processing-queue")); got != 2 {
		t.Errorf("answer-processing-queue dispatched = %v, want 2", got)
	}
	if got := testutil.ToFloat64(m.AMQPDispatchedTotal.WithLabelValues("match-finished-queue")); got != 1 {
		t.Errorf("match-finished-queue dispatched = %v, want 1", got)
	}
}

func TestUnaryServerInterceptor_RecordsPanicAsInternal(t *testing.T) {
	m := New("test")
	interceptor := m.UnaryServerInterceptor()

	handler := func(ctx context.Context, req any) (any, error) {
		panic("boom")
	}

	// The interceptor re-panics so an outer recover (typically pkg/log)
	// can convert to a status error. The test wraps the call in its own
	// recover so the test process doesn't die.
	func() {
		defer func() {
			if r := recover(); r == nil {
				t.Fatal("expected panic to be re-raised so outer interceptors can recover")
			}
		}()
		_, _ = interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: "/svc/Method"}, handler)
	}()

	if got := testutil.ToFloat64(m.RPCRequestsTotal.WithLabelValues("/svc/Method", "Internal")); got != 1 {
		t.Errorf("counter for panic = %v, want 1 with code=Internal", got)
	}
	if c := testutil.CollectAndCount(m.RPCDurationSeconds, "rpc_duration_seconds"); c == 0 {
		t.Errorf("histogram should record panic duration, got 0 observations")
	}
}

func TestStreamServerInterceptor_RecordsPanicAsInternal(t *testing.T) {
	m := New("test")
	interceptor := m.StreamServerInterceptor()

	handler := func(srv any, ss grpc.ServerStream) error {
		panic("stream boom")
	}

	func() {
		defer func() {
			if r := recover(); r == nil {
				t.Fatal("expected panic to be re-raised so outer interceptors can recover")
			}
		}()
		_ = interceptor(nil, &fakeServerStream{ctx: context.Background()}, &grpc.StreamServerInfo{FullMethod: "/svc/Stream"}, handler)
	}()

	if got := testutil.ToFloat64(m.RPCRequestsTotal.WithLabelValues("/svc/Stream", "Internal")); got != 1 {
		t.Errorf("stream panic counter = %v, want 1", got)
	}
}

func TestNewIsolatesRegistries(t *testing.T) {
	// Two services in the same process must not share a registry —
	// otherwise their counters would collide on the same name.
	a := New("a")
	b := New("b")
	if a.Registry() == b.Registry() {
		t.Error("registries must be distinct per service instance")
	}

	// And the global default registry should not have our counters.
	for _, mf := range mustGather(t, prometheus.DefaultGatherer) {
		switch mf.GetName() {
		case "rpc_requests_total", "rpc_duration_seconds", "amqp_publishes_total":
			t.Errorf("collector %q leaked into prometheus.DefaultGatherer", mf.GetName())
		}
	}
}

func mustGather(t *testing.T, g prometheus.Gatherer) []*ioPrometheusClientMetricFamilyShim {
	t.Helper()
	mfs, err := g.Gather()
	if err != nil {
		t.Fatalf("gather: %v", err)
	}
	out := make([]*ioPrometheusClientMetricFamilyShim, 0, len(mfs))
	for _, mf := range mfs {
		out = append(out, &ioPrometheusClientMetricFamilyShim{name: mf.GetName()})
	}
	return out
}

// Tiny shim so the test doesn't need to import the dto package.
type ioPrometheusClientMetricFamilyShim struct{ name string }

func (s *ioPrometheusClientMetricFamilyShim) GetName() string { return s.name }
