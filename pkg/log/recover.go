package log

import (
	"context"
	"runtime/debug"
)

// RecoverPanic is the canonical defer'd panic guard for any goroutine or
// callback the service spawns. Used at the entry of long-lived workers
// (RabbitMQ consumers, time.AfterFunc callbacks, the TimerSync ticker)
// so an unexpected panic — nil-map deref, type-assertion failure, slice
// out-of-bounds — logs a structured error and lets the goroutine exit
// cleanly instead of crashing the entire service process.
//
// Usage:
//
//	go func() {
//	    defer log.RecoverPanic(ctx, "TimerSync")
//	    // ... work that may panic ...
//	}()
//
// `where` identifies the goroutine in logs (e.g. "closeRound",
// "consumeAnswer", "TimerSync"). The stack trace is captured at recovery
// time, not at panic time, so the trace points at the recover frame —
// the panic value (`r`) plus the stack together pinpoint the offending
// line because debug.Stack walks the still-active goroutine stack
// inside the defer.
func RecoverPanic(ctx context.Context, where string) {
	if r := recover(); r != nil {
		FromContext(ctx).Error("panic recovered",
			"where", where,
			"panic", r,
			"stack", string(debug.Stack()))
	}
}
