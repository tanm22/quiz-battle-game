package main

import (
	"context"
	"testing"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "quiz-battle/proto"
)

// TestAuthServiceEnforcement_RejectsUnauthenticated proves that every
// non-skip-listed RPC on the auth service rejects calls without a JWT.
// One test per RPC would be verbose — the gain is the security
// contract is enforced via a single table that every future authed
// RPC can opt into when it's added.
//
// The pkg/auth interceptor tests prove the interceptor logic; this
// test proves the handlers themselves call UserIDFromContext as
// defense-in-depth (so a refactor that accidentally drops the
// interceptor wiring would still get caught).
func TestAuthServiceEnforcement_RejectsUnauthenticated(t *testing.T) {
	srv := newTestAuthServer(t)
	ctx := context.Background() // no JWT in context — should always reject

	cases := []struct {
		method string
		call   func() error
	}{
		{"GetProfile", func() error {
			_, err := srv.GetProfile(ctx, &pb.GetProfileRequest{})
			return err
		}},
		{"UpdateProfile", func() error {
			_, err := srv.UpdateProfile(ctx, &pb.UpdateProfileRequest{DisplayName: "x"})
			return err
		}},
		{"LinkEmail", func() error {
			_, err := srv.LinkEmail(ctx, &pb.LinkEmailRequest{Email: "x@y.z", Code: "000000"})
			return err
		}},
		{"DeleteAccount", func() error {
			_, err := srv.DeleteAccount(ctx, &pb.DeleteAccountRequest{})
			return err
		}},
		{"ClaimDailyReward", func() error {
			_, err := srv.ClaimDailyReward(ctx, &pb.ClaimDailyRewardRequest{})
			return err
		}},
		{"GetStreakInfo", func() error {
			_, err := srv.GetStreakInfo(ctx, &pb.GetStreakInfoRequest{})
			return err
		}},
	}
	for _, tc := range cases {
		t.Run(tc.method, func(t *testing.T) {
			err := tc.call()
			if status.Code(err) != codes.Unauthenticated {
				t.Errorf("%s without JWT: got code=%v err=%v, want Unauthenticated",
					tc.method, status.Code(err), err)
			}
		})
	}
}
