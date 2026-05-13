package coins

// RabbitMQ topology used by the §4.3 earn pipeline. Every coin-earning source
// (match win, tournament placement, daily streak, referral fulfillment)
// publishes a coins.earn.<source> message to the existing topic exchange "sx".
// The scoring service binds a single coin-earn-queue to coins.earn.* and
// dispatches each message to pkg/coins.Ledger.Grant.
//
// Funneling every earn through one queue gives us:
//   - one place to enforce idempotency (refId on the unique index),
//   - one place to add cross-cutting policy (rate limits, audit, metrics),
//   - producers that don't import the ledger or need a Mongo connection.
const (
	EarnExchange       = "sx"
	EarnRoutingPrefix  = "coins.earn"
	EarnQueueName      = "coin-earn-queue"
	EarnBindingPattern = "coins.earn.*"
)

// Earn-source tokens used as the suffix in coins.earn.<source>. These are
// part of the wire contract — adding a new source means publishing under a
// new routing key AND adding a corresponding Reason* in ledger.go.
const (
	EarnSourceMatchWin         = "match_win"
	EarnSourceTournamentPlace  = "tournament_placement"
	EarnSourceStreak           = "streak"
	EarnSourceReferralReferrer = "referral_referrer"
	EarnSourceReferralReferee  = "referral_referee"
)

// EarnRoutingKey returns the canonical "coins.earn.<source>" routing key
// for a given source token. Centralised so producers don't hand-build the
// string and accidentally drift from the consumer's binding pattern.
func EarnRoutingKey(source string) string {
	return EarnRoutingPrefix + "." + source
}

// EarnSideReasons is the allowlist of Reason* values the coins.earn.*
// consumer accepts. Spend-side reasons (ReasonShopPurchase, ReasonShopRefund,
// ReasonAdminAdjustment) are deliberately excluded — those belong to the
// synchronous Purchase RPC and admin tooling, and must not be reachable from
// the multi-producer earn pipeline.
//
// Why this matters: every service in the cluster has publish credentials to
// the `sx` exchange. Without an allowlist, a single compromised service could
// publish {reason: "admin.adjustment", amount: 1e9, userId: <victim>} and the
// consumer would credit arbitrary balances. The consumer DLQs any payload
// whose Reason is not in this map.
var EarnSideReasons = map[string]struct{}{
	ReasonDailyReward:      {},
	ReasonStreakBonus:      {},
	ReasonMatchWin:         {},
	ReasonReferralReferrer: {},
	ReasonReferralReferee:  {},
	ReasonTournamentPrize:  {},
	ReasonWelcomeBonus:     {},
}

// MaxEarnAmount is the per-event upper bound for coins.earn.* deliveries.
// The largest legitimate single earn is ~200 coins (the two-week-streak
// reward in services/auth/main.go::rewardForDay); the 100k ceiling here
// is a defense-in-depth safety net, not a product-shaped value. Any
// payload above this is treated as a bad payload and routed to the DLQ.
const MaxEarnAmount = 100_000

// EarnEvent is the JSON payload every coins.earn.* message carries. The
// consumer hands (UserID, Amount, Reason, RefID, Metadata) straight to
// Ledger.Grant — RefID is therefore the natural idempotency key, scoped
// per-source so two sources can't collide on the same refId.
//
// Refid conventions (so producers stay consistent):
//   - match.win:           "match:<roomId>:user:<userId>"
//   - tournament.placement: "tournament:<tournamentId>:user:<userId>"
//   - streak.daily_reward:  "streak:<userId>:<YYYY-MM-DD>"
//   - referral.referrer:    "referral:<referralId>:referrer"
//   - referral.referee:     "referral:<referralId>:referee"
type EarnEvent struct {
	// Event mirrors the routing key so log tooling that only sees the
	// payload can still bucket events. Producers SHOULD set this.
	Event    string            `json:"event,omitempty"`
	UserID   string            `json:"userId"`
	Amount   int64             `json:"amount"`
	Reason   string            `json:"reason"`
	RefID    string            `json:"refId"`
	Metadata map[string]string `json:"metadata,omitempty"`
}
