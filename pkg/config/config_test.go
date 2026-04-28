package config

import (
	"strings"
	"testing"
)

// envSnapshot saves and restores the process env around a test so a
// failing assertion doesn't leak state into the next test.
func envSnapshot(t *testing.T, keys ...string) {
	t.Helper()
	prev := map[string]string{}
	for _, k := range keys {
		prev[k] = lookup(k)
	}
	t.Cleanup(func() {
		for k, v := range prev {
			if v == "" {
				_ = unset(k)
			} else {
				_ = setEnv(k, v)
			}
		}
	})
}

// Thin wrappers so the test file is the only place that has to import
// "os" — keeps the asserts visually clean.
func lookup(k string) string   { return getenv(k) }
func setEnv(k, v string) error { return setenv(k, v) }
func unset(k string) error     { return unsetenv(k) }

func TestLoadCommon_AllSet(t *testing.T) {
	envSnapshot(t, "MONGO_URI", "REDIS_ADDR", "RABBITMQ_URL", "LOG_LEVEL")
	_ = setEnv("MONGO_URI", "mongodb://m:1")
	_ = setEnv("REDIS_ADDR", "r:6379")
	_ = setEnv("RABBITMQ_URL", "amqp://q")
	_ = setEnv("LOG_LEVEL", "debug")

	c, err := LoadCommon()
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if c.MongoURI != "mongodb://m:1" || c.RedisAddr != "r:6379" ||
		c.RabbitMQURL != "amqp://q" || c.LogLevel != "debug" {
		t.Errorf("config: %+v", c)
	}
}

func TestLoadCommon_MissingOneListedInError(t *testing.T) {
	envSnapshot(t, "MONGO_URI", "REDIS_ADDR", "RABBITMQ_URL")
	_ = setEnv("MONGO_URI", "m")
	_ = setEnv("REDIS_ADDR", "r")
	_ = unset("RABBITMQ_URL")

	_, err := LoadCommon()
	if err == nil {
		t.Fatal("expected error for missing RABBITMQ_URL")
	}
	if !strings.Contains(err.Error(), "RABBITMQ_URL") {
		t.Errorf("error should name the missing key, got: %v", err)
	}
}

func TestLoadCommon_MultipleMissingListedTogether(t *testing.T) {
	// All three missing — operator should see them all in one line so
	// they can fix the deployment manifest in one pass.
	envSnapshot(t, "MONGO_URI", "REDIS_ADDR", "RABBITMQ_URL")
	for _, k := range []string{"MONGO_URI", "REDIS_ADDR", "RABBITMQ_URL"} {
		_ = unset(k)
	}

	_, err := LoadCommon()
	if err == nil {
		t.Fatal("expected error for all-missing")
	}
	for _, k := range []string{"MONGO_URI", "REDIS_ADDR", "RABBITMQ_URL"} {
		if !strings.Contains(err.Error(), k) {
			t.Errorf("missing-keys error did not name %q: %v", k, err)
		}
	}
}

func TestLoadCommon_WhitespaceOnlyTreatedAsEmpty(t *testing.T) {
	// A typo like MONGO_URI="   " in a manifest would otherwise pass
	// the empty-string check but produce a useless config value.
	// TrimSpace on read closes that gap.
	envSnapshot(t, "MONGO_URI", "REDIS_ADDR", "RABBITMQ_URL")
	_ = setEnv("MONGO_URI", "   ")
	_ = setEnv("REDIS_ADDR", "r")
	_ = setEnv("RABBITMQ_URL", "q")

	_, err := LoadCommon()
	if err == nil || !strings.Contains(err.Error(), "MONGO_URI") {
		t.Errorf("whitespace MONGO_URI should fail validation, got: %v", err)
	}
}

func TestLoadCommon_ValuesTrimmedOnStore(t *testing.T) {
	// A manifest typo like MONGO_URI=" mongodb://host" passes the empty
	// check (the trimmed value is non-empty) but the dial layer would
	// then receive whitespace and emit a confusing connection error.
	// Storing the trimmed value keeps the dial path clean.
	envSnapshot(t, "MONGO_URI", "REDIS_ADDR", "RABBITMQ_URL", "LOG_LEVEL")
	_ = setEnv("MONGO_URI", "  mongodb://m:1  ")
	_ = setEnv("REDIS_ADDR", "\tr:6379\n")
	_ = setEnv("RABBITMQ_URL", " amqp://q ")
	_ = setEnv("LOG_LEVEL", "  debug  ")

	c, err := LoadCommon()
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if c.MongoURI != "mongodb://m:1" {
		t.Errorf("MongoURI not trimmed: %q", c.MongoURI)
	}
	if c.RedisAddr != "r:6379" {
		t.Errorf("RedisAddr not trimmed: %q", c.RedisAddr)
	}
	if c.RabbitMQURL != "amqp://q" {
		t.Errorf("RabbitMQURL not trimmed: %q", c.RabbitMQURL)
	}
	if c.LogLevel != "debug" {
		t.Errorf("LogLevel not trimmed: %q", c.LogLevel)
	}
}

func TestRequired_HappyAndMissing(t *testing.T) {
	envSnapshot(t, "X_REQUIRED_TEST")
	_ = setEnv("X_REQUIRED_TEST", "yes")
	if got, err := Required("X_REQUIRED_TEST"); err != nil || got != "yes" {
		t.Errorf("got=%q err=%v, want yes/nil", got, err)
	}
	_ = unset("X_REQUIRED_TEST")
	if _, err := Required("X_REQUIRED_TEST"); err == nil {
		t.Error("expected error for missing var")
	}
}

func TestOptional_FallbackPath(t *testing.T) {
	envSnapshot(t, "X_OPTIONAL_TEST")
	_ = unset("X_OPTIONAL_TEST")
	if got := Optional("X_OPTIONAL_TEST", "fallback"); got != "fallback" {
		t.Errorf("got=%q, want fallback", got)
	}
	_ = setEnv("X_OPTIONAL_TEST", "set")
	if got := Optional("X_OPTIONAL_TEST", "fallback"); got != "set" {
		t.Errorf("got=%q, want set", got)
	}
}

func TestOptionalInt_FallbackOnMalformed(t *testing.T) {
	envSnapshot(t, "X_OPTINT_TEST")
	_ = setEnv("X_OPTINT_TEST", "not-a-number")
	if got := OptionalInt("X_OPTINT_TEST", 42); got != 42 {
		t.Errorf("got=%d, want 42 (malformed should fall through)", got)
	}
	_ = setEnv("X_OPTINT_TEST", "7")
	if got := OptionalInt("X_OPTINT_TEST", 42); got != 7 {
		t.Errorf("got=%d, want 7", got)
	}
}
