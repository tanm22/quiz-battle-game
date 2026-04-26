package main

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"

	"quiz-battle/pkg/coins"
)

func seedTournamentPayout(t *testing.T, srv *scoringServer, tournamentID, userID, status string, coinsAwarded int64) {
	t.Helper()
	_, err := srv.mongoDB.Collection("tournament_payouts").InsertOne(context.Background(), bson.M{
		"tournamentId": tournamentID,
		"userId":       userID,
		"username":     userID,
		"rank":         1,
		"coinsAwarded": coinsAwarded,
		"finalScore":   int64(0),
		"status":       status,
		"createdAt":    time.Now(),
	})
	if err != nil {
		t.Fatalf("seed payout: %v", err)
	}
}

func tournamentEvent(tournamentID, userID string, rank int, coinsAwarded int64) []byte {
	body, _ := json.Marshal(map[string]any{
		"tournamentId":   tournamentID,
		"tournamentName": "Test Cup",
		"userId":         userID,
		"username":       userID,
		"rank":           rank,
		"coinsAwarded":   coinsAwarded,
		"finalScore":     int64(123),
	})
	return body
}

func TestHandleTournamentFinished_GrantsViaLedgerAndFlipsPayout(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	tID := "tour-" + bson.NewObjectID().Hex()
	uid := "user_winner"
	seedScoringUser(t, c, db, uid, 0)
	seedTournamentPayout(t, srv, tID, uid, "pending", 1000)

	if err := srv.handleTournamentFinished(context.Background(), tournamentEvent(tID, uid, 1, 1000)); err != nil {
		t.Fatalf("handleTournamentFinished: %v", err)
	}

	// Ledger row written through Grant.
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(),
		bson.M{
			"userId": uid,
			"reason": coins.ReasonTournamentPrize,
			"refId":  "tournament:" + tID + ":user:" + uid,
		})
	if count != 1 {
		t.Errorf("expected 1 ledger row for tournament prize, got %d", count)
	}

	// users.coins reflects the grant — exactly the awarded amount.
	bal, _ := srv.ledger.GetBalance(context.Background(), uid)
	if bal != 1000 {
		t.Errorf("balance: got %d want 1000", bal)
	}

	// payout row flipped to paid with paidAt populated.
	var p struct {
		Status string     `bson:"status"`
		PaidAt *time.Time `bson:"paidAt"`
	}
	_ = srv.mongoDB.Collection("tournament_payouts").FindOne(context.Background(),
		bson.M{"tournamentId": tID, "userId": uid}).Decode(&p)
	if p.Status != "paid" || p.PaidAt == nil {
		t.Errorf("payout not flipped: %+v", p)
	}
}

func TestHandleTournamentFinished_IdempotentOnRedelivery(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	tID := "tour-" + bson.NewObjectID().Hex()
	uid := "user_w2"
	seedScoringUser(t, c, db, uid, 0)
	seedTournamentPayout(t, srv, tID, uid, "pending", 500)

	body := tournamentEvent(tID, uid, 2, 500)
	for i := 0; i < 3; i++ {
		if err := srv.handleTournamentFinished(context.Background(), body); err != nil {
			t.Fatalf("delivery %d: %v", i, err)
		}
	}

	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(),
		bson.M{"userId": uid, "reason": coins.ReasonTournamentPrize})
	if count != 1 {
		t.Errorf("3 deliveries should produce exactly 1 ledger row, got %d", count)
	}
	bal, _ := srv.ledger.GetBalance(context.Background(), uid)
	if bal != 500 {
		t.Errorf("balance double-credited across redeliveries: got %d want 500", bal)
	}
}

func TestHandleTournamentFinished_PhantomWinnerDropsSilently(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	uid := "user_phantom"
	seedScoringUser(t, c, db, uid, 0)
	// No payout row — event is a phantom.

	body := tournamentEvent("tour-ghost", uid, 1, 1000)
	if err := srv.handleTournamentFinished(context.Background(), body); err != nil {
		t.Fatalf("phantom should ack-skip, got %v", err)
	}
	bal, _ := srv.ledger.GetBalance(context.Background(), uid)
	if bal != 0 {
		t.Errorf("phantom event must not credit; balance %d", bal)
	}
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(), bson.M{"userId": uid})
	if count != 0 {
		t.Errorf("no ledger row for phantom; got %d", count)
	}
}

func TestHandleTournamentFinished_AlreadyPaidSkips(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	tID := "tour-" + bson.NewObjectID().Hex()
	uid := "user_paid"
	seedScoringUser(t, c, db, uid, 0)
	seedTournamentPayout(t, srv, tID, uid, "paid", 1000)

	// Seed a sentinel ledger row to prove handleTournamentFinished does
	// NOT call Grant (and therefore wouldn't add another row) when the
	// payout is already paid.
	if err := srv.handleTournamentFinished(context.Background(), tournamentEvent(tID, uid, 1, 1000)); err != nil {
		t.Fatalf("paid → should ack-skip, got %v", err)
	}
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(), bson.M{"userId": uid})
	if count != 0 {
		t.Errorf("already-paid event must not write ledger; got %d", count)
	}
}

