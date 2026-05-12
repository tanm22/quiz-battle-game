// Package validate holds shared input validators used across services.
// Promoted from services/auth/main.go (usernameRegex, emailRegex) so
// services/scoring's friend-request handlers, services/payment's
// order creation, and any future RPC accepting the same kinds of
// input share one definition. A drift between two regexes for the
// "same" rule is the kind of bug that surfaces months later as a
// support ticket.
//
// Each validator returns a typed error so handlers can pattern-match
// for status code mapping without parsing strings. The error messages
// are user-safe (no internal state, no stack info) so handlers can
// surface them directly to the client.
package validate

import (
	"errors"
	"regexp"
	"strings"
	"unicode/utf8"
)

// ErrInvalidUsername / ErrInvalidEmail / ErrInvalidPassword are the
// sentinel errors callers compare against with errors.Is.
var (
	ErrInvalidUsername     = errors.New("username must be 3-20 characters: letters, digits, or underscore")
	ErrInvalidEmail        = errors.New("email format is invalid")
	ErrInvalidPassword     = errors.New("password must be at least 6 characters")
	ErrInvalidUUID         = errors.New("identifier must be a valid UUID")
	ErrInvalidTopic        = errors.New("topic must be a non-empty short string")
	ErrTooLong             = errors.New("input exceeds maximum length")
	ErrInvalidReferralCode = errors.New("referral code must be 6-12 uppercase letters or digits")
	ErrInvalidTimeFilter   = errors.New("time_filter must be one of: alltime, daily, weekly, monthly")
)

// usernameRE is the canonical username pattern. Matches what
// services/auth/main.go already enforces; promoted here so
// scoring.SendFriendRequest (target_username) and any future username-
// accepting RPC can share the same definition.
var usernameRE = regexp.MustCompile(`^[a-zA-Z0-9_]{3,20}$`)

// emailRE is a deliberately liberal email regex — RFC 5322 has corner
// cases (quoted local parts, IP-literal domains) that very few real
// inboxes hit and that overly strict regexes reject. This catches
// "obviously wrong" without rejecting valid mail. Defense in depth:
// the actual delivery test happens via a verification email.
var emailRE = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)

// uuidRE matches version-1..5 UUIDs in canonical 8-4-4-4-12 form.
// Used by Friend / Challenge / Match RPCs that accept user-provided
// IDs to make IDOR attempts (forged IDs targeting other users) fail
// at the parse step instead of at the Mongo lookup.
var uuidRE = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)

// Username returns nil when s is a valid username, ErrInvalidUsername otherwise.
func Username(s string) error {
	if !usernameRE.MatchString(s) {
		return ErrInvalidUsername
	}
	return nil
}

// Email returns nil when s is a syntactically valid email. Empty
// string returns ErrInvalidEmail — callers that want "optional email"
// must check for empty themselves before calling Email.
func Email(s string) error {
	if !emailRE.MatchString(s) {
		return ErrInvalidEmail
	}
	return nil
}

// Password returns nil when s meets the minimum-length policy.
// Length is the only enforced rule today — complexity requirements
// (uppercase + digit + symbol) trade typing pain for marginal entropy
// gain and aren't part of the product spec.
func Password(s string) error {
	if utf8.RuneCountInString(s) < 6 {
		return ErrInvalidPassword
	}
	return nil
}

// UUID returns nil when s parses as an RFC 4122 UUID. Used to reject
// forged IDs at handler boundaries — "user_id=../../etc/passwd" or
// "user_id=' OR 1=1--" both fail this regex without reaching Mongo.
func UUID(s string) error {
	if !uuidRE.MatchString(strings.ToLower(s)) {
		return ErrInvalidUUID
	}
	return nil
}

// MaxLen rejects strings longer than max bytes. Different from
// utf8.RuneCountInString because we're guarding storage cost, not
// human-perceived length. Use Username / Email / Password for
// semantic limits; use MaxLen for free-form fields (display name,
// profile bio, message text) where we just want a sane ceiling.
func MaxLen(s string, max int) error {
	if len(s) > max {
		return ErrTooLong
	}
	return nil
}

// Topic validates a quiz topic identifier — non-empty after trim and
// short enough to fit a Mongo index leading edge comfortably.
// Topics come from a closed set seeded in seed/main.go but client-
// supplied filter values land here too (preferredTopics during
// onboarding), so we still validate.
func Topic(s string) error {
	t := strings.TrimSpace(s)
	if t == "" || len(t) > 64 {
		return ErrInvalidTopic
	}
	return nil
}

// referralCodeRE matches the issuance format scoring's mint logic
// produces today: uppercase alphanumeric, 6-12 chars. Tighter than the
// 8 hex chars + "REF" prefix the auth service currently generates
// (REFA3B91F2C = 11 chars) so a future scheme bump within that range
// doesn't need a new validator.
var referralCodeRE = regexp.MustCompile(`^[A-Z0-9]{6,12}$`)

// ReferralCode validates a referral-code string at the handler edge
// so a "${jndi:...}"-style or oversize payload never reaches the
// Redis lookup that drives applyReferral.
func ReferralCode(s string) error {
	if !referralCodeRE.MatchString(s) {
		return ErrInvalidReferralCode
	}
	return nil
}

// allowedTimeFilters is the closed set the global-leaderboard
// handler understands. Empty string is allowed and treated as
// "alltime" by the handler — any other unknown value is rejected
// here rather than silently aliased to a default the user didn't ask
// for.
var allowedTimeFilters = map[string]struct{}{
	"":        {},
	"alltime": {},
	"daily":   {},
	"weekly":  {},
	"monthly": {},
}

// TimeFilter validates a leaderboard time-filter string.
func TimeFilter(s string) error {
	if _, ok := allowedTimeFilters[s]; !ok {
		return ErrInvalidTimeFilter
	}
	return nil
}
