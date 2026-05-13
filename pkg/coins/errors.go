// Package coins is the shared, server-authoritative coin economy primitive
// used by every service that grants or reads coin balances. All balance
// changes flow through Ledger.Grant, which writes a coin_ledger row and
// updates users.coins inside a single Mongo transaction (see ADR-0001).
package coins

import "errors"

var (
	// ErrAmountInvalid is returned when delta == 0. Grant rejects no-op grants
	// to keep ledger semantics tight: every row represents real motion.
	ErrAmountInvalid = errors.New("coins: amount must be non-zero")

	// ErrInsufficientBalance is returned when applying a negative delta would
	// drive users.coins below zero. The transaction is aborted and balance
	// is unchanged.
	ErrInsufficientBalance = errors.New("coins: insufficient balance")

	// ErrUnknownReason is returned when the caller passes a reason string
	// that is not a registered Reason* constant. Forces ledger reasons to
	// be exhaustively enumerated rather than free-text.
	ErrUnknownReason = errors.New("coins: unknown reason")

	// ErrMissingRefID is returned when refID == "". Every grant needs a
	// natural idempotency key; without one, retries would double-credit.
	ErrMissingRefID = errors.New("coins: refId required for idempotency")

	// ErrIdempotencyConflict is returned when a Grant retry's (userId,
	// refId, reason) matches an existing row but the caller's delta
	// disagrees with the row's stored delta. Surfaces silent misuse of
	// the idempotency key (e.g. a backfill script reusing an old refId
	// with a different amount) instead of returning the original row
	// and pretending the retry succeeded.
	ErrIdempotencyConflict = errors.New("coins: idempotency conflict: existing entry has a different delta")
)
