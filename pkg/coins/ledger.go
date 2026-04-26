package coins

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// DefaultDBName is the canonical Mongo database for quiz-battle. Services
// pass this to NewLedger so renaming the database touches one place.
const DefaultDBName = "quizbattle"

// LedgerEntry is one immutable row in the coin_ledger collection.
//
// Indexes (declared in seed/main.go):
//   - unique compound (userId, refId, reason) — idempotency
//   - compound (userId, createdAt desc) — newest-first paged reads
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

// Reason constants — every Grant must use one of these. Adding a new earn
// or spend source means adding a constant here AND in validReasons below.
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

// Ledger is the entry point for all balance reads and writes. Construct one
// per service at startup with NewLedger and keep it alive for the process.
type Ledger struct {
	client *mongo.Client
	dbName string
}

// NewLedger binds a Ledger to a Mongo client and a database name. The
// database must contain the users and coin_ledger collections (the seed
// service creates the indexes on coin_ledger).
func NewLedger(client *mongo.Client, dbName string) *Ledger {
	return &Ledger{client: client, dbName: dbName}
}

func (l *Ledger) users() *mongo.Collection {
	return l.client.Database(l.dbName).Collection("users")
}

func (l *Ledger) ledger() *mongo.Collection {
	return l.client.Database(l.dbName).Collection("coin_ledger")
}

// Grant applies delta (positive for earn, negative for spend) to the user's
// balance and writes a corresponding ledger row. The two writes happen in a
// single Mongo transaction so balance and ledger never disagree.
//
// (userID, refID, reason) is the idempotency key — calling Grant twice with
// the same triple returns the existing entry without mutating state.
//
// Returns ErrInsufficientBalance if a negative delta would drive coins below
// zero; the transaction aborts and balance is preserved.
func (l *Ledger) Grant(ctx context.Context, userID string, delta int64, reason, refID string, metadata map[string]string) (*LedgerEntry, error) {
	if err := validateGrantInputs(delta, reason, refID); err != nil {
		return nil, err
	}

	// Fast path: idempotent replay. Skips the transaction overhead when we
	// already have a row for this (userId, refId, reason). The unique index
	// in seed/main.go is the authoritative guard against duplicates;
	// concurrent racers fall through to the transaction below and exactly
	// one writes the row, the rest see DuplicateKey and are funneled here.
	if existing, err := l.findExisting(ctx, userID, refID, reason); err != nil {
		return nil, err
	} else if existing != nil {
		return existing, nil
	}

	session, err := l.client.StartSession()
	if err != nil {
		return nil, fmt.Errorf("start session: %w", err)
	}
	defer session.EndSession(ctx)

	result, err := session.WithTransaction(ctx, func(sc context.Context) (any, error) {
		return l.GrantInSession(sc, userID, delta, reason, refID, metadata)
	})
	if err != nil {
		// Concurrent identical grant: the unique index rejected our insert.
		// The winning grant's row is now visible — fetch and return it.
		if mongo.IsDuplicateKeyError(err) {
			if existing, ferr := l.findExisting(ctx, userID, refID, reason); ferr == nil && existing != nil {
				return existing, nil
			}
		}
		return nil, err
	}
	return result.(*LedgerEntry), nil
}

// GrantInSession is the session-scoped variant of Grant: it performs the
// balance check, ledger insert, and users.$inc against the supplied session
// context (sc) without opening a new session. Use this when the caller is
// already running inside its own WithTransaction and wants the ledger writes
// to commit atomically with other side-effects (e.g. shop inventory mutations
// in pkg/coins/shop.Purchase.Buy).
//
// The caller is responsible for the surrounding session lifecycle, including
// translating duplicate-key errors into idempotency hits — GrantInSession
// itself does not consult the (userId, refId, reason) fast path so concurrent
// racers will surface mongo.IsDuplicateKeyError out of the InsertOne, which
// the outer Grant/Buy translates into "fetch the winner and return it".
//
// Returns ErrInsufficientBalance for negative deltas that would underflow
// coins; aborting via the returned error rolls back the transaction.
func (l *Ledger) GrantInSession(sc context.Context, userID string, delta int64, reason, refID string, metadata map[string]string) (*LedgerEntry, error) {
	if err := validateGrantInputs(delta, reason, refID); err != nil {
		return nil, err
	}
	var user struct {
		Coins int64 `bson:"coins"`
	}
	if err := l.users().FindOne(sc, bson.M{"_id": userID}).Decode(&user); err != nil {
		return nil, fmt.Errorf("load user: %w", err)
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
		return nil, fmt.Errorf("insert ledger: %w", err)
	}
	if _, err := l.users().UpdateOne(sc, bson.M{"_id": userID},
		bson.M{"$inc": bson.M{"coins": delta}}); err != nil {
		return nil, fmt.Errorf("inc balance: %w", err)
	}
	return entry, nil
}

