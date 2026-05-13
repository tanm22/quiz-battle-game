package validate

import (
	"errors"
	"strings"
	"testing"
)

func TestUsername(t *testing.T) {
	cases := []struct {
		in    string
		valid bool
	}{
		{"alice", true},
		{"alice_42", true},
		{"AliceB42", true},
		{"abc", true},
		{"a234567890123456789a", true},   // exactly 20 chars
		{"ab", false},                    // too short
		{"a234567890123456789ab", false}, // 21 chars, too long
		{"alice space", false},
		{"alice-dash", false},
		{"", false},
		{"alice@bob", false},
		{"';drop", false},
	}
	for _, c := range cases {
		err := Username(c.in)
		if c.valid && err != nil {
			t.Errorf("Username(%q) = %v, want nil", c.in, err)
		}
		if !c.valid && !errors.Is(err, ErrInvalidUsername) {
			t.Errorf("Username(%q) = %v, want ErrInvalidUsername", c.in, err)
		}
	}
}

func TestEmail(t *testing.T) {
	cases := []struct {
		in    string
		valid bool
	}{
		{"alice@example.com", true},
		{"a.b+c@example.co.uk", true},
		{"first.last@sub.domain.io", true},
		{"", false},
		{"@example.com", false},
		{"alice@", false},
		{"alice@example", false}, // missing TLD
		{"plain", false},
		{"with space@example.com", false},
	}
	for _, c := range cases {
		err := Email(c.in)
		if c.valid && err != nil {
			t.Errorf("Email(%q) = %v, want nil", c.in, err)
		}
		if !c.valid && !errors.Is(err, ErrInvalidEmail) {
			t.Errorf("Email(%q) = %v, want ErrInvalidEmail", c.in, err)
		}
	}
}

func TestPassword(t *testing.T) {
	if err := Password("hunter2"); err != nil {
		t.Errorf("hunter2 should be valid: %v", err)
	}
	if err := Password("12345"); !errors.Is(err, ErrInvalidPassword) {
		t.Errorf("5-char password should fail: %v", err)
	}
	if err := Password(""); !errors.Is(err, ErrInvalidPassword) {
		t.Errorf("empty password should fail: %v", err)
	}
	// 6 unicode runes = valid even though byte length differs from rune count.
	// Surfaces a real bug if Password were using len() instead of RuneCount.
	if err := Password("héllo!"); err != nil {
		t.Errorf("6-rune password should be valid: %v", err)
	}
}

func TestUUID(t *testing.T) {
	cases := []struct {
		in    string
		valid bool
	}{
		{"550e8400-e29b-41d4-a716-446655440000", true}, // canonical
		{"550E8400-E29B-41D4-A716-446655440000", true}, // upper case is fine
		{"01234567-89ab-1cde-8f01-23456789abcd", true},
		{"not-a-uuid", false},
		{"", false},
		{"550e8400-e29b-41d4-a716-44665544000", false}, // too short
		{"550e8400e29b41d4a716446655440000", false},    // missing dashes
		{"' OR 1=1; DROP TABLE users;--", false},       // SQLi attempt
		{"../../../../etc/passwd", false},              // path traversal
	}
	for _, c := range cases {
		err := UUID(c.in)
		if c.valid && err != nil {
			t.Errorf("UUID(%q) = %v, want nil", c.in, err)
		}
		if !c.valid && !errors.Is(err, ErrInvalidUUID) {
			t.Errorf("UUID(%q) = %v, want ErrInvalidUUID", c.in, err)
		}
	}
}

func TestMaxLen(t *testing.T) {
	if err := MaxLen("hello", 10); err != nil {
		t.Errorf("short string should pass: %v", err)
	}
	if err := MaxLen(strings.Repeat("a", 101), 100); !errors.Is(err, ErrTooLong) {
		t.Errorf("over-limit string should fail: %v", err)
	}
	// Boundary: exactly max length is allowed.
	if err := MaxLen(strings.Repeat("a", 100), 100); err != nil {
		t.Errorf("exactly-at-limit should pass: %v", err)
	}
}

