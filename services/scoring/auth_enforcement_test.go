package main

import (
	"context"
	"testing"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "quiz-battle/proto"
)

// TestScoringServiceEnforcement_RejectsUnauthenticated verifies that
// every authenticated scoring RPC rejects callers without a JWT.
// Defense-in-depth proof: the unary interceptor is already registered
// in main.go but if a refactor accidentally drops it from this
// service's grpc.NewServer args, these handler-level checks must
// still reject anonymous calls.
//
// Picks one representative RPC per concern area (leaderboard, match
// history, friends, coins, shop, referrals, notifications, analytics)
// to keep the table dense without exploding LOC.
func TestScoringServiceEnforcement_RejectsUnauthenticated(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	ctx := context.Background() // no JWT — must always reject

	cases := []struct {
		method string
		call   func() error
	}{
		{"GetLeaderboard", func() error {
			_, err := srv.GetLeaderboard(ctx, &pb.GetLeaderboardRequest{RoomId: "room-x"})
			return err
		}},
		{"GetMatchHistory", func() error {
			_, err := srv.GetMatchHistory(ctx, &pb.GetMatchHistoryRequest{})
			return err
		}},
		{"GetHomeScreenData", func() error {
			_, err := srv.GetHomeScreenData(ctx, &pb.GetHomeScreenDataRequest{})
			return err
		}},
		{"GetGlobalLeaderboard", func() error {
			_, err := srv.GetGlobalLeaderboard(ctx, &pb.GetGlobalLeaderboardRequest{})
			return err
		}},
		{"GetCoinBalance", func() error {
			_, err := srv.GetCoinBalance(ctx, &pb.GetCoinBalanceRequest{})
			return err
		}},
		{"GetShopCatalog", func() error {
			_, err := srv.GetShopCatalog(ctx, &pb.GetShopCatalogRequest{})
			return err
		}},
		{"PurchaseShopItem", func() error {
			_, err := srv.PurchaseShopItem(ctx, &pb.PurchaseShopItemRequest{ItemId: "x"})
			return err
		}},
		{"SendFriendRequest", func() error {
			_, err := srv.SendFriendRequest(ctx, &pb.SendFriendRequestRequest{TargetUsername: "x"})
			return err
		}},
		{"ChallengeFriend", func() error {
			_, err := srv.ChallengeFriend(ctx, &pb.ChallengeFriendRequest{FriendUserId: "x"})
			return err
		}},
		{"GetReferralDashboard", func() error {
			_, err := srv.GetReferralDashboard(ctx, &pb.GetReferralDashboardRequest{})
			return err
		}},
		{"UpdateNotificationPrefs", func() error {
			_, err := srv.UpdateNotificationPrefs(ctx, &pb.UpdateNotificationPrefsRequest{})
			return err
		}},
		{"GetUserAnalytics", func() error {
			_, err := srv.GetUserAnalytics(ctx, &pb.GetUserAnalyticsRequest{})
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
