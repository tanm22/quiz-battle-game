package log

import (
	"strings"
	"testing"
)

func TestRedactEmail(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{"typical", "alice@example.com", "a***@example.com"},
		{"short_local", "b@x.io", "b***@x.io"},
		{"empty", "", ""},
		{"no_at_falls_back_to_first_char", "plaintext", "p***"},
		{"single_char_no_at", "a", "a***"},
		{"leading_at_keeps_domain", "@example.com", "***@example.com"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := RedactEmail(tc.in); got != tc.want {
				t.Errorf("RedactEmail(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}

func TestRedactEmailDropsLocalPartAfterFirstChar(t *testing.T) {
	got := RedactEmail("alicewashere@example.com")
	if strings.Contains(got, "lice") || strings.Contains(got, "washere") {
		t.Errorf("RedactEmail leaked local-part substring: %q", got)
	}
}
