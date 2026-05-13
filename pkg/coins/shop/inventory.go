package shop

import (
	"context"
	"errors"
	"fmt"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
)

// ErrAlreadyOwned signals that a cosmetic AddCosmetic was a no-op because
// the user already had the item. Purchase.Buy propagates this error so the
// transaction aborts and the debit rolls back — debiting coins for an
// asset the user already owns is a silent money-leak. Same-key retries
// never reach this branch (the replay fast-path returns the original
// receipt before the txn starts); fresh-key re-purchases and concurrent
// distinct-key races both correctly fail here.
var ErrAlreadyOwned = errors.New("shop: cosmetic already owned")

// ErrStreakFreezeAlreadyHeldThisWeek is returned by ClaimStreakFreezeForWeek
// when the user has already claimed (or carried over a claim from the same
// ISO week). The Purchase.Buy caller surfaces it as the WEEKLY_CAP error
// code so the Flutter client can render the right message.
var ErrStreakFreezeAlreadyHeldThisWeek = errors.New("shop: streak freeze already purchased this week")

// currentWeekISO returns the user's ISO-8601 year-week label, e.g.
// "2026-W17". UTC is the cap window: rolling at the local midnight of any
// timezone would let users at the international date line claim two
// freezes per "week". A consistent UTC week is simpler and abuse-proof.
func currentWeekISO() string {
	y, w := time.Now().UTC().ISOWeek()
	return fmt.Sprintf("%04d-W%02d", y, w)
}

// InventoryStore mutates inventory state on the users collection. Every
// mutating method takes a session context (sc) so callers running inside a
// WithTransaction can commit the inventory change atomically with the
// matching ledger row in pkg/coins.Ledger.GrantInSession. Callers outside
// a transaction can pass context.Background() — a single-document update
// is always atomic at the document level on its own.
type InventoryStore struct{ db *mongo.Database }

// NewInventory wraps a *mongo.Database. The caller-managed lifetime keeps
// inventory mutations on the same connection pool as the rest of the
// service; the type is stateless beyond the bound database handle.
func NewInventory(db *mongo.Database) *InventoryStore { return &InventoryStore{db: db} }

// AddCosmetic appends itemID to the user's ownedCosmetics set. The $ne
// predicate makes the operation idempotent: a second call for an already-
// owned item is rejected with ErrAlreadyOwned without mutating the array.
func (s *InventoryStore) AddCosmetic(sc context.Context, userID, itemID string) error {
	res, err := s.db.Collection("users").UpdateOne(sc,
		bson.M{"_id": userID, "ownedCosmetics": bson.M{"$ne": itemID}},
		bson.M{"$addToSet": bson.M{"ownedCosmetics": itemID}})
	if err != nil {
		return err
	}
	if res.MatchedCount == 0 {
		return ErrAlreadyOwned
	}
	return nil
}

// IncrementReroll bumps the user's spendable rerollCharges counter by
// charges. Not idempotent on its own — Purchase.Buy guards against double-
// crediting via the coin_reroll_application side collection keyed on the
// ledger entry ID.
func (s *InventoryStore) IncrementReroll(sc context.Context, userID string, charges int32) error {
	_, err := s.db.Collection("users").UpdateOne(sc, bson.M{"_id": userID},
		bson.M{"$inc": bson.M{"rerollCharges": charges}})
	return err
}

// ClaimStreakFreezeForWeek atomically grants the user a held streak-freeze
// for the current ISO week, refusing if one was already claimed this week.
//
// The $ne predicate handles all three cases naturally:
//   - empty string ("" != "2026-W17"): no freeze ever claimed → succeed.
//   - prior week ("2026-W16" != "2026-W17"): carryover allowed → succeed.
//   - current week ("2026-W17" == "2026-W17"): no match → return cap error.
//
// A freeze held from a *previous* week is overwritten on a fresh claim
// (StreakFreezeHeld stays true, StreakFreezeWeekISO advances). This keeps
// the v1 product rule literally "one per week"; if product later wants
// "one freeze ever held at a time", flip the predicate to also reject
// when StreakFreezeHeld is already true.
func (s *InventoryStore) ClaimStreakFreezeForWeek(sc context.Context, userID string) error {
	week := currentWeekISO()
	res, err := s.db.Collection("users").UpdateOne(sc,
		bson.M{"_id": userID, "streakFreezeWeekISO": bson.M{"$ne": week}},
		bson.M{"$set": bson.M{"streakFreezeHeld": true, "streakFreezeWeekISO": week}},
	)
	if err != nil {
		return err
	}
	if res.MatchedCount == 0 {
		return ErrStreakFreezeAlreadyHeldThisWeek
	}
	return nil
}
