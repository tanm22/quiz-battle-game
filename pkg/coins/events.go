package coins

// AMQP routing surface for asynchronous coin grants. Producers (quiz match-
// finished, future tournament finalizer, future streak bonus emitter)
// publish to "coins.earn.<source>" on the existing "sx" topic exchange;
// the scoring service binds a single coin-earn-queue with the
// "coins.earn.*" wildcard and dispatches every message through
// scoringServer.handleEarnEvent → ledger.Grant.
//
// One queue + one consumer for every async earn source keeps the wire
// payload, idempotency model, and operational story uniform: any new
// earning source becomes a producer-side change only.
const (
	EarnExchange       = "sx"
	EarnRoutingPrefix  = "coins.earn"
	EarnQueueName      = "coin-earn-queue"
	EarnBindingPattern = "coins.earn.*"

	// Source string used as the routing-key suffix and (optionally) embedded
	// in metadata so the consumer can log a clean source label without
	// re-parsing the routing key.
	EarnSourceMatchWin   = "match_win"
	EarnSourceTournament = "tournament_placement"
	EarnSourceStreak     = "streak"
	EarnSourceReferral   = "referral"
)

// EarnEvent is the JSON payload published on the sx exchange under any
// "coins.earn.<source>" routing key. The fields map 1:1 to ledger.Grant
// arguments — Reason must match a constant in the validReasons set in
// ledger.go, RefID is the (userId, refId, reason) idempotency natural
// key for that source, Amount must be positive (earn events never debit;
// shop purchases use the synchronous Purchase orchestrator instead).
//
// Producers: keep RefID stable across retries — that's what guarantees
// at-least-once delivery without double-credit. Match-win producer uses
// "match:<roomId>:user:<userId>"; tournament uses
// "tournament:<tournamentId>:user:<userId>".
type EarnEvent struct {
	Event    string            `json:"event"` // e.g. "coins.earn.match_win"
	UserID   string            `json:"userId"`
	Amount   int64             `json:"amount"`
	Reason   string            `json:"reason"` // one of pkg/coins reasons
	RefID    string            `json:"refId"`  // idempotency key
	Metadata map[string]string `json:"metadata,omitempty"`
}
