// Package config validates required environment variables at service
// startup and exits non-zero on missing / invalid values. Removes the
// "if X == \"\" { X = \"dev-default\" }" pattern that scattered insecure
// fallbacks across every service main() — a missing JWT_SECRET silently
// falling back to "quiz-battle-dev-secret" in prod is the kind of bug
// that doesn't show up until someone forges a token.
//
// Service-specific optional vars (RAZORPAY_*, FIREBASE_*, RESEND_*) are
// NOT covered here; services read them directly with os.Getenv after
// Common() returns. The line is "is this var required for ANY service
// to boot at all?" — if yes, list it here.
package config

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"

	"quiz-battle/pkg/log"
)

// Common holds the infra dependencies every service needs (Mongo,
// Redis, RabbitMQ). JWT_SECRET is NOT here on purpose — the
// notification service doesn't mint or verify tokens, so requiring
// JWT_SECRET on its container would be operational dead weight.
// Services that DO use JWT (auth, matchmaking, quiz, scoring, payment)
// fetch it via config.MustRequired(ctx, "JWT_SECRET").
type Common struct {
	MongoURI    string
	RedisAddr   string
	RabbitMQURL string
	// LogLevel is optional; pkg/log already handles parsing and
	// defaults to INFO when empty. Hoisted here so the value is
	// surfaced once at startup for visibility.
	LogLevel string
}

// requiredCommonKeys are the infra-dep env vars every service MUST
// have. Listed in one place so the error message can mention all
// missing vars in a single line, not one Fatal per missing var.
var requiredCommonKeys = []string{
	"MONGO_URI",
	"REDIS_ADDR",
	"RABBITMQ_URL",
}

// LoadCommon reads + validates the cross-service required env vars.
// Returns an error listing every missing or empty key — operator can
// fix all of them in one pass instead of restarting per missing var.
func LoadCommon() (*Common, error) {
	missing := make([]string, 0, len(requiredCommonKeys))
	for _, k := range requiredCommonKeys {
		if strings.TrimSpace(os.Getenv(k)) == "" {
			missing = append(missing, k)
		}
	}
	if len(missing) > 0 {
		return nil, fmt.Errorf("required env vars missing or empty: %s", strings.Join(missing, ", "))
	}
	return &Common{
		MongoURI:    os.Getenv("MONGO_URI"),
		RedisAddr:   os.Getenv("REDIS_ADDR"),
		RabbitMQURL: os.Getenv("RABBITMQ_URL"),
		LogLevel:    os.Getenv("LOG_LEVEL"),
	}, nil
}

// MustCommon wraps LoadCommon with a Fatal-on-error shim suitable for
// main(). The fatal log line is structured (it's emitted via pkg/log)
// so an operator's grep for "config validation failed" lands on the
// exact message that names the missing keys.
func MustCommon(ctx context.Context) *Common {
	c, err := LoadCommon()
	if err != nil {
		log.Fatal(ctx, "config validation failed; aborting startup", "err", err)
	}
	return c
}

// Required returns the value of name, or an error when the env var is
// unset or whitespace-only. Use this for service-specific required
// vars that don't belong in Common (e.g. RAZORPAY_KEY_SECRET in
// payment, GOOGLE_CLIENT_ID in auth).
func Required(name string) (string, error) {
	v := strings.TrimSpace(os.Getenv(name))
	if v == "" {
		return "", fmt.Errorf("required env var %s is missing or empty", name)
	}
	return v, nil
}

// MustRequired is the Fatal-on-error wrapper for Required.
func MustRequired(ctx context.Context, name string) string {
	v, err := Required(name)
	if err != nil {
		log.Fatal(ctx, "required env var missing", "name", name)
	}
	return v
}

// Optional returns the value of name when set, or fallback when not.
// Used for "has a sensible default" knobs (LOG_LEVEL, NOTIF_DAILY_CAP).
// Note: there is intentionally no analog for the four required vars
// in Common — providing one would re-create the insecure-default
// pattern this package exists to remove.
func Optional(name, fallback string) string {
	v := strings.TrimSpace(os.Getenv(name))
	if v == "" {
		return fallback
	}
	return v
}

// OptionalInt parses the env var as a base-10 integer. Returns fallback
// on missing OR malformed input — services that care about the
// distinction should call os.Getenv + strconv.Atoi directly.
func OptionalInt(name string, fallback int) int {
	v := strings.TrimSpace(os.Getenv(name))
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return n
}
