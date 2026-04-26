package main

import (
	"context"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/coins"
	pb "quiz-battle/proto"
)

// todayIST returns today in the same format used by processStreak so the
// test seeds match production logic exactly.
func todayIST() string {
	ist, _ := time.LoadLocation("Asia/Kolkata")
	return time.Now().In(ist).Format("2006-01-02")
}

func TestClaimDailyReward_WritesLedgerEntry(t *testing.T) {
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "alice")

	// Pretend the user has already touched the streak today (login flow).
	today := todayIST()
	_, err := srv.users().UpdateOne(context.Background(), bson.M{"_id": uid},
		bson.M{"$set": bson.M{"streak.lastClaimedDate": today, "streak.current": int(1)}})
	if err != nil {
		t.Fatalf("seed streak: %v", err)
	}

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: uid, Username: "alice"})
	resp, err := srv.ClaimDailyReward(ctx, &pb.ClaimDailyRewardRequest{})
	if err != nil {
		t.Fatalf("ClaimDailyReward: %v", err)
	}
	if resp.Reward == nil || resp.Reward.Coins <= 0 {
		t.Fatalf("expected reward coins > 0, got %+v", resp.Reward)
	}

	// One ledger row, with the right reason and refId shape.
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(),
		bson.M{"userId": uid, "reason": coins.ReasonDailyReward, "refId": "streak:" + uid + ":" + today})
	if count != 1 {
		t.Errorf("expected 1 ledger row, got %d", count)
	}

	// users.coins reflects the grant.
	bal, _ := srv.ledger.GetBalance(context.Background(), uid)
	if bal != resp.Reward.Coins {
		t.Errorf("balance %d, want %d", bal, resp.Reward.Coins)
	}

	// rewardClaimedDate is set so a same-day re-call hits the early return.
	var u struct {
		Streak struct {
			RewardClaimedDate string `bson:"rewardClaimedDate"`
		} `bson:"streak"`
	}
	_ = srv.users().FindOne(context.Background(), bson.M{"_id": uid}).Decode(&u)
	if u.Streak.RewardClaimedDate != today {
		t.Errorf("rewardClaimedDate=%q, want %q", u.Streak.RewardClaimedDate, today)
	}
}

func TestClaimDailyReward_IsIdempotentWithinSameDay(t *testing.T) {
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "bob")

	today := todayIST()
	_, _ = srv.users().UpdateOne(context.Background(), bson.M{"_id": uid},
		bson.M{"$set": bson.M{"streak.lastClaimedDate": today, "streak.current": int(2)}})

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: uid, Username: "bob"})
	first, err := srv.ClaimDailyReward(ctx, &pb.ClaimDailyRewardRequest{})
	if err != nil {
		t.Fatalf("first claim: %v", err)
	}
	second, err := srv.ClaimDailyReward(ctx, &pb.ClaimDailyRewardRequest{})
	if err != nil {
		t.Fatalf("second claim: %v", err)
	}
	if first.Reward.Coins != second.Reward.Coins {
		t.Errorf("reward changed across calls: %d → %d", first.Reward.Coins, second.Reward.Coins)
	}
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(),
		bson.M{"userId": uid, "reason": coins.ReasonDailyReward})
	if count != 1 {
		t.Errorf("ledger should have exactly 1 row across 2 same-day claims, got %d", count)
	}
	bal, _ := srv.ledger.GetBalance(context.Background(), uid)
	if bal != first.Reward.Coins {
		t.Errorf("balance double-credited: got %d, want %d", bal, first.Reward.Coins)
	}
}

func TestClaimDailyReward_RequiresStreakLogin(t *testing.T) {
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "carol")
	// no streak.lastClaimedDate set → must fail FailedPrecondition

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: uid, Username: "carol"})
	_, err := srv.ClaimDailyReward(ctx, &pb.ClaimDailyRewardRequest{})
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}
