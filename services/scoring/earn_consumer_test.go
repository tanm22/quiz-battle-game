package main

import (
	"context"
	"encoding/json"
	"testing"

	"go.mongodb.org/mongo-driver/v2/bson"

	"quiz-battle/pkg/coins"
)

func TestEarnConsumer_GrantsAndIsIdempotent(t *testing.T) {
	srv := newTestScoringServer(t)
	uid := createTestUserWithCoins(t, srv, "alice", 0)
	ev := coins.EarnEvent{
		Event:  "coins.earn.match_win",
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
		t.Fatalf("second dispatch (replay): %v", err)
	}

	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(
		context.Background(),
		bson.M{"userId": uid, "refId": ev.RefID},
	)
	if count != 1 {
		t.Errorf("expected 1 ledger row after duplicate, got %d", count)
	}
	bal, _ := srv.ledger.GetBalance(context.Background(), uid)
	if bal != 75 {
		t.Errorf("balance double-credited: got %d, want 75", bal)
	}
}

func TestEarnConsumer_RejectsInvalidPayloads(t *testing.T) {
	srv := newTestScoringServer(t)
	uid := createTestUserWithCoins(t, srv, "alice", 0)

	cases := []struct {
		name string
		ev   coins.EarnEvent
	}{
		{"missing userId", coins.EarnEvent{Amount: 10, Reason: coins.ReasonMatchWin, RefID: "x"}},
		{"zero amount", coins.EarnEvent{UserID: uid, Reason: coins.ReasonMatchWin, RefID: "x"}},
		{"missing reason", coins.EarnEvent{UserID: uid, Amount: 10, RefID: "x"}},
		{"missing refId", coins.EarnEvent{UserID: uid, Amount: 10, Reason: coins.ReasonMatchWin}},
		{"negative amount", coins.EarnEvent{UserID: uid, Amount: -5, Reason: coins.ReasonMatchWin, RefID: "x"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			body, _ := json.Marshal(tc.ev)
			if err := srv.handleEarnEvent(context.Background(), body); err == nil {
				t.Errorf("expected rejection, got nil error")
			}
		})
	}
	// Balance must be untouched.
	bal, _ := srv.ledger.GetBalance(context.Background(), uid)
	if bal != 0 {
		t.Errorf("balance leaked from invalid event: got %d, want 0", bal)
	}
}
