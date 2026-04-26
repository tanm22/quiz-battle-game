package main

import (
	"context"
	"encoding/json"
	"testing"

	"go.mongodb.org/mongo-driver/v2/bson"

	"quiz-battle/pkg/coins"
)

func seedReferralRow(t *testing.T, srv *scoringServer, refID, referrerID, refereeID string) {
	t.Helper()
	_, err := srv.mongoDB.Collection("referrals").InsertOne(context.Background(), bson.M{
		"_id":           refID,
		"refereeId":     refereeID,
		"referrerId":    referrerID,
		"rewardGranted": false,
		"status":        "pending",
	})
	if err != nil {
		t.Fatalf("seed referral: %v", err)
	}
}

func TestHandleReferralEvent_GrantsBothPartiesAndFlipsStatus(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	rId := "user_referrer"
	eId := "user_referee"
	seedScoringUser(t, c, db, rId, 0)
	seedScoringUser(t, c, db, eId, 0)
	refID := "ref-" + bson.NewObjectID().Hex()
	seedReferralRow(t, srv, refID, rId, eId)

	body, _ := json.Marshal(map[string]any{
		"referrerId":  rId,
		"refereeId":   eId,
		"refereeName": "Carol",
	})
	if err := srv.handleReferralEvent(context.Background(), body); err != nil {
		t.Fatalf("handleReferralEvent: %v", err)
	}

	rBal, _ := srv.ledger.GetBalance(context.Background(), rId)
	eBal, _ := srv.ledger.GetBalance(context.Background(), eId)
	if rBal != referralReferrerCoins || eBal != referralRefereeCoins {
		t.Errorf("balances: referrer=%d (want %d) referee=%d (want %d)",
			rBal, referralReferrerCoins, eBal, referralRefereeCoins)
	}

	for _, want := range []struct{ uid, refKey, reason string }{
		{rId, "referral:" + refID + ":referrer", coins.ReasonReferralReferrer},
		{eId, "referral:" + refID + ":referee", coins.ReasonReferralReferee},
	} {
		n, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(),
			bson.M{"userId": want.uid, "refId": want.refKey, "reason": want.reason})
		if n != 1 {
			t.Errorf("missing ledger row for %s/%s", want.uid, want.reason)
		}
	}

	var ref struct {
		Status        string `bson:"status"`
		RewardGranted bool   `bson:"rewardGranted"`
	}
	_ = srv.mongoDB.Collection("referrals").FindOne(context.Background(), bson.M{"_id": refID}).Decode(&ref)
	if ref.Status != "converted" || !ref.RewardGranted {
		t.Errorf("referral not flipped: %+v", ref)
	}
}

func TestHandleReferralEvent_IdempotentOnRedelivery(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	rId := "user_r2"
	eId := "user_e2"
	seedScoringUser(t, c, db, rId, 0)
	seedScoringUser(t, c, db, eId, 0)
	refID := "ref-" + bson.NewObjectID().Hex()
	seedReferralRow(t, srv, refID, rId, eId)

	body, _ := json.Marshal(map[string]any{"referrerId": rId, "refereeId": eId, "refereeName": "Dan"})
	for i := 0; i < 3; i++ {
		if err := srv.handleReferralEvent(context.Background(), body); err != nil {
			t.Fatalf("dispatch %d: %v", i, err)
		}
	}

	rBal, _ := srv.ledger.GetBalance(context.Background(), rId)
	eBal, _ := srv.ledger.GetBalance(context.Background(), eId)
	if rBal != referralReferrerCoins || eBal != referralRefereeCoins {
		t.Errorf("redelivery double-credited: referrer=%d referee=%d", rBal, eBal)
	}
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(), bson.M{
		"refId": bson.M{"$in": bson.A{
			"referral:" + refID + ":referrer",
			"referral:" + refID + ":referee",
		}},
	})
	if count != 2 {
		t.Errorf("expected exactly 2 ledger rows after 3 deliveries, got %d", count)
	}
}

func TestHandleReferralEvent_NoReferralRow(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "user_lonely", 0)

	body, _ := json.Marshal(map[string]any{
		"referrerId": "user_lonely", "refereeId": "user_ghost",
	})
	if err := srv.handleReferralEvent(context.Background(), body); err != nil {
		t.Fatalf("expected nil error for missing referral, got %v", err)
	}
	bal, _ := srv.ledger.GetBalance(context.Background(), "user_lonely")
	if bal != 0 {
		t.Errorf("no referral row → no grant; balance %d", bal)
	}
}

func TestHandleReferralEvent_BadPayload(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	if err := srv.handleReferralEvent(context.Background(), []byte("{not json")); err == nil {
		t.Fatal("expected decode error")
	}
}
