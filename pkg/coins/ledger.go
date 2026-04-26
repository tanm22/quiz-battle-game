// Package coins owns the server-authoritative coin ledger. Every balance
// change in the system MUST go through Ledger.Grant (or GrantInSession when
// the caller already holds an outer session). The invariant the rest of the
// codebase relies on:
//
//	If users.coins changed, there is exactly one matching coin_ledger row
//	with the same delta and a balanceAfter that equals the post-state.
//
// Idempotency is enforced by a unique compound index on
// (userId, refId, reason). Producers use natural keys for refId so the same
// real-world event always hashes to the same row:
//
//	streak.daily_reward    →  "streak:<userId>:<YYYY-MM-DD-IST>"
//	match.win              →  "match:<roomId>"
//	referral.referrer      →  "referral:<referralId>:referrer"
//	referral.referee       →  "referral:<referralId>:referee"
//	tournament.placement   →  "tournament:<tournamentId>:user:<userId>"
//	shop.purchase          →  "purchase:<userId>:<itemId>:<weekISO?>"
//
// The ledger uses Mongo transactions on a single-node replica set. Writes
// race-safe across goroutines and across processes; the dup-key recovery
// path in Grant handles the case where two sessions both saw "no row" and
// only one wins the InsertOne.
package coins

import (
	"context"
	"errors"
	"fmt"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// LedgerEntry is the canonical shape of a coin_ledger document. Immutable
// once written — all fields are set in a single InsertOne and never updated.
type LedgerEntry struct {
	ID           string            `bson:"_id"`
	UserID       string            `bson:"userId"`
	Delta        int64             `bson:"delta"`
	Reason       string            `bson:"reason"`
	RefID        string            `bson:"refId"`
	BalanceAfter int64             `bson:"balanceAfter"`
	Metadata     map[string]string `bson:"metadata,omitempty"`
	CreatedAt    time.Time         `bson:"createdAt"`
}

// Reason constants are the only valid values for LedgerEntry.Reason. Adding
// a new earning/spending source requires both a constant here and an entry
// in validReasons below.
const (
	ReasonDailyReward      = "streak.daily_reward"
	ReasonStreakBonus      = "streak.bonus"
	ReasonMatchWin         = "match.win"
	ReasonReferralReferrer = "referral.referrer"
	ReasonReferralReferee  = "referral.referee"
	ReasonTournamentPrize  = "tournament.placement"
	ReasonShopPurchase     = "shop.purchase"
	ReasonShopRefund       = "shop.refund"
	ReasonAdminAdjustment  = "admin.adjustment"
)

var validReasons = map[string]struct{}{
	ReasonDailyReward:      {},
	ReasonStreakBonus:      {},
	ReasonMatchWin:         {},
	ReasonReferralReferrer: {},
	ReasonReferralReferee:  {},
	ReasonTournamentPrize:  {},
	ReasonShopPurchase:     {},
	ReasonShopRefund:       {},
	ReasonAdminAdjustment:  {},
}

// Ledger wraps a Mongo client + database name. Cheap to construct; the
// services hold a single instance for their process lifetime.
type Ledger struct {
	client *mongo.Client
	dbName string
}

func NewLedger(client *mongo.Client, dbName string) *Ledger {
	return &Ledger{client: client, dbName: dbName}
}

func (l *Ledger) users() *mongo.Collection { return l.client.Database(l.dbName).Collection("users") }
func (l *Ledger) ledger() *mongo.Collection {
	return l.client.Database(l.dbName).Collection("coin_ledger")
}

// Grant applies delta (positive or negative) atomically with a ledger entry.
// (userID, refID, reason) is the idempotency key — repeat calls for the same
// triple return the existing entry without mutating state.
//
// Returns:
//   - ErrAmountInvalid if delta == 0
//   - ErrUnknownReason if reason is not in validReasons
//   - ErrMissingRefID if refID is empty
//   - ErrInsufficientBalance if delta < 0 and the user's balance would go negative
//   - any underlying Mongo error otherwise
//
// Concurrency: two simultaneous calls with the same (userID, refID, reason)
// race; one wins the InsertOne, the other sees E11000 inside its session,
// which the dup-key recovery path below resolves by re-reading the winner
// outside any session.
func (l *Ledger) Grant(ctx context.Context, userID string, delta int64, reason, refID string, metadata map[string]string) (*LedgerEntry, error) {
	if delta == 0 {
		return nil, ErrAmountInvalid
	}
	if _, ok := validReasons[reason]; !ok {
		return nil, ErrUnknownReason
	}
	if refID == "" {
		return nil, ErrMissingRefID
	}

	// Fast path: idempotent replay. Read outside any session — fine because
	// we re-check inside the txn callback for race-safety. Saves a session
	// startup on the common "already granted" path.
	var existing LedgerEntry
	err := l.ledger().FindOne(ctx, bson.M{"userId": userID, "refId": refID, "reason": reason}).Decode(&existing)
	if err == nil {
		return &existing, nil
	} else if !errors.Is(err, mongo.ErrNoDocuments) {
		return nil, err
	}

	session, err := l.client.StartSession()
	if err != nil {
		return nil, err
	}
	defer session.EndSession(ctx)

	result, err := session.WithTransaction(ctx, func(sc context.Context) (any, error) {
		return l.grantInSession(sc, userID, delta, reason, refID, metadata)
	})
	if err != nil {
		// Concurrent first-time grant from another session committed first.
		// Mongo transactions use snapshot isolation, so we couldn't see the
		// winner's write from inside our (now-aborted) session. Re-read
		// OUTSIDE any session — that uses default read concern and will
		// surface the committed entry.
		if mongo.IsDuplicateKeyError(err) {
			var winner LedgerEntry
			if e2 := l.ledger().FindOne(ctx, bson.M{"userId": userID, "refId": refID, "reason": reason}).Decode(&winner); e2 == nil {
				return &winner, nil
			}
		}
		return nil, err
	}
	return result.(*LedgerEntry), nil
}

// GrantInSession is the caller-holds-the-session variant. Use this when an
// outer orchestrator (e.g. shop.Purchase) needs to atomically combine the
// coin grant with other writes inside the same Mongo transaction. The
// caller's WithTransaction wrapper is responsible for dup-key recovery.
//
// DO NOT call from request handlers that don't already have an outer
// session — use Grant() for those.
func (l *Ledger) GrantInSession(sc context.Context, userID string, delta int64, reason, refID string, metadata map[string]string) (*LedgerEntry, error) {
	if delta == 0 {
		return nil, ErrAmountInvalid
	}
	if _, ok := validReasons[reason]; !ok {
		return nil, ErrUnknownReason
	}
	if refID == "" {
		return nil, ErrMissingRefID
	}
	// Fast path inside the session — the session sees its own writes, so a
	// re-call within the same orchestrator returns the existing row.
	var existing LedgerEntry
	err := l.ledger().FindOne(sc, bson.M{"userId": userID, "refId": refID, "reason": reason}).Decode(&existing)
	if err == nil {
		return &existing, nil
	} else if !errors.Is(err, mongo.ErrNoDocuments) {
		return nil, err
	}
	return l.grantInSession(sc, userID, delta, reason, refID, metadata)
}

// grantInSession performs read-check-insert-inc inside an existing session.
// InsertOne can fail with E11000 if another session won the race on
// (userId, refId, reason); that error bubbles up to the caller's
// WithTransaction wrapper, which handles dup-key recovery via an
// out-of-session re-read. DO NOT try to recover from E11000 here — the
// session is already poisoned and snapshot isolation hides the winner.
func (l *Ledger) grantInSession(sc context.Context, userID string, delta int64, reason, refID string, metadata map[string]string) (*LedgerEntry, error) {
	var user struct {
		Coins int64 `bson:"coins"`
	}
	if err := l.users().FindOne(sc, bson.M{"_id": userID}).Decode(&user); err != nil {
		return nil, err
	}
	if delta < 0 && user.Coins+delta < 0 {
		return nil, ErrInsufficientBalance
	}

	entry := &LedgerEntry{
		ID:           bson.NewObjectID().Hex(),
		UserID:       userID,
		Delta:        delta,
		Reason:       reason,
		RefID:        refID,
		BalanceAfter: user.Coins + delta,
		Metadata:     metadata,
		CreatedAt:    time.Now().UTC(),
	}
	if _, err := l.ledger().InsertOne(sc, entry); err != nil {
		return nil, err // caller's WithTransaction handles dup-key
	}
	if _, err := l.users().UpdateOne(sc, bson.M{"_id": userID},
		bson.M{"$inc": bson.M{"coins": delta}}); err != nil {
		return nil, err
	}
	return entry, nil
}

// GetBalance returns the user's current cached balance from users.coins.
// This is consistent with the ledger by construction — every $inc is
// guarded by a transaction that also wrote a ledger row.
func (l *Ledger) GetBalance(ctx context.Context, userID string) (int64, error) {
	var user struct {
		Coins int64 `bson:"coins"`
	}
	if err := l.users().FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
		return 0, err
	}
	return user.Coins, nil
}

