package main

import (
	"context"
	"testing"

	"go.mongodb.org/mongo-driver/v2/bson"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/coins"
	pb "quiz-battle/proto"
)

// §4.1: completing onboarding grants a one-time 100-coin welcome bonus,
// recorded through the standard ledger so it shows up in transaction history.
// The grant is idempotent on (userId, refId, reason) — retries of
// UpdateProfile(markOnboardingCompleted: true) must NEVER double-credit.

func TestUpdateProfile_GrantsWelcomeBonusOnFirstCompletion(t *testing.T) {
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "alice")

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: uid, Username: "alice"})
	resp, err := srv.UpdateProfile(ctx, &pb.UpdateProfileRequest{
		OnboardingCompleted: true,
	})
	if err != nil {
		t.Fatalf("UpdateProfile: %v", err)
	}
	if !resp.Success {
		t.Fatal("expected Success=true")
	}

	// User document reflects the credit + the onboarding flag/timestamp.
	var doc bson.M
	if err := srv.users().FindOne(context.Background(), bson.M{"_id": uid}).Decode(&doc); err != nil {
		t.Fatalf("find user: %v", err)
	}
	if got, _ := doc["coins"].(int64); got != 100 {
		t.Errorf("coins: got %v, want 100", doc["coins"])
	}
	if doc["onboardingCompleted"] != true {
		t.Errorf("onboardingCompleted: got %v, want true", doc["onboardingCompleted"])
	}
	if _, ok := doc["onboardingCompletedAt"]; !ok {
		t.Error("onboardingCompletedAt: missing, want set")
	}

	// Exactly one ledger row with the welcome reason and predictable refID.
	var entry bson.M
	err = srv.mongoDB.Collection("coin_ledger").FindOne(context.Background(),
		bson.M{"userId": uid, "reason": coins.ReasonWelcomeBonus}).Decode(&entry)
	if err != nil {
		t.Fatalf("expected 1 ledger row, got error: %v", err)
	}
	if got, _ := entry["delta"].(int64); got != 100 {
		t.Errorf("delta: got %v, want 100", entry["delta"])
	}
	if entry["refId"] != "welcome:"+uid {
		t.Errorf("refId: got %v, want %q", entry["refId"], "welcome:"+uid)
	}

	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(),
		bson.M{"userId": uid, "reason": coins.ReasonWelcomeBonus})
	if count != 1 {
		t.Errorf("expected exactly 1 welcome ledger row, got %d", count)
	}
}

func TestUpdateProfile_WelcomeBonusIsIdempotent(t *testing.T) {
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "bob")

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: uid, Username: "bob"})
	if _, err := srv.UpdateProfile(ctx, &pb.UpdateProfileRequest{OnboardingCompleted: true}); err != nil {
		t.Fatalf("first UpdateProfile: %v", err)
	}
	if _, err := srv.UpdateProfile(ctx, &pb.UpdateProfileRequest{OnboardingCompleted: true}); err != nil {
		t.Fatalf("second UpdateProfile: %v", err)
	}

	// Balance must not have doubled.
	bal, _ := srv.ledger.GetBalance(context.Background(), uid)
	if bal != 100 {
		t.Errorf("balance: got %d, want 100 (idempotency broken — double credit)", bal)
	}

	// Still exactly one ledger row.
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(),
		bson.M{"userId": uid, "reason": coins.ReasonWelcomeBonus})
	if count != 1 {
		t.Errorf("expected exactly 1 welcome ledger row across 2 calls, got %d", count)
	}
}

func TestUpdateProfile_NoBonusWhenOnboardingFlagNotSet(t *testing.T) {
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "carol")

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: uid, Username: "carol"})
	if _, err := srv.UpdateProfile(ctx, &pb.UpdateProfileRequest{DisplayName: "Carol C."}); err != nil {
		t.Fatalf("UpdateProfile: %v", err)
	}

	bal, _ := srv.ledger.GetBalance(context.Background(), uid)
	if bal != 0 {
		t.Errorf("balance: got %d, want 0 (no flag → no bonus)", bal)
	}
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(),
		bson.M{"userId": uid})
	if count != 0 {
		t.Errorf("expected 0 ledger rows, got %d", count)
	}
}

func TestUpdateProfile_NoBonusWhenAlreadyCompleted(t *testing.T) {
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "dave")

	// Pre-seed Mongo so onboardingCompleted is already true and the user
	// already holds 100 coins from a prior welcome bonus. A retry of
	// UpdateProfile(markOnboardingCompleted: true) must be a no-op for the
	// grant — neither the user balance nor the ledger gains another entry.
	_, err := srv.users().UpdateOne(context.Background(),
		bson.M{"_id": uid},
		bson.M{"$set": bson.M{"onboardingCompleted": true, "coins": int64(100)}})
	if err != nil {
		t.Fatalf("seed onboardingCompleted: %v", err)
	}

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: uid, Username: "dave"})
	if _, err := srv.UpdateProfile(ctx, &pb.UpdateProfileRequest{OnboardingCompleted: true}); err != nil {
		t.Fatalf("UpdateProfile: %v", err)
	}

	bal, _ := srv.ledger.GetBalance(context.Background(), uid)
	if bal != 100 {
		t.Errorf("balance: got %d, want 100 (already-completed → no second grant)", bal)
	}
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(),
		bson.M{"userId": uid, "reason": coins.ReasonWelcomeBonus})
	if count != 0 {
		t.Errorf("expected 0 welcome ledger rows (skip grant entirely when already true), got %d", count)
	}
}
