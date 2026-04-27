package log

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"testing"
)

func TestFatalLogsAndExits(t *testing.T) {
	var buf bytes.Buffer
	prevDefault := slog.Default()
	t.Cleanup(func() { slog.SetDefault(prevDefault) })
	slog.SetDefault(newLogger("test", slog.LevelDebug, &buf))

	var capturedCode int
	prev := exitFn
	exitFn = func(code int) { capturedCode = code }
	t.Cleanup(func() { exitFn = prev })

	Fatal(context.Background(), "redis connect failed", "err", "dial tcp: refused")

	if capturedCode != 1 {
		t.Errorf("exit code = %d, want 1", capturedCode)
	}
	var out map[string]any
	if err := json.Unmarshal(buf.Bytes(), &out); err != nil {
		t.Fatalf("output not JSON: %v\n%s", err, buf.String())
	}
	if out["level"] != "ERROR" {
		t.Errorf("level = %v, want ERROR", out["level"])
	}
	if out["msg"] != "redis connect failed" {
		t.Errorf("msg = %v", out["msg"])
	}
	if out["err"] != "dial tcp: refused" {
		t.Errorf("err = %v", out["err"])
	}
}

func TestFatalAttachesRequestID(t *testing.T) {
	var buf bytes.Buffer
	prevDefault := slog.Default()
	t.Cleanup(func() { slog.SetDefault(prevDefault) })
	slog.SetDefault(newLogger("test", slog.LevelDebug, &buf))
	exitFn = func(int) {}
	t.Cleanup(func() { exitFn = origExit })

	ctx := ContextWithRequestID(context.Background(), "rid-fatal")
	Fatal(ctx, "boom")

	var out map[string]any
	json.Unmarshal(buf.Bytes(), &out)
	if out["request_id"] != "rid-fatal" {
		t.Errorf("request_id = %v, want rid-fatal", out["request_id"])
	}
}