// GetLedger returns ledger entries for a user, newest first, paged by a
// createdAt cursor. pageSize is clamped to [1, 100] with a default of 25.
// Empty pageToken returns the first page; the returned next-page-token is
// empty when there are no further entries.
//
// The cursor is the createdAt timestamp of the last row of the previous
// page, RFC3339Nano formatted. This is exact (no off-by-one) because we
// fetch pageSize+1 rows and slice off the trailing one to detect a next
// page; the next call uses a strict $lt filter.
func (l *Ledger) GetLedger(ctx context.Context, userID string, pageSize int32, pageToken string) ([]*LedgerEntry, string, error) {
	if pageSize <= 0 || pageSize > 100 {
		pageSize = 25
	}
	filter := bson.M{"userId": userID}
	if pageToken != "" {
		t, err := time.Parse(time.RFC3339Nano, pageToken)
		if err != nil {
			return nil, "", fmt.Errorf("invalid pageToken: %w", err)
		}
		filter["createdAt"] = bson.M{"$lt": t}
	}
	cur, err := l.ledger().Find(ctx, filter,
		options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}}).SetLimit(int64(pageSize)+1),
	)
	if err != nil {
		return nil, "", err
	}
	defer cur.Close(ctx)

	var rows []*LedgerEntry
	if err := cur.All(ctx, &rows); err != nil {
		return nil, "", err
	}
	var next string
	if int32(len(rows)) > pageSize {
		next = rows[pageSize-1].CreatedAt.Format(time.RFC3339Nano)
		rows = rows[:pageSize]
	}
	return rows, next, nil
}
