# ADR-0007 — Premium-trial extension via transactional outbox

## Status
Accepted — 2026-04-26.

## Context

The coin shop sells a 3-day premium trial. Buying it must:

1. Debit the user's coin balance and write the matching `coin_ledger` row (atomic, per [adr-0005](./0005-coin-ledger-transactional.md)).
2. Extend `users.planExpiresAt` (and flip `users.plan` to `"premium"` if needed).

The first effect is owned by `services/scoring` (the shop lives there). The second is owned by `services/payment` — it's the same field the Razorpay webhook handler writes to, with the same `premiumExpiryWarned` reset semantics. We can't have two services racing on `users.planExpiresAt`.

Three options for how scoring tells payment to do its half:

- **A. Synchronous gRPC call from scoring → payment.** Couples request latency: a slow payment service blocks every cosmetic purchase. Worse, a partial failure (debit committed, gRPC call timed out) leaves the user with coins gone but no premium.
- **B. RabbitMQ event** — publish `coins.premium.trial` from scoring, consume in payment. Better than (A) — broker decouples latency — but the publish is outside scoring's coin-debit transaction. A crash between debit-commit and publish loses the effect intent.
- **C. Transactional outbox.** Inside scoring's `Purchase.Buy` transaction, insert a row into `coin_effect_outbox` (keyed by `<ledgerEntryId>:<effectKind>`). The row commits with the ledger and `users.coins` `$inc`. A worker in `services/payment` polls the outbox, applies the effect, and marks the row processed.

## Decision

Adopt **option C: transactional outbox**, with the consumer in `services/payment`.

The outbox primitives (`OutboxRow`, `EnqueueOutbox`, `DequeueDue`, `MarkProcessed`, the `coin_effect_outbox` collection + `(processedAt, kind)` index) live in `pkg/coins/shop/outbox.go`. `services/payment.startPremiumTrialConsumer` polls every second, pulls up to 32 unprocessed rows of kind `"premium_trial"`, extends `planExpiresAt`, sets `plan="premium"`, and marks the row processed.

### Schema

`coin_effect_outbox` collection:

| Field | Type | Notes |
|---|---|---|
| `_id` | string | `<ledgerEntryId>:<effectKind>` — natural key, prevents duplicate enqueue |
| `userId` | string | Recipient |
| `kind` | string | `"premium_trial"` today |
| `payload` | map<string,string> | Effect-specific data — `days` for trials |
| `attempts` | int | Reserved for future retry-bounded DLQ; unused in v1 |
| `processedAt` | time.Time? | Nil while pending |
| `createdAt` | time.Time | Set by `EnqueueOutbox` |

Index: `(processedAt asc, kind asc)` — covers the consumer's "find unprocessed by kind, oldest first" sweep.

### Consumer behavior

- **Renewal-aware extension.** If the user's `planExpiresAt` is already in the future (from a prior Razorpay payment or another trial), extend from THAT timestamp, not from `now`. Otherwise back-to-back trials would shorten the user's existing premium time, which is precisely the failure mode the outbox is meant to prevent.
- **`premiumExpiryWarned` reset.** Cleared in the same `$unset` as the plan extension, mirroring the Razorpay capture path so the warning worker re-fires against the new expiry.
- **User-deleted gap.** If the user disappeared between debit and consumption (rare — would require `DeleteAccount` between the shop transaction commit and the next poll), log and mark the row processed so the worker stops retrying. The coin debit is permanent regardless; reconciliation is manual.
- **Per-row failure.** Log and leave the row unprocessed. The next poll retries. There is no per-row retry counter or DLQ in v1; operator alerts on outbox queue depth are the floor.

### Observability

The payment service runs a 30-second-tick watcher over `coin_effect_outbox` that publishes Prometheus gauges per kind:

- `outbox_pending_total{kind}` — rows with `processedAt: null`. Healthy: 0.
- `outbox_oldest_age_seconds{kind}` — age of the oldest unprocessed row, 0 when the queue is empty.

When `outbox_oldest_age_seconds` exceeds **300 s** for a given kind, the watcher emits a structured `outbox stuck` error log. In production, attach a Prometheus alert: `outbox_oldest_age_seconds > 600 for 5m` → page.

## Consequences

### Positive
- Coin debit and effect intent are atomic — the outbox row commits in the same Mongo transaction as the ledger write. Scoring never tells the user "purchased successfully" when the effect intent might be lost.
- Cross-service concern stays loose-coupled: payment owns `planExpiresAt` and is the only writer; scoring just signals intent.
- Consumer is independently testable: drop a row into `coin_effect_outbox` and watch the worker process it without standing up the full purchase flow.

### Negative
- Eventual consistency window — typically <2 s with the 1 s poll. The Flutter UI shows an "extending..." state and refreshes after a short delay.
- **Mid-row crash over-grant.** If the worker crashes after extending `planExpiresAt` but before `MarkProcessed`, the next poll re-extends. Because the logic extends from the existing (pushed-out) expiry, the user gets an extra `days × 24 h` per crash. Mitigations: rare in practice; the worker is short-lived per row; an operator can detect via `coin_effect_outbox` rows older than ~5 s. A future `claimedAt` lease would close this gap fully but adds complexity not warranted at v1 scale.
- **Single-instance worker assumption.** Two `services/payment` replicas would each poll the same rows. The current Mongo-only locking story (`processedAt: nil` filter) doesn't prevent both replicas from picking the same row. The repo runs single-instance services per `docker-compose.yml`; multi-replica payment is out of v1 scope but documented here for future planning.

## Alternatives considered

- **Synchronous gRPC** — rejected (latency coupling + partial-failure visibility).
- **Pure RabbitMQ event** without outbox — rejected (publish-after-commit can lose intent on a crash).
- **Outbox consumer in scoring** — would keep all coin-economy code in one service, but means scoring writes `users.planExpiresAt`, breaking the "payment owns plan state" invariant. Rejected.
- **Per-row claim-with-lease (`claimedAt + claimedBy`)** — preferred for multi-replica deployments. Out of scope for v1.

## References
- `pkg/coins/shop/outbox.go` — `OutboxRow`, `EnqueueOutbox`, `DequeueDue`, `MarkProcessed`.
- `pkg/coins/shop/purchase.go` — the `KindPremiumTrial` arm of `applyEffect` enqueues the row.
- `services/payment/premium_trial_consumer.go` — the consumer.
- `services/payment/outbox_watcher.go` — Prometheus lag gauges + stuck-row logging.
- `seed/main.go` — declares the `(processedAt asc, kind asc)` index.
- [adr-0005](./0005-coin-ledger-transactional.md) — the broader "transaction-or-no-write" invariant the outbox preserves across services.