func TestTopic(t *testing.T) {
	if err := Topic("science"); err != nil {
		t.Errorf("science should be valid: %v", err)
	}
	if err := Topic(""); !errors.Is(err, ErrInvalidTopic) {
		t.Errorf("empty topic should fail: %v", err)
	}
	if err := Topic("   "); !errors.Is(err, ErrInvalidTopic) {
		t.Errorf("whitespace topic should fail: %v", err)
	}
	if err := Topic(strings.Repeat("x", 65)); !errors.Is(err, ErrInvalidTopic) {
		t.Errorf("over-64 topic should fail: %v", err)
	}
}

func TestReferralCode(t *testing.T) {
	cases := map[string]bool{
		"":                      false,
		"ABC":                   false, // too short
		"ABC123":                true,
		"REFA3B91F2C":           true,  // 11 chars — within 6-12
		strings.Repeat("A", 32): false, // too long
		"abc-123":               false, // wrong charset
		"abc123":                false, // lowercase rejected
	}
	for in, ok := range cases {
		err := ReferralCode(in)
		if (err == nil) != ok {
			t.Errorf("ReferralCode(%q) err=%v, want ok=%v", in, err, ok)
		}
	}
}

func TestTimeFilter(t *testing.T) {
	cases := map[string]bool{
		"":         true, // empty defaults to alltime on the server
		"alltime":  true,
		"daily":    true,
		"weekly":   true,
		"monthly":  true,
		"lastweek": false,
		"yearly":   false,
	}
	for in, ok := range cases {
		err := TimeFilter(in)
		if (err == nil) != ok {
			t.Errorf("TimeFilter(%q) err=%v, want ok=%v", in, err, ok)
		}
	}
}

// TestDisplayName covers the post-Tanishq-review XSS gate: HTML
// punctuation, control characters, and newlines must all be rejected
// at the input boundary so downstream surfaces (push notifications,
// future web UI, log lines) can render the value without escaping.
func TestDisplayName(t *testing.T) {
	cases := map[string]bool{
		"Alice":                       true,
		"Alice Wonderland":            true, // spaces allowed
		"José María":                  true, // accented Unicode allowed
		"プレイヤー 1":                  true, // CJK allowed
		"🎮 Gamer":                    true, // emoji allowed
		"a":                           true, // single char ok
		strings.Repeat("A", 40):       true, // 40-byte limit ok
		strings.Repeat("A", 41):       false, // over 40 bytes
		"":                            false, // empty rejected
		"<script>alert(1)</script>":   false, // HTML script tag
		"Alice<Bob":                   false, // lone <
		"Alice>Bob":                   false, // lone >
		`Alice"Bob`:                   false, // double quote
		"Alice'Bob":                   false, // single quote
		"Alice&Bob":                   false, // ampersand (HTML entity)
		"Alice`Bob":                   false, // backtick (template injection)
		"Alice\nBob":                  false, // newline
		"Alice\tBob":                  false, // tab (control char)
		"Alice\x00Bob":                false, // null byte
		"Alice\x7fBob":                false, // DEL char
		"Alice\rBob":                  false, // carriage return
	}
	for in, ok := range cases {
		err := DisplayName(in)
		if (err == nil) != ok {
			t.Errorf("DisplayName(%q) err=%v, want ok=%v", in, err, ok)
		}
	}
}

// TestSanitizeDisplayName documents the cleanup contract — trims
// surrounding whitespace, collapses internal runs, drops control
// chars. The result must still pass DisplayName() to be stored.
func TestSanitizeDisplayName(t *testing.T) {
	cases := map[string]string{
		"":                  "",
		"   ":               "",
		"  Alice  ":         "Alice",
		"Alice   Bob":       "Alice Bob",            // collapse internal runs
		"Alice\tBob":        "Alice Bob",            // tab → single space
		"Alice  \t  Bob":    "Alice Bob",            // mixed whitespace collapses
		"\x00Alice\x00":     "Alice",                // null bytes dropped
		"\nAlice\n":         "Alice",                // newlines dropped
		"  José María  ":    "José María",           // Unicode preserved
	}
	for in, want := range cases {
		got := SanitizeDisplayName(in)
		if got != want {
			t.Errorf("SanitizeDisplayName(%q) = %q, want %q", in, got, want)
		}
	}
}
