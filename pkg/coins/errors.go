package coins

import "errors"

// Sentinel errors returned by the ledger primitives. Callers compare with
// errors.Is so wrapping is safe.
var (
	ErrAmountInvalid       = errors.New("coins: amount must be non-zero")
	ErrInsufficientBalance = errors.New("coins: insufficient balance")
	ErrUnknownReason       = errors.New("coins: unknown reason")
	ErrMissingRefID        = errors.New("coins: refId required for idempotency")
)
