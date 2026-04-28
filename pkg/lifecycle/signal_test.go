package lifecycle

import (
	"context"
	"os"
	"syscall"
	"testing"
	"time"
)

// We test with SIGUSR1 rather than SIGTERM. The test binary's default
// SIGTERM action is "terminate the process", and there's an unavoidable
// race between the goroutine reaching signal.Notify and the kill
// arriving — if the kill wins, the test process dies. SIGUSR1 has no
// default action that affects the test binary, so it's safe.

func TestWaitForSignal_ReturnsOnSignal(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	got := make(chan os.Signal, 1)
	go func() {
		got <- waitForSignals(ctx, syscall.SIGUSR1)
	}()

	// Give the goroutine time to register the handler before the kill.
	time.Sleep(50 * time.Millisecond)

	if err := syscall.Kill(syscall.Getpid(), syscall.SIGUSR1); err != nil {
		t.Fatalf("kill: %v", err)
	}

	select {
	case sig := <-got:
		if sig != syscall.SIGUSR1 {
			t.Errorf("expected SIGUSR1, got %v", sig)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("waitForSignals never returned")
	}
}

func TestWaitForSignal_ReturnsNilOnCtxCancel(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())

	got := make(chan os.Signal, 1)
	go func() {
		got <- waitForSignals(ctx, syscall.SIGUSR1)
	}()

	cancel()

	select {
	case sig := <-got:
		if sig != nil {
			t.Errorf("expected nil from ctx cancel, got %v", sig)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("waitForSignals never returned after ctx cancel")
	}
}

func TestWaitForSignal_HandlerStopsAfterReturn(t *testing.T) {
	// Verify back-to-back invocations both return cleanly. If
	// signal.Stop didn't fire on the first invocation, the second
	// goroutine's signal.Notify on the same channel could deadlock or
	// double-receive. Three iterations is enough to surface either.
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	for i := 0; i < 3; i++ {
		done := make(chan os.Signal, 1)
		go func() { done <- waitForSignals(ctx, syscall.SIGUSR1) }()
		time.Sleep(50 * time.Millisecond)
		if err := syscall.Kill(syscall.Getpid(), syscall.SIGUSR1); err != nil {
			t.Fatalf("kill iteration %d: %v", i, err)
		}
		select {
		case <-done:
		case <-time.After(2 * time.Second):
			t.Fatalf("iteration %d: did not return", i)
		}
	}
}
