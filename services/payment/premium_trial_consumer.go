package main

import (
	"context"
	"errors"
	"log"
	"strconv"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"

	"quiz-battle/pkg/coins/shop"
)

// premiumTrialDefaultDays is the fallback when an outbox row's payload is
// missing or unparseable. The shop catalog ships a 3-day trial today; if a
// future SKU lands without a `days` metadata key, we'd rather grant the
// minimum-known value than 0 days (which would be a debit-without-effect).
const premiumTrialDefaultDays = 3

// premiumTrialPollInterval throttles the outbox sweep. Tight enough that a
// purchase feels instant on the client (typical apply window <2s under
// normal conditions); loose enough that an idle stack doesn't hammer
// Mongo with empty Find calls.
const premiumTrialPollInterval = time.Second

// startPremiumTrialConsumer launches a background goroutine that drains
// `coin_effect_outbox` rows of kind="premium_trial" — the §4.3 PR 5
// transactional-outbox handoff between the shop's coin debit (in scoring)
// and the actual `users.planExpiresAt` extension (here in payment).
//
// The shop's Purchase.Buy writes the outbox row inside the same Mongo
// transaction as the ledger insert, so a successful debit guarantees the
// row exists. This worker:
//
//  1. Polls DequeueDue (oldest unprocessed first, capped batch).
//  2. For each row: extends `planExpiresAt` by the metadata `days` value
//     (defaulting to premiumTrialDefaultDays), flips the user's `plan` to
//     "premium". Renewal-aware: if the existing expiry is in the future,
//     we extend from THAT date instead of `now` so a user who buys two
//     trials back-to-back gets the additive days, not a re-anchor that
//     overwrites the time they'd already paid for.
//  3. Calls MarkProcessed to flip `processedAt` so the next poll skips
//     this row. The flip is the consumer's idempotency point — a crash
//     between step 2 and step 3 would re-extend on retry, which is the
//     "renewal-aware extends from existing expiry" behavior above
//     accepting on a real renewal but is a (rare) over-grant on a
//     mid-row crash. Acceptable trade-off documented in ADR-0003.
//
// Errors during step 2/3 are logged and the row is left unprocessed so
// the next tick retries. Hard failures (Mongo down) loop with the poll
// interval as the backoff; an operator alert on outbox queue depth is
// the floor.
func (s *paymentServer) startPremiumTrialConsumer(ctx context.Context) {
	go func() {
		t := time.NewTicker(premiumTrialPollInterval)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				s.drainPremiumTrialOutbox(ctx)
			}
		}
	}()
}

func (s *paymentServer) drainPremiumTrialOutbox(ctx context.Context) {
	db := s.mongoClient.Database(s.dbName)
	rows, err := shop.DequeueDue(ctx, db, "premium_trial", 32)
	if err != nil {
		log.Printf("[payment] premium-trial outbox dequeue: %v", err)
		return
	}
	for _, r := range rows {
		s.applyPremiumTrialRow(ctx, db, r)
	}
}

// applyPremiumTrialRow processes a single outbox row. Split out so it
// returns early on per-row error without breaking the surrounding loop.
func (s *paymentServer) applyPremiumTrialRow(ctx context.Context, db *mongo.Database, r shop.OutboxRow) {
	days, _ := strconv.Atoi(r.Payload["days"])
	if days <= 0 {
		days = premiumTrialDefaultDays
	}

	// Renewal-aware extension: if the user already has a planExpiresAt in
	// the future, extend from THERE so we don't shorten an existing trial
	// when a user buys overlapping rows. Read in the same op as the
	// update via FindOneAndUpdate is overkill here (no concurrent writers
	// to this field other than this worker + Razorpay webhook); a plain
	// FindOne+Update is fine since the worker is single-instance.
	var existing struct {
		PlanExpiresAt *time.Time `bson:"planExpiresAt"`
	}
	now := time.Now().UTC()
	if err := s.users().FindOne(ctx, bson.M{"_id": r.UserID}).Decode(&existing); err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			// User was deleted between debit and trial application —
			// rare, but log and mark processed so we stop retrying.
			log.Printf("[payment] premium-trial: user %s gone, marking row %s processed", r.UserID, r.ID)
			if err := shop.MarkProcessed(ctx, db, r.ID); err != nil {
				log.Printf("[payment] mark processed (user gone) %s: %v", r.ID, err)
			}
			return
		}
		log.Printf("[payment] premium-trial: load user %s for row %s: %v", r.UserID, r.ID, err)
		return
	}
	base := now
	if existing.PlanExpiresAt != nil && existing.PlanExpiresAt.After(now) {
		base = *existing.PlanExpiresAt
	}
	expiry := base.Add(time.Duration(days) * 24 * time.Hour)

	// Clear premiumExpiryWarned so the warning worker can re-fire if this
	// new expiry crosses the 3-day threshold; mirrors the existing
	// payment.captured plan-upgrade behavior.
	if _, err := s.users().UpdateOne(ctx,
		bson.M{"_id": r.UserID},
		bson.M{
			"$set":   bson.M{"plan": "premium", "planExpiresAt": expiry},
			"$unset": bson.M{"premiumExpiryWarned": ""},
		},
	); err != nil {
		log.Printf("[payment] premium-trial: extend plan for %s row %s: %v", r.UserID, r.ID, err)
		return
	}

	if err := shop.MarkProcessed(ctx, db, r.ID); err != nil {
		log.Printf("[payment] premium-trial: mark processed %s: %v", r.ID, err)
		return
	}
	log.Printf("[payment] premium-trial granted user=%s days=%d expiresAt=%s row=%s",
		r.UserID, days, expiry.Format(time.RFC3339), r.ID)
}
