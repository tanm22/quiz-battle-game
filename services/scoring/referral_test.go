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

// publishCapture wires a publishHook that records every (routingKey, body)
// pair. Returns a getter the test calls after the action under test.
func publishCapture(srv *scoringServer) func() []capturedPublish {
	var got []capturedPublish
	srv.publishHook = func(routingKey string, body []byte) {
		got = append(got, capturedPublish{Routing: routingKey, Body: body})
	}
	return func() []capturedPublish { return got }
}

type capturedPublish struct {
	Routing string
	Body    []byte
}

func TestHandleReferralEvent_PublishesEarnsAndFlipsStatus(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	rId := "user_referrer"
	eId := "user_referee"
	seedScoringUser(t, c, db, rId, 0)
	seedScoringUser(t, c, db, eId, 0)
	refID := "ref-" + bson.NewObjectID().Hex()
	seedReferralRow(t, srv, refID, rId, eId)

	captured := publishCapture(srv)

	body, _ := json.Marshal(map[string]any{
		"referrerId":  rId,
		"refereeId":   eId,
		"refereeName": "Carol",
	})
	if err := srv.handleReferralEvent(context.Background(), body); err != nil {
		t.Fatalf("handleReferralEvent: %v", err)
	}

	// New contract: handler PUBLISHES earn events; the earn-consumer
	// (covered by handleEarnEvent tests) is what writes the ledger row.
	// So no ledger rows should exist after just the referral handler runs.
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(), bson.M{})
	if count != 0 {
		t.Errorf("handleReferralEvent must not call Grant directly; got %d ledger rows", count)
	}
	rBal, _ := srv.ledger.GetBalance(context.Background(), rId)
	eBal, _ := srv.ledger.GetBalance(context.Background(), eId)
	if rBal != 0 || eBal != 0 {
		t.Errorf("balances must not change in the referral handler: referrer=%d referee=%d", rBal, eBal)
	}

	pubs := captured()
	wantRoutings := map[string]coins.EarnEvent{
		coins.EarnRoutingKey(coins.EarnSourceReferralReferrer): {
			UserID: rId, Amount: referralReferrerCoins,
			Reason: coins.ReasonReferralReferrer,
			RefID:  "referral:" + refID + ":referrer",
		},
		coins.EarnRoutingKey(coins.EarnSourceReferralReferee): {
			UserID: eId, Amount: referralRefereeCoins,
			Reason: coins.ReasonReferralReferee,
			RefID:  "referral:" + refID + ":referee",
		},
	}
	earnPubs := 0
	for _, p := range pubs {
		want, ok := wantRoutings[p.Routing]
		if !ok {
			continue
		}
		earnPubs++
		var got coins.EarnEvent
		if err := json.Unmarshal(p.Body, &got); err != nil {
			t.Errorf("decode %s: %v", p.Routing, err)
			continue
		}
		if got.UserID != want.UserID || got.Amount != want.Amount ||
			got.Reason != want.Reason || got.RefID != want.RefID {
			t.Errorf("%s payload: got %+v want match on %+v", p.Routing, got, want)
		}
	}
	if earnPubs != 2 {
		t.Errorf("expected 2 earn publishes (referrer+referee), got %d (all pubs: %+v)", earnPubs, pubs)
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

	captured := publishCapture(srv)
	body, _ := json.Marshal(map[string]any{"referrerId": rId, "refereeId": eId, "refereeName": "Dan"})

	for i := 0; i < 3; i++ {
		if err := srv.handleReferralEvent(context.Background(), body); err != nil {
			t.Fatalf("dispatch %d: %v", i, err)
		}
	}

	// First call publishes 2 earn events + 1 notif. Subsequent calls see
	// rewardGranted=true and short-circuit before any publish.
	earnPubs := 0
	for _, p := range captured() {
		if p.Routing == coins.EarnRoutingKey(coins.EarnSourceReferralReferrer) ||
			p.Routing == coins.EarnRoutingKey(coins.EarnSourceReferralReferee) {
			earnPubs++
		}
	}
	if earnPubs != 2 {
		t.Errorf("3 deliveries should produce 2 earn publishes (only first delivery acts), got %d", earnPubs)
	}
}

func TestHandleReferralEvent_NoReferralRow(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "user_lonely", 0)
	captured := publishCapture(srv)

	body, _ := json.Marshal(map[string]any{
		"referrerId": "user_lonely", "refereeId": "user_ghost",
	})
	if err := srv.handleReferralEvent(context.Background(), body); err != nil {
		t.Fatalf("expected nil error for missing referral, got %v", err)
	}
	for _, p := range captured() {
		if p.Routing == coins.EarnRoutingKey(coins.EarnSourceReferralReferrer) ||
			p.Routing == coins.EarnRoutingKey(coins.EarnSourceReferralReferee) {
			t.Errorf("must not publish earn for missing referral row; got %s", p.Routing)
		}
	}
}

func TestHandleReferralEvent_BadPayload(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	if err := srv.handleReferralEvent(context.Background(), []byte("{not json")); err == nil {
		t.Fatal("expected decode error")
	}
}

func TestHandleReferralEvent_RoundTripsThroughEarnConsumer(t *testing.T) {
	// End-to-end: hand the published earn events back to the same service's
	// handleEarnEvent and verify the credits land. Proves the two halves
	// are wire-compatible without standing up RabbitMQ.
	srv, c, db := scoringTestEnv(t)
	rId := "user_e2e_r"
	eId := "user_e2e_e"
	seedScoringUser(t, c, db, rId, 0)
	seedScoringUser(t, c, db, eId, 0)
	refID := "ref-" + bson.NewObjectID().Hex()
	seedReferralRow(t, srv, refID, rId, eId)

	captured := publishCapture(srv)
	body, _ := json.Marshal(map[string]any{"referrerId": rId, "refereeId": eId, "refereeName": "Eve"})
	if err := srv.handleReferralEvent(context.Background(), body); err != nil {
		t.Fatalf("referral handler: %v", err)
	}

	// Replay each earn publish into the consumer.
	for _, p := range captured() {
		if p.Routing != coins.EarnRoutingKey(coins.EarnSourceReferralReferrer) &&
			p.Routing != coins.EarnRoutingKey(coins.EarnSourceReferralReferee) {
			continue
		}
		if err := srv.handleEarnEvent(context.Background(), p.Body); err != nil {
			t.Fatalf("earn consumer dispatch %s: %v", p.Routing, err)
		}
	}

	rBal, _ := srv.ledger.GetBalance(context.Background(), rId)
	eBal, _ := srv.ledger.GetBalance(context.Background(), eId)
	if rBal != referralReferrerCoins || eBal != referralRefereeCoins {
		t.Errorf("end-to-end balances: referrer=%d (want %d) referee=%d (want %d)",
			rBal, referralReferrerCoins, eBal, referralRefereeCoins)
	}
}
