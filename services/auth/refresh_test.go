package main

import (
	"context"
	"os"
	"testing"

	"github.com/redis/go-redis/v9"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/keys"
	pb "quiz-battle/proto"
)

// authedCtx attaches Claims for the given uid to a fresh background
// context. Local to refresh_test.go because services/auth already had
// other tests using their own helpers and this one only ever wants the
// uid (no username variations).
func authedCtx(uid string) context.Context {
	return auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: uid, Username: uid})
}

// plantResetOTP writes a reset-purpose OTP for the given email directly
// into Redis so a test can drive ResetPassword without the SendEmailCode
// round-trip. Mirrors the real path: ResetPassword's CheckEmailCode reads
// the same key.
func plantResetOTP(t *testing.T, srv *authServer, email, code string) error {
	t.Helper()
	return keys.StoreEmailCode(context.Background(), srv.rdb, email, "reset", code)
}

// attachRedis points srv.rdb at a real local Redis. Register uses
// SETNX on the referral-code key, so the refresh-token tests that
// go through Register need a live Redis. Mirrors the same pattern
// used in services/scoring/friends_test.go.
func attachRedis(t *testing.T, srv *authServer) {
	t.Helper()
	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		addr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: addr})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		t.Skipf("redis ping: %v", err)
	}
	// Wipe keyspace so prior runs (referral codes, OTPs) don't bleed in.
	if err := rdb.FlushDB(context.Background()).Err(); err != nil {
		t.Fatalf("redis flush: %v", err)
	}
	srv.rdb = rdb
	t.Cleanup(func() { _ = rdb.Close() })
}

func TestRefreshToken_RotatesAndReturnsFreshPair(t *testing.T) {
	srv := newTestAuthServer(t)
	attachRedis(t, srv)
	ctx := context.Background()

	// Bootstrap: register a user and capture the refresh token.
	reg, err := srv.Register(ctx, &pb.RegisterRequest{Username: "alice_refresh", Password: "hunter22"})
	if err != nil {
		t.Fatalf("Register: %v", err)
	}
	if reg.RefreshToken == "" {
		t.Fatal("Register returned no refresh token")
	}

	resp, err := srv.RefreshToken(ctx, &pb.RefreshTokenRequest{RefreshToken: reg.RefreshToken})
	if err != nil {
		t.Fatalf("RefreshToken: %v", err)
	}
	if resp.AccessToken == "" || resp.RefreshToken == "" {
		t.Errorf("empty token in refresh response: %+v", resp)
	}
	if resp.RefreshToken == reg.RefreshToken {
		t.Errorf("refresh token not rotated")
	}
	if resp.ExpiresIn <= 0 {
		t.Errorf("expires_in=%d, want > 0", resp.ExpiresIn)
	}

	// The original refresh token must now be invalid (single-use).
	if _, err := srv.RefreshToken(ctx, &pb.RefreshTokenRequest{RefreshToken: reg.RefreshToken}); status.Code(err) != codes.Unauthenticated {
		t.Errorf("replay should be Unauthenticated, got %v", err)
	}
}

func TestRefreshToken_RejectsUnknown(t *testing.T) {
	srv := newTestAuthServer(t)
	_, err := srv.RefreshToken(context.Background(), &pb.RefreshTokenRequest{RefreshToken: "deadbeef"})
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("err=%v, want Unauthenticated", err)
	}
}

func TestRefreshToken_RejectsTooLong(t *testing.T) {
	srv := newTestAuthServer(t)
	long := make([]byte, 200)
	for i := range long {
		long[i] = 'a'
	}
	_, err := srv.RefreshToken(context.Background(), &pb.RefreshTokenRequest{RefreshToken: string(long)})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("err=%v, want InvalidArgument", err)
	}
}

func TestLogout_RevokesTheFamily(t *testing.T) {
	srv := newTestAuthServer(t)
	attachRedis(t, srv)
	ctx := context.Background()
	reg, err := srv.Register(ctx, &pb.RegisterRequest{Username: "bob_logout", Password: "hunter22"})
	if err != nil {
		t.Fatalf("Register: %v", err)
	}

	if _, err := srv.Logout(ctx, &pb.LogoutRequest{RefreshToken: reg.RefreshToken}); err != nil {
		t.Fatalf("Logout: %v", err)
	}
	if _, err := srv.RefreshToken(ctx, &pb.RefreshTokenRequest{RefreshToken: reg.RefreshToken}); status.Code(err) != codes.Unauthenticated {
		t.Errorf("post-logout refresh should fail Unauthenticated, got %v", err)
	}
}

func TestLogout_IdempotentOnUnknownToken(t *testing.T) {
	srv := newTestAuthServer(t)
	resp, err := srv.Logout(context.Background(), &pb.LogoutRequest{RefreshToken: "neverissued"})
	if err != nil {
		t.Fatalf("Logout on unknown token failed: %v", err)
	}
	if !resp.Success {
		t.Errorf("unknown-token Logout returned success=false")
	}
}

// TestResetPassword_RevokesAllRefreshTokens drives the OTP path the way
// the real client would: register → SendEmailCode bypassed by writing
// the reset OTP directly into Redis (the same place keys.CheckEmailCode
// reads it from) → ResetPassword. The refresh token issued at
// registration must be dead after the reset commits.
func TestResetPassword_RevokesAllRefreshTokens(t *testing.T) {
	srv := newTestAuthServer(t)
	attachRedis(t, srv)
	ctx := context.Background()

	reg, err := srv.Register(ctx, &pb.RegisterRequest{Username: "carol_reset", Password: "hunter22", Email: "carol@example.com"})
	if err != nil {
		t.Fatalf("Register: %v", err)
	}

	// Plant a verified reset OTP so ResetPassword's CheckEmailCode passes.
	// The real client would go SendEmailCode → user-eyeballs-mail →
	// ResetPassword, but the OTP storage shape is the contract that matters
	// for revocation — keys.StoreEmailCode is the same call the production
	// path makes.
	if err := plantResetOTP(t, srv, "carol@example.com", "123456"); err != nil {
		t.Fatalf("plant OTP: %v", err)
	}

	if _, err := srv.ResetPassword(ctx, &pb.ResetPasswordRequest{Email: "carol@example.com", Code: "123456", NewPassword: "newpassword"}); err != nil {
		t.Fatalf("ResetPassword: %v", err)
	}

	if _, err := srv.RefreshToken(ctx, &pb.RefreshTokenRequest{RefreshToken: reg.RefreshToken}); status.Code(err) != codes.Unauthenticated {
		t.Errorf("refresh token survived password reset: %v", err)
	}
}

func TestDeleteAccount_RevokesAllRefreshTokens(t *testing.T) {
	srv := newTestAuthServer(t)
	attachRedis(t, srv)
	ctx := context.Background()

	reg, err := srv.Register(ctx, &pb.RegisterRequest{Username: "dan_delete", Password: "hunter22"})
	if err != nil {
		t.Fatalf("Register: %v", err)
	}

	actx := authedCtx(reg.UserId)
	if _, err := srv.DeleteAccount(actx, &pb.DeleteAccountRequest{}); err != nil {
		t.Fatalf("DeleteAccount: %v", err)
	}

	if _, err := srv.RefreshToken(ctx, &pb.RefreshTokenRequest{RefreshToken: reg.RefreshToken}); status.Code(err) != codes.Unauthenticated {
		t.Errorf("refresh token survived account delete")
	}
}
