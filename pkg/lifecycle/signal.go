// Package lifecycle holds the small helpers each service uses to wire
// SIGTERM / SIGINT into a clean shutdown — drain in-flight gRPC,
// cancel consumer goroutines, close the broker, disconnect Mongo,
// and exit zero.
//
// One helper, intentionally minimal. The actual shutdown sequence is
// per-service because each service's resource graph is different;
// abstracting that into a generic lifecycle.Run hides differences
// that operators need to understand from the source.
package lifecycle

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"quiz-battle/pkg/log"
)

// WaitForSignal blocks until SIGINT (Ctrl-C) or SIGTERM (docker stop,
// k8s preStop, systemd) arrives, or until ctx is cancelled. Returns
// the signal that was received, or nil if ctx was cancelled first.
//
// Usage:
//
//	ctx, cancel := context.WithCancel(context.Background())
//	defer cancel()
//	// ... start gRPC server in goroutine, start consumers ...
//	lifecycle.WaitForSignal(ctx)
//	cancel() // tell consumers to stop
//	grpcServer.GracefulStop()
//	// ... close AMQP / Mongo / metrics HTTP server ...
func WaitForSignal(ctx context.Context) os.Signal {
	return waitForSignals(ctx, os.Interrupt, syscall.SIGTERM)
}

// waitForSignals is the internal helper exposed for tests so they can
// register a non-default signal (e.g. SIGUSR1) without killing the
// test binary the way an unhandled SIGTERM would.
func waitForSignals(ctx context.Context, signals ...os.Signal) os.Signal {
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, signals...)
	defer signal.Stop(sigs)

	select {
	case sig := <-sigs:
		log.FromContext(ctx).Info("shutdown signal received", "signal", sig.String())
		return sig
	case <-ctx.Done():
		log.FromContext(ctx).Info("ctx cancelled before signal")
		return nil
	}
}
