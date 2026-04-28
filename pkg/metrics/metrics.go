// Package metrics provides per-service Prometheus instrumentation:
// counters for RPC calls, errors, AMQP publish/consume events, and
// webhook events; a histogram for unary RPC handling time; and an
// HTTP server that exposes /metrics on :2112 and a /healthz liveness
// probe.
//
// Per the §4.7 spec: bounded-cardinality labels only — method, code,
// routing_key, queue, ack_status. Never user_id / room_id / order_id —
// those would unbounded the cardinality and blow up the TSDB.
package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
)

// Metrics groups all the per-service collectors. Each service builds
// one Metrics with New(serviceName) and uses it for the lifetime of
// the process. The service name is added as a constant label so a
// single Prometheus scrape config can target every service and the
// queries can filter by service= without per-service relabel rules.
type Metrics struct {
	RPCRequestsTotal    *prometheus.CounterVec
	RPCDurationSeconds  *prometheus.HistogramVec
	AMQPPublishesTotal  *prometheus.CounterVec
	AMQPConsumesTotal   *prometheus.CounterVec
	AMQPDispatchedTotal *prometheus.CounterVec
	WebhookEventsTotal  *prometheus.CounterVec

	registry *prometheus.Registry
	service  string
}

// New builds the per-service Metrics. The returned Registry exposes
// only this service's collectors plus the Go runtime / process
// collectors — no global default state, no leaks between tests.
func New(serviceName string) *Metrics {
	reg := prometheus.NewRegistry()
	reg.MustRegister(prometheus.NewGoCollector())
	reg.MustRegister(prometheus.NewProcessCollector(prometheus.ProcessCollectorOpts{}))

	wrapped := prometheus.WrapRegistererWith(prometheus.Labels{"service": serviceName}, reg)

	m := &Metrics{
		registry: reg,
		service:  serviceName,
		RPCRequestsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "rpc_requests_total",
				Help: "Total gRPC requests received, partitioned by method and response code.",
			},
			[]string{"method", "code"},
		),
		RPCDurationSeconds: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name: "rpc_duration_seconds",
				Help: "Unary gRPC handling time in seconds. Streaming RPCs are excluded — their duration is stream lifetime, not per-request, and would skew the histogram.",
				// Buckets tuned for typical RPC times: most calls are
				// 1–50ms, slow tail at 100–500ms, alert beyond 1s.
				Buckets: []float64{0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5},
			},
			[]string{"method", "code"},
		),
		AMQPPublishesTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "amqp_publishes_total",
				Help: "Total AMQP messages published, partitioned by routing key and outcome.",
			},
			[]string{"routing_key", "outcome"},
		),
		AMQPConsumesTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "amqp_consumes_total",
				Help: "Total AMQP messages consumed and dispositioned, partitioned by queue and ack status. Status is one of: ack, nack_requeue, nack_drop.",
			},
			[]string{"queue", "status"},
		),
		AMQPDispatchedTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "amqp_dispatched_total",
				Help: "Total AMQP messages handed to a consumer for processing, partitioned by queue. Counts messages that were dispatched to the per-message handler regardless of whether the handler later acked or nacked. Operators can compute amqp_dispatched_total - amqp_consumes_total per queue to spot handlers that don't disposition properly.",
			},
			[]string{"queue"},
		),
		WebhookEventsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "webhook_events_total",
				Help: "Total webhook events received and dispositioned, partitioned by source and outcome.",
			},
			[]string{"source", "outcome"},
		),
	}

	wrapped.MustRegister(
		m.RPCRequestsTotal,
		m.RPCDurationSeconds,
		m.AMQPPublishesTotal,
		m.AMQPConsumesTotal,
		m.AMQPDispatchedTotal,
		m.WebhookEventsTotal,
	)
	return m
}

// Registry returns the per-service registry for use by an HTTP handler
// (typically promhttp.HandlerFor(reg, ...)). Exposed for serve.go.
func (m *Metrics) Registry() *prometheus.Registry { return m.registry }

// Service returns the constant `service` label value, exposed for
// tests + diagnostic logs.
func (m *Metrics) Service() string { return m.service }

// AMQP outcomes — small enumerated set so cardinality stays bounded.
const (
	OutcomeOK    = "ok"
	OutcomeError = "error"

	StatusAck         = "ack"
	StatusNackRequeue = "nack_requeue"
	StatusNackDrop    = "nack_drop"
)
