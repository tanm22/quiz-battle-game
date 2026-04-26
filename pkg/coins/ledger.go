package coins

import (
	"context"
	"time"

	"go.mongodb.org/mongo-driver/v2/mongo"
)

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
	panic("not implemented yet — Task 1.5")
}

// GetBalance returns the cached balance from users.coins. The cache is kept
// consistent with the ledger by Grant's transaction, so this is the only
// read path callers need.
func (l *Ledger) GetBalance(ctx context.Context, userID string) (int64, error) {
	panic("not implemented yet — Task 1.5")
}

// GetLedger returns ledger entries for the user newest-first, paged by an
// opaque cursor that encodes the createdAt of the last row of the previous
// page. pageSize is clamped to [1, 100] with a default of 25.
func (l *Ledger) GetLedger(ctx context.Context, userID string, pageSize int32, pageToken string) ([]*LedgerEntry, string, error) {
	panic("not implemented yet — Task 1.5/1.7")
}
