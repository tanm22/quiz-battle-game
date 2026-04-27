package log

import (
	"context"
	"os"
)

// origExit is the default exit function captured at package init. Tests can
// restore it after swapping exitFn during a test.
var origExit = os.Exit

// exitFn is the function Fatal calls to terminate the process. Tests
// override this to assert on exit codes without actually exiting. Production
// callers never touch it.
var exitFn = origExit

// Fatal logs msg at ERROR level via FromContext(ctx) — so the request_id is
// attached when present — then terminates the process with exit code 1.
//
// args follows slog's variadic key-value pattern: Fatal(ctx, "msg", "err",
// err, "host", host) emits {msg, err, host} as JSON attributes. Odd-numbered
// arg counts silently degrade to slog's `!BADKEY` placeholder, so always
// pass key/value pairs.
//
// Note: os.Exit skips deferred functions. Any defers registered before this
// call (mongo.Disconnect, amqp.Close, etc.) will not run — close resources
// explicitly first if cleanup matters, or return an error and let main()
// unwind normally.
//
// Use this for unrecoverable startup errors. Do NOT use it inside RPC
// handlers — return an error instead so the gRPC layer can surface a
// proper status code to the client.
func Fatal(ctx context.Context, msg string, args ...any) {
	FromContext(ctx).Error(msg, args...)
	exitFn(1)
}
