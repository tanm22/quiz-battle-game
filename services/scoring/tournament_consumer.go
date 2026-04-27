package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"

	"quiz-battle/pkg/coins"
	"quiz-battle/pkg/log"
)

// errBadTournamentPayload marks unrecoverable parse / shape errors on a
// tournament.finished message so the consumer can dead-letter it instead
// of looping the same broken payload forever.
var errBadTournamentPayload = errors.New("bad tournament payload")

// handleTournamentFinished processes one tournament.finished message —
// the per-winner event the quiz service emits when its finalization worker
// closes a tournament. The grant flows through pkg/coins.Ledger.Grant for
// the §4.3 invariant (no balance change without a ledger row).
//
// Order of operations is reversed from the pre-§4.3 implementation:
//
//	OLD: flip tournament_payouts row → "paid"  →  $inc users.coins
//	     (a coin-grant failure after the flip orphans the row — manual fixup)
//
//	NEW: Grant (idempotent on refId)            →  flip payout row → "paid"
//	     (Grant retries cleanly via the unique index; flip is the dedup gate
//	      for the notification publish, not for the credit itself.)
//
// The (userId, refId, reason) unique index in coin_ledger remains the
// authoritative idempotency layer for the credit; the tournament_payouts
// state machine continues to dedupe the FCM notification.
func (s *scoringServer) handleTournamentFinished(ctx context.Context, body []byte) error {
	var event struct {
		TournamentID   string `json:"tournamentId"`
		TournamentName string `json:"tournamentName"`
		UserID         string `json:"userId"`
		Username       string `json:"username"`
		Rank           int    `json:"rank"`
		CoinsAwarded   int64  `json:"coinsAwarded"`
		FinalScore     int64  `json:"finalScore"`
	}
	if err := json.Unmarshal(body, &event); err != nil {
		return fmt.Errorf("%w: decode: %v", errBadTournamentPayload, err)
	}
	if event.TournamentID == "" || event.UserID == "" {
		return fmt.Errorf("%w: missing tournamentId or userId: %+v", errBadTournamentPayload, event)
	}
	// Negative coinsAwarded is rejected so a producer bug (typo'd
	// tournaments.prizePool, bad migration, etc.) dead-letters here
	// instead of: skipping Grant, flipping the payout to "paid", and
	// publishing a misleading notif. Mirrors handleEarnEvent's guard.
	// `coinsAwarded == 0` is legal — purely-reputational tournaments
	// flip the payout + notify without a credit (test below).
	if event.CoinsAwarded < 0 {
		return fmt.Errorf("%w: coinsAwarded must not be negative (got %d)", errBadTournamentPayload, event.CoinsAwarded)
	}

	// Phantom-winner protection: only credit for events that have a
	// pre-existing tournament_payouts row. The quiz finalizer writes that
	// row immediately before publishing, so under normal flow it always
	// exists. A forged or stale event without a row is dropped.
	var payout struct {
		Status string `bson:"status"`
	}
	err := s.mongoDB.Collection("tournament_payouts").FindOne(ctx, bson.M{
		"tournamentId": event.TournamentID,
		"userId":       event.UserID,
	}).Decode(&payout)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			log.FromContext(ctx).Info("no payout row; discarding event",
				"consumer", "tournament_finished",
				"user_id", event.UserID,
				"tournament_id", event.TournamentID)
			return nil
		}
		return fmt.Errorf("load payout: %w", err)
	}
	if payout.Status == "paid" {
		// Redelivery — the credit happened on a previous delivery.
		return nil
	}

	// §4.3: every credit writes a coin_ledger row inside Grant's
	// transaction. Grant is idempotent on (userId, refId, reason); a
	// retry after a partial failure (e.g. broker redelivery) returns the
	// existing row instead of double-crediting.
	if event.CoinsAwarded > 0 {
		metadata := map[string]string{
			"rank":           fmt.Sprintf("%d", event.Rank),
			"tournamentId":   event.TournamentID,
			"tournamentName": event.TournamentName,
		}
		if _, err := s.ledger.Grant(ctx, event.UserID, event.CoinsAwarded,
			coins.ReasonTournamentPrize,
			"tournament:"+event.TournamentID+":user:"+event.UserID,
			metadata); err != nil {
			return fmt.Errorf("grant: %w", err)
		}
	}

	// Flip the payout row to "paid" — gates the notification publish on
	// the first delivery only. A race lost here (two redeliveries hitting
	// concurrently in a multi-instance setup) means the loser sees
	// ModifiedCount == 0 and skips the notif; the winner's notif still
	// fires. Acceptable: a duplicate FCM is worse than a missing one only
	// in marginal cases.
	res, err := s.mongoDB.Collection("tournament_payouts").UpdateOne(ctx,
		bson.M{
			"tournamentId": event.TournamentID,
			"userId":       event.UserID,
			"status":       bson.M{"$ne": "paid"},
		},
		bson.M{"$set": bson.M{"status": "paid", "paidAt": time.Now()}},
	)
	if err != nil {
		return fmt.Errorf("flip payout: %w", err)
	}
	if res.ModifiedCount == 0 {
		// Lost the race to another delivery — credit was applied
		// (idempotently) but the notif is the other delivery's job.
		return nil
	}

	notifJSON, _ := json.Marshal(map[string]any{
		"event":          "notif.tournament.finished",
		"userId":         event.UserID,
		"username":       event.Username,
		"tournamentId":   event.TournamentID,
		"tournamentName": event.TournamentName,
		"rank":           event.Rank,
		"coinsAwarded":   event.CoinsAwarded,
		"finalScore":     event.FinalScore,
	})
	if err := s.publish(ctx, "notif.tournament.finished", notifJSON); err != nil {
		// Best-effort: a publish failure here permanently loses the FCM
		// because the row is now "paid" and the next redelivery
		// early-returns on payout.Status=="paid" before reaching this
		// publish. A true outbox (durable notif row + drain worker)
		// would close this gap; out of scope for this PR. Operator
		// floor: alert on tournament-finished log volume.
		log.FromContext(ctx).Warn("notif publish failed",
			"consumer", "tournament_finished",
			"user_id", event.UserID,
			"tournament_id", event.TournamentID,
			"err", err)
	}
	log.FromContext(ctx).Info("prize granted via ledger",
		"consumer", "tournament_finished",
		"user_id", event.UserID,
		"tournament_id", event.TournamentID,
		"rank", event.Rank,
		"coins", event.CoinsAwarded)
	return nil
}
