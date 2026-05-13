package main

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"go.mongodb.org/mongo-driver/v2/bson"

	"quiz-battle/pkg/coins"
)

func TestHandleEarnEvent_GrantsAndIsIdempotent(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	uid := "alice"
	seedScoringUser(t, c, db, uid, 0)

	ev := coins.EarnEvent{
		Event:  coins.EarnRoutingKey(coins.EarnSourceMatchWin),
		UserID: uid,
		Amount: 75,
		Reason: coins.ReasonMatchWin,
		RefID:  "match:m9:user:" + uid,
	}
	body, _ := json.Marshal(ev)

	if err := srv.handleEarnEvent(context.Background(), body); err != nil {
		t.Fatalf("first dispatch: %v", err)
	}
	if err := srv.handleEarnEvent(context.Background(), body); err != nil {
		t.Fatalf("redelivery: %v", err)
	}

	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(),
		bson.M{"userId": uid, "refId": ev.RefID})
	if count != 1 {
		t.Errorf("expected exactly 1 ledger row across 2 deliveries, got %d", count)
	}
	bal, _ := srv.ledger.GetBalance(context.Background(), uid)
	if bal != 75 {
		t.Errorf("balance double-credited: got %d, want 75", bal)
	}
}

func TestHandleEarnEvent_RejectsBadPayloads(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	cases := []struct {
		name string
		body []byte
	}{
		{"not json", []byte("{not json")},
		{"missing userId", mustJSON(coins.EarnEvent{Amount: 10, Reason: coins.ReasonMatchWin, RefID: "x"})},
		{"missing reason", mustJSON(coins.EarnEvent{UserID: "alice", Amount: 10, RefID: "x"})},
		{"missing refId", mustJSON(coins.EarnEvent{UserID: "alice", Amount: 10, Reason: coins.ReasonMatchWin})},
		{"zero amount", mustJSON(coins.EarnEvent{UserID: "alice", Amount: 0, Reason: coins.ReasonMatchWin, RefID: "x"})},
		{"negative amount", mustJSON(coins.EarnEvent{UserID: "alice", Amount: -1, Reason: coins.ReasonMatchWin, RefID: "x"})},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := srv.handleEarnEvent(context.Background(), tc.body)
			if err == nil {
				t.Fatal("expected error")
			}
			if !errors.Is(err, errBadEarnPayload) {
				t.Errorf("expected errBadEarnPayload, got %v", err)
			}
		})
	}
	// No grants attempted on any of the bad payloads.
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(), bson.M{"userId": "alice"})
	if count != 0 {
		t.Errorf("bad payloads must not write ledger rows, got %d", count)
	}
}

func TestHandleEarnEvent_RejectsSpendSideReasons(t *testing.T) {
	// Defense in depth: any service with `sx`-publish permission can put a
	// message on coins.earn.*. The consumer must NOT honour spend-side
	// reasons (shop.purchase / shop.refund / admin.adjustment) — those
	// belong to the synchronous Purchase RPC + admin tooling. Letting a
	// compromised internal service publish {reason: "admin.adjustment",
	// amount: 1e9} would silently credit any user any amount. We DLQ such
	// payloads (errBadEarnPayload → Nack false,false) so the bad message
	// can't head-of-line-block healthy traffic and surfaces in alerts.
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	spendSide := []string{
		coins.ReasonShopPurchase,
		coins.ReasonShopRefund,
		coins.ReasonAdminAdjustment,
	}
	for _, reason := range spendSide {
		t.Run(reason, func(t *testing.T) {
			body := mustJSON(coins.EarnEvent{
				UserID: "alice", Amount: 10, Reason: reason, RefID: "evil:" + reason,
			})
			err := srv.handleEarnEvent(context.Background(), body)
			if err == nil {
				t.Fatalf("expected reject for spend-side reason %q", reason)
			}
			if !errors.Is(err, errBadEarnPayload) {
				t.Errorf("expected errBadEarnPayload, got %v", err)
			}
		})
	}

	// No grants attempted on any of the rejected reasons.
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(), bson.M{"userId": "alice"})
	if count != 0 {
		t.Errorf("spend-side payloads must not write ledger rows, got %d", count)
	}
}

func TestHandleEarnEvent_RejectsAmountAboveCap(t *testing.T) {
	// A compromised producer publishing {amount: 1e9} would credit a
	// billion coins. Cap any single earn well above the largest
	// legitimate value (the biggest is the 200-coin Two-Week-Streak
	// reward in services/auth/main.go::rewardForDay) so the abuse
	// surface is bounded.
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)

	body := mustJSON(coins.EarnEvent{
		UserID: "alice",
		Amount: coins.MaxEarnAmount + 1,
		Reason: coins.ReasonMatchWin,
		RefID:  "match:huge",
	})
	err := srv.handleEarnEvent(context.Background(), body)
	if err == nil {
		t.Fatal("expected reject for amount over cap")
	}
	if !errors.Is(err, errBadEarnPayload) {
		t.Errorf("expected errBadEarnPayload, got %v", err)
	}
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(), bson.M{"userId": "alice"})
	if count != 0 {
		t.Errorf("over-cap payload must not write ledger row, got %d", count)
	}
}

func TestHandleEarnEvent_UserGoneDLQs(t *testing.T) {
	// A coins.earn.* delivery targeting a user that doesn't exist must NOT
	// requeue forever — the user can't materialize back into existence, so
	// requeue is a poison-message stall. coin-earn-queue is a classic queue
	// without x-delivery-limit (an acknowledged trade-off documented at
	// services/scoring/main.go:2084-2086), so unbounded requeue would
	// head-of-line-block healthy traffic once prefetch=16 fills with
	// ghost-userId messages. Classify user-gone as errBadEarnPayload so
	// the message routes to coin-earn-dlq and surfaces in alerts.
	srv, _, _ := scoringTestEnv(t)
	// Don't seed the user — Grant will fail loading the user.

	body := mustJSON(coins.EarnEvent{
		UserID: "ghost",
		Amount: 10,
		Reason: coins.ReasonMatchWin,
		RefID:  "match:phantom",
	})
	err := srv.handleEarnEvent(context.Background(), body)
	if err == nil {
		t.Fatal("expected error for missing user")
	}
	if !errors.Is(err, errBadEarnPayload) {
		t.Errorf("user-gone should DLQ as errBadEarnPayload, got %v", err)
	}
}

func mustJSON(v any) []byte {
	b, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return b
}
