// Package tlsutil centralises the opt-in TLS wiring for every public
// surface we expose: gRPC listeners, the Razorpay webhook HTTP server,
// the admin dashboard, and the Prometheus metrics endpoint.
//
// Recommended deployment is plaintext behind a reverse proxy (nginx /
// Caddy / cloud load balancer) that terminates TLS — see
// docs/deployment-tls.md. For deployments where in-process TLS is
// required (e.g. zero-trust networks, or single-host VPS without a
// proxy), set the env vars below and the helpers here will load the
// certs and switch the server to TLS automatically.
//
// Env vars (all optional; default is plaintext):
//
//	TLS_ENABLED     — "true" / "1" to enable in-process TLS
//	TLS_CERT_FILE   — path to the PEM-encoded certificate (chain)
//	TLS_KEY_FILE    — path to the PEM-encoded private key
//
// Setting TLS_ENABLED without both cert paths is a hard error at
// startup so a misconfiguration can't silently fall through to
// plaintext on a service that's supposed to be encrypted.
package tlsutil

import (
	"context"
	"crypto/tls"
	"fmt"
	"net/http"
	"os"
	"strings"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"

	"quiz-battle/pkg/log"
)

// Enabled reports whether the TLS_ENABLED env var is truthy. Used by
// callers that want to log "starting plaintext" vs "starting TLS"
// without re-reading the env themselves.
func Enabled() bool {
	v := strings.TrimSpace(strings.ToLower(os.Getenv("TLS_ENABLED")))
	return v == "true" || v == "1" || v == "yes"
}

// loadCert reads and validates the configured cert + key. Returns an
// error rather than fataling so callers can decide whether a missing
// cert is acceptable (e.g. dev mode) or should crash the service.
func loadCert() (tls.Certificate, error) {
	certFile := strings.TrimSpace(os.Getenv("TLS_CERT_FILE"))
	keyFile := strings.TrimSpace(os.Getenv("TLS_KEY_FILE"))
	if certFile == "" || keyFile == "" {
		return tls.Certificate{}, fmt.Errorf("TLS_ENABLED set but TLS_CERT_FILE or TLS_KEY_FILE is empty")
	}
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		return tls.Certificate{}, fmt.Errorf("load cert/key pair: %w", err)
	}
	return cert, nil
}

// GRPCServerOptions returns the grpc.ServerOption slice the caller
// should pass to grpc.NewServer. When TLS_ENABLED is false the slice
// is empty and the server starts plaintext (current default —
// matches deployment-tls.md's recommended "reverse proxy terminates
// TLS" posture).
//
// On TLS_ENABLED=true the function loads the cert pair and returns
// a credentials.NewTLS option; misconfiguration is fatal so we don't
// silently downgrade to plaintext.
func GRPCServerOptions(ctx context.Context) []grpc.ServerOption {
	if !Enabled() {
		return nil
	}
	cert, err := loadCert()
	if err != nil {
		log.Fatal(ctx, "TLS_ENABLED but cert load failed", "err", err)
	}
	creds := credentials.NewTLS(&tls.Config{
		Certificates: []tls.Certificate{cert},
		MinVersion:   tls.VersionTLS12,
	})
	log.FromContext(ctx).Info("gRPC TLS enabled", "component", "tlsutil")
	return []grpc.ServerOption{grpc.Creds(creds)}
}

// ServeHTTP starts the given *http.Server using TLS when TLS_ENABLED
// is set, plaintext otherwise. Mirrors srv.ListenAndServe()'s
// blocking semantics — callers should wrap in a goroutine or use it
// at the end of main.
func ServeHTTP(ctx context.Context, srv *http.Server) error {
	if !Enabled() {
		return srv.ListenAndServe()
	}
	certFile := strings.TrimSpace(os.Getenv("TLS_CERT_FILE"))
	keyFile := strings.TrimSpace(os.Getenv("TLS_KEY_FILE"))
	if certFile == "" || keyFile == "" {
		return fmt.Errorf("TLS_ENABLED set but TLS_CERT_FILE or TLS_KEY_FILE is empty")
	}
	log.FromContext(ctx).Info("HTTP TLS enabled", "component", "tlsutil", "addr", srv.Addr)
	return srv.ListenAndServeTLS(certFile, keyFile)
}
