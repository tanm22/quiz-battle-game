package shop

import (
	"context"
	"errors"
	"fmt"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"

	"quiz-battle/pkg/coins"
)

// ErrInactiveItem is returned when the user attempts to buy an item whose
// `active` flag is false in the catalog. Surfaced to the client as the
// INACTIVE error code.
var ErrInactiveItem = errors.New("shop: item not active")

// ErrUnknownItem is returned when the requested itemID isn't in the
// catalog at all. Surfaced as the UNKNOWN error code.
var ErrUnknownItem = errors.New("shop: unknown item")

// PurchaseResult is what a successful Buy returns. LedgerEntryID is the
// authoritative receipt — clients echo it back when retrying so the
// idempotency fast-path matches. Owned indicates whether the item kind
// puts something in the user's cosmetic inventory (so the UI can flip
// the storefront tile to "owned" without an extra inventory fetch).
type PurchaseResult struct {
	LedgerEntryID string
	NewBalance    int64
	Owned         bool
}

// Purchase orchestrates the four-step buy flow (validate → debit → effect
// → outbox) inside one Mongo transaction. Holds a *mongo.Client because
// it needs to start its own session; the bound *mongo.Database is the
// canonical handle for all reads and writes.
type Purchase struct {
	client *mongo.Client
	db     *mongo.Database
	ledger *coins.Ledger
}

// NewPurchase constructs a Purchase bound to a Mongo client/db pair and
// the shared coins.Ledger. The same Ledger instance can (and should) be
// reused by other earn paths in the same service.
func NewPurchase(client *mongo.Client, db *mongo.Database, ledger *coins.Ledger) *Purchase {
	return &Purchase{client: client, db: db, ledger: ledger}
}

// Buy debits the user's balance and applies the item's effect ATOMICALLY in
// one Mongo transaction: ledger insert + users.$inc + inventory mutation +
// (for premium-trial) outbox enqueue all commit together or all roll back.
//
// Idempotency: refId = "purchase:<itemID>:<idempotencyKey>". On a retry
// with the same key, the replay fast-path returns the original entry
// without re-applying the effect — the original transaction already did
// that. Without this, retrying a successful streak-freeze buy would re-
// enter the txn, the in-tx ClaimStreakFreezeForWeek would correctly refuse,
// and the whole transaction would abort, surfacing as a (wrong) "weekly
// cap" error to a legitimate client retry.
//
// Concurrent racers: two simultaneous first-time grants for the same key
// race on the unique (userId, refId, reason) index. Exactly one wins; the
// loser's WithTransaction returns a duplicate-key error and we re-read the
// winning entry out of session (snapshot isolation inside the loser's
// session would otherwise hide the winner's just-committed row).
func (p *Purchase) Buy(ctx context.Context, userID, itemID, idempotencyKey string) (*PurchaseResult, error) {
	if idempotencyKey == "" {
		return nil, errors.New("idempotencyKey required")
	}
	item, err := GetItem(ctx, p.db, itemID)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, ErrUnknownItem
		}
		return nil, err
	}
	if !item.Active {
		return nil, ErrInactiveItem
	}

	refID := "purchase:" + itemID + ":" + idempotencyKey

	// Replay fast-path: an entry with this refId already exists, so the
	// previous successful transaction already applied the effect. Return
	// the receipt without re-entering the txn.
	if existing, err := findExistingPurchase(ctx, p.db, userID, refID); err != nil {
		return nil, err
	} else if existing != nil {
		return purchaseResult(existing, item), nil
	}

	session, err := p.client.StartSession()
	if err != nil {
		return nil, err
	}
	defer session.EndSession(ctx)

	out, err := session.WithTransaction(ctx, func(sc context.Context) (any, error) {
		// 1. Ledger row + users.$inc — same session as the inventory write
		// below so they commit together.
		entry, err := p.ledger.GrantInSession(sc, userID, -item.PriceCoins, coins.ReasonShopPurchase, refID,
			map[string]string{"itemId": itemID, "kind": item.Kind})
		if err != nil {
			return nil, err
		}

		// 2. Per-kind effect.
		if err := p.applyEffect(sc, item, entry, userID); err != nil {
			return nil, err
		}
		return entry, nil
	})
	if err != nil {
		// Concurrent winner committed during our txn: snapshot isolation
		// kept us blind to the row inside the failing session, so re-read
		// it out of session and return the same receipt.
		if mongo.IsDuplicateKeyError(err) {
			if winner, ferr := findExistingPurchase(ctx, p.db, userID, refID); ferr == nil && winner != nil {
				return purchaseResult(winner, item), nil
			}
		}
		return nil, err
	}
	entry := out.(*coins.LedgerEntry)
	return purchaseResult(entry, item), nil
}

