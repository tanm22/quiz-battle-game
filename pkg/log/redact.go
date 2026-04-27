package log

import "strings"

// RedactEmail returns a privacy-safe form of email suitable for log
// attributes:
//
//	"alice@example.com" -> "a***@example.com"
//	""                  -> ""
//	"plaintext"         -> "p***"
//	"@example.com"      -> "***@example.com"
//
// Use this for non-error INFO/WARN logs that need to identify the user. On
// errors where debugging requires the full address, log the raw email — the
// error path is rare, narrowly scoped, and the diagnostic value outweighs
// the leak risk.
//
// The redacted form keeps the first character of the local part plus the
// full domain. Domain is preserved on the assumption that an
// engineer-readable signal ("which provider?", "is this a corporate
// account?") is worth more than blanket secrecy of an address that the
// user themselves typed into a public sign-up form.
func RedactEmail(email string) string {
	if email == "" {
		return ""
	}
	at := strings.IndexByte(email, '@')
	if at < 0 {
		return string(email[0]) + "***"
	}
	if at == 0 {
		return "***" + email
	}
	return string(email[0]) + "***" + email[at:]
}