func validateGrantInputs(delta int64, reason, refID string) error {
	if delta == 0 {
		return ErrAmountInvalid
	}
	if _, ok := validReasons[reason]; !ok {
		return ErrUnknownReason
	}
	if refID == "" {
		return ErrMissingRefID
	}
	return nil
}

func (l *Ledger) findExisting(ctx context.Context, userID, refID, reason string) (*LedgerEntry, error) {
	var existing LedgerEntry
	err := l.ledger().FindOne(ctx, bson.M{"userId": userID, "refId": refID, "reason": reason}).Decode(&existing)
	if err == nil {
		return &existing, nil
	}
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, nil
	}
	return nil, fmt.Errorf("lookup existing: %w", err)
}

// GetBalance returns the cached balance from users.coins. The cache is kept
// consistent with the ledger by Grant's transaction, so this is the only
// read path callers need.
func (l *Ledger) GetBalance(ctx context.Context, userID string) (int64, error) {
	var user struct {
		Coins int64 `bson:"coins"`
	}
	if err := l.users().FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
		return 0, err
	}
	return user.Coins, nil
}

// GetLedger returns ledger entries for the user newest-first, paged by an
// opaque cursor encoding (createdAt, _id) of the last row of the previous
// page. pageSize defaults to 25 if <= 0 and is clamped to 100.
//
// _id is included in the sort and the cursor as a tiebreaker — without it,
// two entries sharing the same createdAt nanosecond would be skipped or
// duplicated across pages.
func (l *Ledger) GetLedger(ctx context.Context, userID string, pageSize int32, pageToken string) ([]*LedgerEntry, string, error) {
	if pageSize <= 0 {
		pageSize = 25
	}
	if pageSize > 100 {
		pageSize = 100
	}
	filter := bson.M{"userId": userID}
	if pageToken != "" {
		t, id, err := decodeCursor(pageToken)
		if err != nil {
			return nil, "", fmt.Errorf("invalid pageToken: %w", err)
		}
		filter["$or"] = []bson.M{
			{"createdAt": bson.M{"$lt": t}},
			{"createdAt": t, "_id": bson.M{"$lt": id}},
		}
	}
	cur, err := l.ledger().Find(ctx, filter,
		options.Find().
			SetSort(bson.D{{Key: "createdAt", Value: -1}, {Key: "_id", Value: -1}}).
			SetLimit(int64(pageSize)+1),
	)
	if err != nil {
		return nil, "", err
	}
	defer cur.Close(ctx)

	rows := []*LedgerEntry{}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, "", err
	}
	var next string
	if int32(len(rows)) > pageSize {
		last := rows[pageSize-1]
		next = encodeCursor(last.CreatedAt, last.ID)
		rows = rows[:pageSize]
	}
	return rows, next, nil
}

type pageCursor struct {
	T  time.Time `json:"t"`
	ID string    `json:"i"`
}

func encodeCursor(t time.Time, id string) string {
	raw, _ := json.Marshal(pageCursor{T: t, ID: id})
	return base64.RawURLEncoding.EncodeToString(raw)
}

func decodeCursor(s string) (time.Time, string, error) {
	raw, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return time.Time{}, "", err
	}
	var c pageCursor
	if err := json.Unmarshal(raw, &c); err != nil {
		return time.Time{}, "", err
	}
	return c.T, c.ID, nil
}
