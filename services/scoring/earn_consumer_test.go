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

func TestHandleEarnEvent_PropagatesGrantError(t *testing.T) {
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
		t.Fatal("expected grant error for missing user")
	}
	if errors.Is(err, errBadEarnPayload) {
		t.Errorf("missing-user is a grant failure, not a bad-payload error: %v", err)
	}
}

func mustJSON(v any) []byte {
	b, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return b
}
