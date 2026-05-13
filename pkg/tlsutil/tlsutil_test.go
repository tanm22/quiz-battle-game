package tlsutil

import (
	"context"
	"os"
	"testing"
)

// TestEnabled covers the truthy / falsy parsing of TLS_ENABLED so a
// stray "True" / "1" / "yes" doesn't silently fall through to
// plaintext when the operator meant to flip it on.
func TestEnabled(t *testing.T) {
	cases := map[string]bool{
		"":      false,
		"false": false,
		"0":     false,
		"no":    false,
		"true":  true,
		"True":  true,
		"TRUE":  true,
		"1":     true,
		"yes":   true,
		" true ": true,
	}
	for in, want := range cases {
		t.Setenv("TLS_ENABLED", in)
		if got := Enabled(); got != want {
			t.Errorf("Enabled() with TLS_ENABLED=%q: got %v, want %v", in, got, want)
		}
	}
}

// TestGRPCServerOptions_PlaintextWhenDisabled documents that an
// unset / falsy TLS_ENABLED returns an empty option slice so the
// caller's grpc.NewServer keeps its current plaintext behaviour.
func TestGRPCServerOptions_PlaintextWhenDisabled(t *testing.T) {
	t.Setenv("TLS_ENABLED", "")
	opts := GRPCServerOptions(context.Background())
	if len(opts) != 0 {
		t.Errorf("expected no options when TLS disabled, got %d", len(opts))
	}
}

// TestGRPCServerOptions_FatalsOnMissingCert is hard to assert
// directly (log.Fatal terminates the process), so we exercise the
// loadCert seam instead. Same contract: TLS_ENABLED true with
// missing files must error, not silently downgrade.
func TestLoadCert_RejectsMissingPaths(t *testing.T) {
	t.Setenv("TLS_CERT_FILE", "")
	t.Setenv("TLS_KEY_FILE", "")
	_, err := loadCert()
	if err == nil {
		t.Fatal("loadCert should error when paths are empty")
	}
}

// TestLoadCert_RejectsNonExistentFiles covers the "typo'd path"
// case — a real cert file path that doesn't exist on disk.
func TestLoadCert_RejectsNonExistentFiles(t *testing.T) {
	t.Setenv("TLS_CERT_FILE", "/nonexistent/cert.pem")
	t.Setenv("TLS_KEY_FILE", "/nonexistent/key.pem")
	_, err := loadCert()
	if err == nil {
		t.Fatal("loadCert should error when files don't exist")
	}
	if _, statErr := os.Stat("/nonexistent/cert.pem"); statErr == nil {
		t.Skip("/nonexistent path actually exists on this machine; skip negative test")
	}
}
