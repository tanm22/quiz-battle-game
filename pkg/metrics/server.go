package metrics

import (
	"context"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	"quiz-battle/pkg/log"
)

// Serve starts an HTTP server on addr (typically ":2112") that exposes
// /metrics for Prometheus scraping and /healthz as a liveness probe.
// Returns the *http.Server so the caller can shut it down gracefully
// during process shutdown (PR-C1).
//
// The /healthz endpoint deliberately returns 200 if the process is
// running. It does NOT check Mongo/Redis/RabbitMQ liveness — that is
// readiness, a separate concern, and overloading /healthz with
// dependency checks creates restart storms when one dep blips.
func (m *Metrics) Serve(ctx context.Context, addr string) *http.Server {
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.HandlerFor(m.registry, promhttp.HandlerOpts{
		// EnableOpenMetrics produces the OpenMetrics text format
		// alongside the legacy Prometheus format — modern Prometheus
		// servers prefer this; older ones still accept the legacy fallback.
		EnableOpenMetrics: true,
	}))
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.FromContext(ctx).Info("metrics serving", "addr", addr, "service", m.service)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.FromContext(ctx).Error("metrics server failed", "addr", addr, "err", err)
		}
	}()

	return srv
}
