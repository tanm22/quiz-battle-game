package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"testing"
)

// sign produces the canonical Razorpay webhook signature for a given
// body/secret: hex-encoded HMAC-SHA256(secret, body). Mirrors the math
// inside verifyRazorpaySignature so the tests share no code with the
// production path — a regression in the verifier won't accidentally
// mask itself by using the same buggy helper.
func sign(t *testing.T, body []byte, secret string) string {
	t.Helper()
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

func TestVerifyRazorpaySignature_ValidSignatureAccepted(t *testing.T) {
	body := []byte(`{"event":"payment.captured","payload":{"payment":{"entity":{"id":"pay_test_1","amount":14900}}}}`)
	secret := "wh_test_secret_change_me"

	if !verifyRazorpaySignature(body, sign(t, body, secret), secret) {
		t.Fatalf("valid signature rejected — verifier is broken")
	}
}

func TestVerifyRazorpaySignature_TamperedBodyRejected(t *testing.T) {
	original := []byte(`{"event":"payment.captured","payload":{"payment":{"entity":{"amount":14900}}}}`)
	tampered := []byte(`{"event":"payment.captured","payload":{"payment":{"entity":{"amount":99999900}}}}`)
	secret := "wh_test_secret"

	// Sign the original, send the tampered body — must reject.
	if verifyRazorpaySignature(tampered, sign(t, original, secret), secret) {
		t.Fatal("tampered body accepted — verifier doesn't actually re-MAC the body")
	}
}

func TestVerifyRazorpaySignature_WrongSecretRejected(t *testing.T) {
	body := []byte(`{"event":"payment.captured"}`)
	correctSecret := "wh_real_secret"
	attackerSecret := "wh_guessed_secret"

	// Attacker signs with their guessed secret; we verify with the real one.
	if verifyRazorpaySignature(body, sign(t, body, attackerSecret), correctSecret) {
		t.Fatal("signature from wrong secret accepted")
	}
}

func TestVerifyRazorpaySignature_EmptySecretRejected(t *testing.T) {
	body := []byte(`{"event":"payment.captured"}`)
	// An empty webhook secret means the operator hasn't configured one yet —
	// failing closed prevents a misconfigured deploy from accepting any
	// signature an attacker can compute.
	if verifyRazorpaySignature(body, sign(t, body, ""), "") {
		t.Fatal("empty secret accepted — fail-closed guard is gone")
	}
}

func TestVerifyRazorpaySignature_EmptySignatureRejected(t *testing.T) {
	body := []byte(`{"event":"payment.captured"}`)
	if verifyRazorpaySignature(body, "", "wh_test_secret") {
		t.Fatal("empty signature accepted")
	}
}

func TestVerifyRazorpaySignature_EmptyBodyWithCorrectSigAccepted(t *testing.T) {
	// HMAC of an empty body is well-defined; if Razorpay ever sends an
	// empty payload (e.g. a ping) with a correct signature, we should
	// still accept it. Guards against an off-by-one in the body read.
	secret := "wh_test_secret"
	if !verifyRazorpaySignature([]byte{}, sign(t, []byte{}, secret), secret) {
		t.Fatal("empty body with valid signature rejected")
	}
}

func TestVerifyRazorpaySignature_SignatureCaseSensitiveRejected(t *testing.T) {
	// hex.EncodeToString produces lowercase. An uppercase signature
	// from a buggy client should be rejected — the comparison is a
	// byte-wise hmac.Equal, not a case-insensitive match.
	body := []byte(`{"event":"payment.captured"}`)
	secret := "wh_test_secret"
	lower := sign(t, body, secret)
	upper := ""
	for _, c := range lower {
		if c >= 'a' && c <= 'f' {
			upper += string(c - 32)
		} else {
			upper += string(c)
		}
	}
	if verifyRazorpaySignature(body, upper, secret) {
		t.Fatal("uppercase-hex signature accepted; hmac.Equal should be byte-exact")
	}
}
