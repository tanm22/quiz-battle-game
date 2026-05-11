package main

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"

	"quiz-battle/pkg/coins/shop"
	"quiz-battle/pkg/log"
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
		log.FromContext(ctx).Error("premium-trial outbox dequeue failed", "err", err)
		return
	}
	for _, r := range rows {
		s.applyPremiumTrialRow(ctx, db, r)
	}
}

// applyPremiumTrialRow processes a single outbox row. Split out so it
// returns early on per-row error without breaking the surrounding loop.
//
// Atomicity: read user → compute expiry → user UpdateOne → MarkProcessed
// all run inside ONE Mongo transaction. Without this, a transient
// MarkProcessed failure (Mongo blip, context deadline mid-op, network
// reset) would leave planExpiresAt extended but the row still pending.
// On the next 1s poll the renewal-aware base would read the freshly-
// extended expiry as the existing trial and re-extend from THERE,
// granting `2 * days` for a single purchase. The transaction collapses
// that whole window: either both writes commit and the row never re-
// enters DequeueDue, or neither writes and the next poll starts from
// the original (untouched) state.
//
// Concurrency note: rs0 supports read-snapshot inside transactions, so
// the read-then-update against `users` is consistent with `MarkProcessed`
// against `coin_effect_outbox` even though they're different collections.
func (s *paymentServer) applyPremiumTrialRow(ctx context.Context, db *mongo.Database, r shop.OutboxRow) {
	days, _ := strconv.Atoi(r.Payload["days"])
	if days <= 0 {
		days = premiumTrialDefaultDays
	}

	session, err := s.mongoClient.StartSession()
	if err != nil {
		log.FromContext(ctx).Error("premium-trial start session failed", "row_id", r.ID, "err", err)
		return
	}
	defer session.EndSession(ctx)

	now := time.Now().UTC()
	res, err := session.WithTransaction(ctx, func(sc context.Context) (any, error) {
		// Re-read inside the session so the renewal-aware base is the
		// snapshot the txn commits against. A non-existent user here is
		// not a transient error — log it, mark the row processed in the
		// SAME txn so we don't spin retrying, and ack with a sentinel.
		var existing struct {
			PlanExpiresAt *time.Time `bson:"planExpiresAt"`
		}
		if err := s.users().FindOne(sc, bson.M{"_id": r.UserID}).Decode(&existing); err != nil {
			if errors.Is(err, mongo.ErrNoDocuments) {
				if err := markProcessedInSession(sc, db, r.ID); err != nil {
					return nil, fmt.Errorf("mark processed (user gone): %w", err)
				}
				return userGoneSentinel{}, nil
			}
			return nil, fmt.Errorf("load user: %w", err)
		}

		base := now
		if existing.PlanExpiresAt != nil && existing.PlanExpiresAt.After(now) {
			base = *existing.PlanExpiresAt
		}
		expiry := base.Add(time.Duration(days) * 24 * time.Hour)

		// Clear premiumExpiryWarned so the warning worker can re-fire if
		// this new expiry crosses the 3-day threshold; mirrors the
		// existing payment.captured plan-upgrade behavior.
		if _, err := s.users().UpdateOne(sc,
			bson.M{"_id": r.UserID},
			bson.M{
				"$set":   bson.M{"plan": "premium", "planExpiresAt": expiry},
				"$unset": bson.M{"premiumExpiryWarned": ""},
			},
		); err != nil {
			return nil, fmt.Errorf("extend plan: %w", err)
		}

		if err := markProcessedInSession(sc, db, r.ID); err != nil {
			return nil, fmt.Errorf("mark processed: %w", err)
		}
		return expiry, nil
	})
	if err != nil {
		log.FromContext(ctx).Warn("premium-trial txn aborted; will retry", "row_id", r.ID, "err", err)
		return
	}

	if _, gone := res.(userGoneSentinel); gone {
		log.FromContext(ctx).Info("premium-trial user gone; row marked processed", "user_id", r.UserID, "row_id", r.ID)
		return
	}
	log.FromContext(ctx).Info("premium-trial granted",
		"user_id", r.UserID,
		"days", days,
		"expires_at", res.(time.Time).Format(time.RFC3339),
		"row_id", r.ID,
	)
}

// userGoneSentinel is the WithTransaction return value used when the
// targeted user document doesn't exist. Lets the caller distinguish
// "trial granted" from "row marked processed because nothing to grant"
// without a magic time.Time value.
type userGoneSentinel struct{}

// markProcessedInSession is the session-aware variant of
// shop.MarkProcessed. Inlined here rather than added to the shop package
// because (a) it's the only consumer that needs in-session marking, and
// (b) the field shape lives in shop.OutboxRow's bson tags, so this stays
// trivially synced.
func markProcessedInSession(sc context.Context, db *mongo.Database, id string) error {
	now := time.Now().UTC()
	_, err := db.Collection(shop.EffectOutboxCollection).UpdateOne(sc,
		bson.M{"_id": id},
		bson.M{"$set": bson.M{"processedAt": now}},
	)
	return err
}