// applyEffect runs the kind-specific in-session inventory mutation. Any
// error returned here aborts the transaction (debit included) — that's
// the entire refund-on-failure story: a failed effect means the debit
// never lands.
func (p *Purchase) applyEffect(sc context.Context, item *Item, entry *coins.LedgerEntry, userID string) error {
	inventory := NewInventory(p.db)

	switch item.Kind {
	case KindAvatarFrame, KindNameColor:
		// ErrAlreadyOwned on a retry is benign: the original txn added
		// the cosmetic, and the replay fast-path already returned. The
		// only way we'd hit this branch with the same refId is if the
		// fast-path missed (concurrent first commit), in which case the
		// duplicate-key path above handles it.
		if err := inventory.AddCosmetic(sc, userID, item.ID); err != nil && !errors.Is(err, ErrAlreadyOwned) {
			return fmt.Errorf("add cosmetic: %w", err)
		}
		return nil

	case KindRerollTopic:
		// IncrementReroll is NOT inherently idempotent. Keyed-by-ledger
		// sentinel: insert a row in coin_reroll_application with _id =
		// ledger entry ID. A retry that re-enters the txn will see the
		// row exist and skip the increment. The surrounding fast-path
		// makes this rare (only a concurrent racer that lost the unique
		// index race can land here twice), but the guard is cheap.
		applied, err := rerollAlreadyApplied(sc, p.db, entry.ID)
		if err != nil {
			return fmt.Errorf("check reroll applied: %w", err)
		}
		if applied {
			return nil
		}
		charges := chargesForRerollItem(item)
		if err := inventory.IncrementReroll(sc, userID, charges); err != nil {
			return fmt.Errorf("incr reroll: %w", err)
		}
		if err := markRerollApplied(sc, p.db, entry.ID, userID, charges); err != nil {
			return fmt.Errorf("mark reroll applied: %w", err)
		}
		return nil

	case KindStreakFreeze:
		// In-tx weekly cap. Returning the error rolls back the debit, so
		// a user already-capped this week never loses coins.
		if err := inventory.ClaimStreakFreezeForWeek(sc, userID); err != nil {
			return err
		}
		return nil

	case KindPremiumTrial:
		// Outbox enqueue runs in the SAME session as the debit. On a
		// retry, the duplicate-key on _id is benign — the row already
		// exists and the consumer will eventually process it once.
		row := OutboxRow{
			ID:      entry.ID + ":premium_trial",
			UserID:  userID,
			Kind:    "premium_trial",
			Payload: map[string]string{"days": item.Metadata["days"], "ledgerEntryId": entry.ID},
		}
		if err := EnqueueOutbox(sc, p.db, row); err != nil {
			if !mongo.IsDuplicateKeyError(err) {
				return fmt.Errorf("enqueue outbox: %w", err)
			}
		}
		return nil

	default:
		return fmt.Errorf("unhandled item kind: %s", item.Kind)
	}
}

// chargesForRerollItem reads the charge count from the item's metadata,
// defaulting to 1 if unset or unparseable. Currently only "1" and "5"
// are honoured as catalog values; anything else falls back to 1.
func chargesForRerollItem(item *Item) int32 {
	if v, ok := item.Metadata["charges"]; ok && v == "5" {
		return 5
	}
	return 1
}

func findExistingPurchase(ctx context.Context, db *mongo.Database, userID, refID string) (*coins.LedgerEntry, error) {
	var existing coins.LedgerEntry
	err := db.Collection("coin_ledger").FindOne(ctx,
		bson.M{"userId": userID, "refId": refID, "reason": coins.ReasonShopPurchase}).
		Decode(&existing)
	if err == nil {
		return &existing, nil
	}
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, nil
	}
	return nil, err
}

func purchaseResult(entry *coins.LedgerEntry, item *Item) *PurchaseResult {
	return &PurchaseResult{
		LedgerEntryID: entry.ID,
		NewBalance:    entry.BalanceAfter,
		Owned:         item.Kind == KindAvatarFrame || item.Kind == KindNameColor,
	}
}

// rerollAlreadyApplied / markRerollApplied implement the per-ledger-entry
// idempotency guard for the reroll branch. The collection's _id uniqueness
// (the default Mongo guarantee) is the only index we need; no entry in
// seed/main.go is required.
func rerollAlreadyApplied(sc context.Context, db *mongo.Database, entryID string) (bool, error) {
	err := db.Collection("coin_reroll_application").FindOne(sc, bson.M{"_id": entryID}).Err()
	if err == nil {
		return true, nil
	}
	if errors.Is(err, mongo.ErrNoDocuments) {
		return false, nil
	}
	return false, err
}

func markRerollApplied(sc context.Context, db *mongo.Database, entryID, userID string, charges int32) error {
	_, err := db.Collection("coin_reroll_application").InsertOne(sc, bson.M{
		"_id": entryID, "userId": userID, "charges": charges, "appliedAt": time.Now().UTC(),
	})
	return err
}