func TestHandleTournamentFinished_ZeroCoinsFlipsButDoesNotGrant(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	tID := "tour-" + bson.NewObjectID().Hex()
	uid := "user_token"
	seedScoringUser(t, c, db, uid, 0)
	seedTournamentPayout(t, srv, tID, uid, "pending", 0)

	if err := srv.handleTournamentFinished(context.Background(), tournamentEvent(tID, uid, 11, 0)); err != nil {
		t.Fatalf("zero-coin tournament: %v", err)
	}
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(), bson.M{"userId": uid})
	if count != 0 {
		t.Errorf("zero-coin events must not write ledger; got %d", count)
	}
	var p struct {
		Status string `bson:"status"`
	}
	_ = srv.mongoDB.Collection("tournament_payouts").FindOne(context.Background(),
		bson.M{"tournamentId": tID, "userId": uid}).Decode(&p)
	if p.Status != "paid" {
		t.Errorf("payout still must flip for reputational tournaments: %s", p.Status)
	}
}

func TestHandleTournamentFinished_BadPayloadDLQs(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)

	cases := []struct {
		name string
		body []byte
	}{
		{"not json", []byte("{not json")},
		{"missing tournamentId", []byte(`{"userId":"u1","coinsAwarded":100}`)},
		{"missing userId", []byte(`{"tournamentId":"t1","coinsAwarded":100}`)},
		{"negative coinsAwarded", []byte(`{"tournamentId":"t1","userId":"u1","coinsAwarded":-100}`)},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := srv.handleTournamentFinished(context.Background(), tc.body)
			if err == nil {
				t.Fatal("expected error")
			}
			if !errors.Is(err, errBadTournamentPayload) {
				t.Errorf("expected errBadTournamentPayload, got %v", err)
			}
		})
	}
}

func TestHandleTournamentFinished_NegativeAwardDoesNotMutateState(t *testing.T) {
	// Catches the original review concern: before the guard, a negative
	// coinsAwarded would skip Grant (the > 0 branch) but still flip the
	// payout row to "paid" and publish a notif with the bad amount. With
	// the guard, the message dead-letters and state stays untouched so
	// an operator can investigate the producer-side bug.
	srv, c, db := scoringTestEnv(t)
	tID := "tour-" + bson.NewObjectID().Hex()
	uid := "user_neg"
	seedScoringUser(t, c, db, uid, 0)
	seedTournamentPayout(t, srv, tID, uid, "pending", -50)

	body, _ := json.Marshal(map[string]any{
		"tournamentId": tID, "userId": uid, "coinsAwarded": int64(-50),
	})
	err := srv.handleTournamentFinished(context.Background(), body)
	if !errors.Is(err, errBadTournamentPayload) {
		t.Fatalf("expected errBadTournamentPayload, got %v", err)
	}

	bal, _ := srv.ledger.GetBalance(context.Background(), uid)
	if bal != 0 {
		t.Errorf("balance must not change on negative amount; got %d", bal)
	}
	count, _ := srv.mongoDB.Collection("coin_ledger").CountDocuments(context.Background(), bson.M{"userId": uid})
	if count != 0 {
		t.Errorf("ledger must stay empty on negative amount; got %d", count)
	}
	var p struct {
		Status string `bson:"status"`
	}
	_ = srv.mongoDB.Collection("tournament_payouts").FindOne(context.Background(),
		bson.M{"tournamentId": tID, "userId": uid}).Decode(&p)
	if p.Status == "paid" {
		t.Errorf("payout must NOT flip to paid on negative amount; got status=%q", p.Status)
	}
}

func TestHandleTournamentFinished_GrantBeforeFlipPreservesInvariant(t *testing.T) {
	// Reorder check: the new flow grants FIRST, so that a hypothetical
	// flip failure (Mongo blip on the second UpdateOne) would still leave
	// us with a ledger row matching what was credited. Hard to inject
	// such a failure cleanly; we exercise the ordering by asserting that
	// after a successful run, the ledger entry has a CreatedAt at or
	// before the payout's PaidAt — a witness to "grant happened first".
	//
	// Limitation: this is a timing witness, not a causal-ordering proof.
	// Sub-millisecond writes can land on the same wall-clock instant and
	// `After` would still be false even if the order silently flipped in
	// a future refactor. A truly causal ordering check requires injecting
	// a fault between Grant and the flip; left as a follow-up once a
	// fault-injection seam exists.
	srv, c, db := scoringTestEnv(t)
	tID := "tour-" + bson.NewObjectID().Hex()
	uid := "user_order"
	seedScoringUser(t, c, db, uid, 0)
	seedTournamentPayout(t, srv, tID, uid, "pending", 100)

	if err := srv.handleTournamentFinished(context.Background(), tournamentEvent(tID, uid, 5, 100)); err != nil {
		t.Fatalf("handler: %v", err)
	}

	var entry coins.LedgerEntry
	_ = srv.mongoDB.Collection("coin_ledger").FindOne(context.Background(),
		bson.M{"refId": "tournament:" + tID + ":user:" + uid}).Decode(&entry)
	var p struct {
		PaidAt time.Time `bson:"paidAt"`
	}
	_ = srv.mongoDB.Collection("tournament_payouts").FindOne(context.Background(),
		bson.M{"tournamentId": tID, "userId": uid}).Decode(&p)

	if entry.CreatedAt.IsZero() || p.PaidAt.IsZero() {
		t.Fatalf("missing timestamps: ledger=%v paidAt=%v", entry.CreatedAt, p.PaidAt)
	}
	if entry.CreatedAt.After(p.PaidAt) {
		t.Errorf("ledger.createdAt (%v) should not be after payouts.paidAt (%v) — order would be wrong",
			entry.CreatedAt, p.PaidAt)
	}
}
