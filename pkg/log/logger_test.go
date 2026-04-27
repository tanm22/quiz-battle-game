package log

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"strings"
	"testing"
)

func decode(t *testing.T, line []byte) map[string]any {
	t.Helper()
	var out map[string]any
	if err := json.Unmarshal(line, &out); err != nil {
		t.Fatalf("not JSON: %v\n%s", err, line)
	}
	return out
}

func TestNewLoggerEmitsJSONWithService(t *testing.T) {
	var buf bytes.Buffer
	logger := newLogger("auth-test", slog.LevelInfo, &buf)
	logger.Info("hello world")

	out := decode(t, buf.Bytes())
	if out["service"] != "auth-test" {
		t.Errorf("service attr missing or wrong: %v", out["service"])
	}
	if out["msg"] != "hello world" {
		t.Errorf("msg = %v, want hello world", out["msg"])
	}
	if out["level"] != "INFO" {
		t.Errorf("level = %v, want INFO", out["level"])
	}
	if _, ok := out["time"].(string); !ok {
		t.Errorf("time attr missing or non-string: %v", out["time"])
	}
}

func TestNewLoggerLevelFilter(t *testing.T) {
	var buf bytes.Buffer
	logger := newLogger("auth-test", slog.LevelWarn, &buf)
	logger.Debug("debug-msg")
	logger.Info("info-msg")
	logger.Warn("warn-msg")

	got := buf.String()
	if strings.Contains(got, "debug-msg") {
		t.Errorf("debug emitted at warn level: %s", got)
	}
	if strings.Contains(got, "info-msg") {
		t.Errorf("info emitted at warn level: %s", got)
	}
	if !strings.Contains(got, "warn-msg") {
		t.Errorf("warn missing: %s", got)
	}
}

func TestFromContextAttachesRequestID(t *testing.T) {
	var buf bytes.Buffer
	slog.SetDefault(newLogger("test", slog.LevelInfo, &buf))

	ctx := ContextWithRequestID(context.Background(), "rid-xyz")
	FromContext(ctx).Info("with-id")

	out := decode(t, buf.Bytes())
	if out["request_id"] != "rid-xyz" {
		t.Errorf("request_id = %v, want rid-xyz", out["request_id"])
	}
}

func TestFromContextNoRequestID(t *testing.T) {
	var buf bytes.Buffer
	slog.SetDefault(newLogger("test", slog.LevelInfo, &buf))

	FromContext(context.Background()).Info("no-id")

	out := decode(t, buf.Bytes())
	if _, present := out["request_id"]; present {
		t.Errorf("request_id attr should be absent, got %v", out["request_id"])
	}
}

func TestInitUsesEnvLogLevel(t *testing.T) {
	t.Setenv("LOG_LEVEL", "warn")
	logger := Init("init-test")
	if !logger.Enabled(context.Background(), slog.LevelWarn) {
		t.Errorf("warn should be enabled when LOG_LEVEL=warn")
	}
	if logger.Enabled(context.Background(), slog.LevelInfo) {
		t.Errorf("info should be disabled when LOG_LEVEL=warn")
	}
}
