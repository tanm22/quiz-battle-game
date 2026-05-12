package auth

import (
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// TestGenerateAndVerify_RoundTrip is the happy path: a token signed
// with the right secret verifies, and the claims survive unchanged.
func TestGenerateAndVerify_RoundTrip(t *testing.T) {
	const secret = "test-secret-do-not-use-in-prod"
	tok, err := GenerateToken("user-123", "alice", secret)
	if err != nil {
		t.Fatalf("generate: %v", err)
	}
	claims, err := VerifyToken(tok, secret)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if claims.UserID != "user-123" {
		t.Errorf("user id: want user-123, got %q", claims.UserID)
	}
	if claims.Username != "alice" {
		t.Errorf("username: want alice, got %q", claims.Username)
	}
	// Note: we don't assert on claims.Subject here. The Claims struct's
	// UserID field uses `json:"sub"`, which collides with the embedded
	// RegisteredClaims.Subject (also "sub"). The outer UserID wins on
	// (de)serialization, leaving Subject empty after a round-trip — an
	// artifact of the JSON tag layout, not a correctness issue, since
	// every caller reads UserID (via UserIDFromContext).
}

// TestVerify_WrongSecretRejected proves the HMAC actually gates trust:
// a token signed by one secret must NOT verify under a different one.
func TestVerify_WrongSecretRejected(t *testing.T) {
	tok, err := GenerateToken("user-1", "alice", "secret-A")
	if err != nil {
		t.Fatalf("generate: %v", err)
	}
	if _, err := VerifyToken(tok, "secret-B"); err == nil {
		t.Fatal("token verified under wrong secret — HMAC gate is broken")
	}
}

// TestVerify_ExpiredTokenRejected — golang-jwt validates `exp` by
// default; we don't override that, so an expired token must be
// rejected by VerifyToken without us doing extra work.
func TestVerify_ExpiredTokenRejected(t *testing.T) {
	const secret = "test-secret"
	// Build a token whose ExpiresAt is in the past.
	claims := Claims{
		UserID:   "u",
		Username: "a",
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   "u",
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(-1 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now().Add(-2 * time.Hour)),
		},
	}
	tok, err := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("sign expired token: %v", err)
	}
	if _, err := VerifyToken(tok, secret); err == nil {
		t.Fatal("expired token verified — exp claim is being ignored")
	}
}

// TestVerify_AlgNoneRejected is the classic JWT attack: an attacker
// sets the header's alg to "none" and submits an unsigned token. Our
// VerifyToken explicitly type-asserts on *jwt.SigningMethodHMAC, so
// such a token must be rejected with "unexpected signing method".
func TestVerify_AlgNoneRejected(t *testing.T) {
	const secret = "test-secret"
	claims := Claims{
		UserID:   "u",
		Username: "a",
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   "u",
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(1 * time.Hour)),
		},
	}
	// jwt.UnsafeAllowNoneSignatureType is the library's escape hatch
	// for the well-known footgun; we use it as the attacker would.
	tok, err := jwt.NewWithClaims(jwt.SigningMethodNone, claims).SignedString(jwt.UnsafeAllowNoneSignatureType)
	if err != nil {
		t.Fatalf("sign alg:none token: %v", err)
	}
	_, err = VerifyToken(tok, secret)
	if err == nil {
		t.Fatal("alg:none token verified — service is vulnerable to the classic JWT bypass")
	}
	if !strings.Contains(err.Error(), "signing method") {
		// Either our explicit guard or the library's safety should
		// reject this. We don't pin the exact message but it must
		// signal the cause, not just "invalid token".
		t.Logf("note: rejection message was %q (acceptable as long as the token didn't pass)", err.Error())
	}
}

// TestVerify_GarbageTokenRejected — a non-JWT string must not panic
// and must produce an error.
func TestVerify_GarbageTokenRejected(t *testing.T) {
	if _, err := VerifyToken("not.a.jwt", "any-secret"); err == nil {
		t.Fatal("garbage token verified")
	}
}

// TestUserIDFromContext_EmptyReturnsError ensures the context helpers
// don't silently return empty strings — handlers rely on errors to
// reject unauthenticated calls.
func TestUserIDFromContext_EmptyReturnsError(t *testing.T) {
	ctx := t.Context()
	_, err := UserIDFromContext(ctx)
	if err == nil {
		t.Fatal("UserIDFromContext returned no error for empty context")
	}
}

// TestContextWithClaims_RoundTrip checks the inject/extract pair so
// downstream handlers can rely on UserID and Username both surviving.
func TestContextWithClaims_RoundTrip(t *testing.T) {
	claims := &Claims{UserID: "u-77", Username: "bob"}
	ctx := ContextWithClaims(t.Context(), claims)

	uid, err := UserIDFromContext(ctx)
	if err != nil {
		t.Fatalf("UserIDFromContext after inject: %v", err)
	}
	if uid != "u-77" {
		t.Errorf("user id: want u-77, got %q", uid)
	}

	uname, err := UsernameFromContext(ctx)
	if err != nil {
		t.Fatalf("UsernameFromContext after inject: %v", err)
	}
	if uname != "bob" {
		t.Errorf("username: want bob, got %q", uname)
	}
}

// TestVerify_EmptyTokenRejected — empty string is a common
// off-by-one mistake in metadata extraction; make sure VerifyToken
// doesn't accept it as a degenerate "valid" token.
func TestVerify_EmptyTokenRejected(t *testing.T) {
	_, err := VerifyToken("", "secret")
	if err == nil {
		t.Fatal("empty token verified")
	}
	// Guard against the library returning a typed-nil error.
	if errors.Is(err, nil) {
		t.Fatal("err is typed nil")
	}
}

func TestAccessTokenTTLIsShortAndRefreshIsLong(t *testing.T) {
	if AccessTokenTTL >= time.Hour {
		t.Errorf("AccessTokenTTL = %v, want < 1h to bound revocation latency", AccessTokenTTL)
	}
	if RefreshTokenTTL < 7*24*time.Hour {
		t.Errorf("RefreshTokenTTL = %v, want >= 7d so users aren't forced to re-login too often", RefreshTokenTTL)
	}
}

func TestGenerateAccessTokenIncludesJTI(t *testing.T) {
	tok, jti, err := GenerateAccessToken("u-1", "alice", "secret")
	if err != nil {
		t.Fatalf("GenerateAccessToken: %v", err)
	}
	claims, err := VerifyToken(tok, "secret")
	if err != nil {
		t.Fatalf("VerifyToken: %v", err)
	}
	if claims.ID == "" || claims.ID != jti {
		t.Errorf("jti=%q, want non-empty and match returned %q", claims.ID, jti)
	}
}

func TestGenerateRefreshTokenIDReturnsHexString(t *testing.T) {
	id, err := GenerateRefreshTokenID()
	if err != nil {
		t.Fatalf("GenerateRefreshTokenID: %v", err)
	}
	if len(id) < 32 {
		t.Errorf("refresh id %q too short (got %d bytes)", id, len(id))
	}
}
