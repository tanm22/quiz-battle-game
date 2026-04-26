# ADR 0003 — Premium Trial Extension via Transactional Outbox

## Status

Accepted — 2026-04-26.

## Context

Section 4.3 includes a 3-day premium trial as a coin-shop SKU. Buying it must:

1. Debit the user's coin balance (and write the matching `coin_ledger` row, per ADR-0001).
2. Extend `users.planExpiresAt` (and flip `users.plan` to `"premium"` if needed).

The first effect is owned by `services/scoring` (the shop lives there). The second effect is owned by `services/payment` — it's the same field the Razorpay webhook handler writes to, with the same `premiumExpiryWarned` reset semantics. We don't want two services racing on `users.planExpiresAt`.

Three options for how scoring tells payment to do its half:

- **A. Synchronous gRPC call from scoring → payment.** Couples request latency: a slow Razorpay-side payment-service blocks every cosmetic purchase. Worse, a partial failure (debit committed, gRPC call timed out) leaves the user with coins gone but no premium.
- **B. RabbitMQ event** — publish `coins.premium.trial` from scoring, consume in payment. Better than (A) — broker decouples latency — but the publish is outside scoring's coin-debit transaction. A crash between debit-commit and publish loses the effect intent.
- **C. Transactional outbox.** Inside scoring's `Purchase.Buy` transaction, insert a row into `coin_effect_outbox` (keyed by `<ledgerEntryId>:<effectKind>`). The row commits with the ledger and `users.coins` `$inc`. A worker in `services/payment` polls the outbox, applies the effect, and marks the row processed.

## Decision

Adopt **option C: transactional outbox**, with the consumer in `services/payment`.

The outbox primitives (`OutboxRow`, `EnqueueOutbox`, `DequeueDue`, `MarkProcessed`, the `coin_effect_outbox` collection + `(processedAt asc, kind asc)` index) ship in PR 4 because they're how `Purchase.Buy` durably records the intent inside its session. PR 5 adds the consumer side: `services/payment.startPremiumTrialConsumer` polls every second, pulls up to 32 unprocessed rows of kind `"premium_trial"`, extends `planExpiresAt`, sets `plan="premium"`, and marks the row processed.

### Schema (recap)

`coin_effect_outbox`:

| Field | Type | Notes |
|---|---|---|
| `_id` | string | `<ledgerEntryId>:<effectKind>` — natural key, prevents duplicate enqueue |
| `userId` | string | ID of the user receiving the effect |
| `kind` | string | Effect type — currently only `"premium_trial"` |
| `payload` | map<string,string> | Effect-specific data — `days` for trials |
| `attempts` | int | Reserved for future retry-bounded dead-letter; unused in v1 |
| `processedAt` | time.Time? | Nil while pending, set by `MarkProcessed` once consumed |
| `createdAt` | time.Time | Set inside `EnqueueOutbox` |

Index: `(processedAt asc, kind asc)` — covers the consumer's "find unprocessed by kind, oldest first" sweep.

### Consumer behavior

- **Renewal-aware extension**: if the user's `planExpiresAt` is already in the future (e.g. from a prior Razorpay payment or another trial), extend from THAT timestamp, not from `now`. Otherwise back-to-back trials would shorten the user's existing premium time, which is precisely the failure mode "transactional outbox" is supposed to prevent.
- **`premiumExpiryWarned` reset**: cleared in the same `$unset` as the plan extension, mirroring the existing `payment.captured` plan-upgrade behavior so the warning worker re-fires against the new expiry.
- **User-deleted gap**: if the user disappeared between debit and consumption (rare — would require `DeleteAccount` between the shop transaction commit and the next poll), log and mark the row processed so the worker stops retrying. The coin debit is permanent regardless; reconciliation is manual.
- **Per-row failure**: log and leave the row unprocessed. The next poll retries. There is no per-row retry counter or DLQ in v1 — operator alerts on outbox queue depth are the floor.

## Consequences

**Pros:**

- Coin debit and effect intent are atomic — the outbox row commits in the same Mongo transaction as the ledger write. Scoring never tells the user "purchased successfully" when the effect intent might be lost.
- Cross-service concern stays loose-coupled: payment owns `planExpiresAt` and is the only writer; scoring just signals intent.
- Consumer is independently testable (drop a row directly into `coin_effect_outbox` and watch the worker process it) without standing up the full purchase flow.

**Cons:**

- Eventual consistency window — typically <2s with the 1s poll interval. The Flutter UI must reflect "extending..." and either show an optimistic state or refresh after a short delay. Acceptable for a trial that lasts days.
- **Mid-row crash over-grant**: if the worker crashes after extending `planExpiresAt` but before `MarkProcessed`, the next poll re-extends. Because the renewal-aware logic extends from the existing (already-pushed-out) expiry, the user gets an extra `days * 24h` grant per crash. Mitigations: rare in practice; the worker is short-lived per row; an operator can detect via `coin_effect_outbox` rows older than ~5s. A future `claimedAt` watermark would close this gap fully but adds complexity unwarranted at v1 scale.
- Single-instance worker assumption: two `services/payment` replicas would each poll the same rows. The current Mongo-only locking story (`processedAt: nil` filter) doesn't prevent both replicas from picking the same row. The repo runs single-instance services per `docker-compose.yml`; multi-replica payment is out of v1 scope but documented here for future planning.

## Alternatives considered

- **Synchronous gRPC** — rejected (latency coupling + partial-failure visibility).
- **Pure RabbitMQ event** without outbox — rejected (publish-after-commit can lose intent on a crash).
- **Outbox consumer in `scoring`** — would keep all coin-economy code in one service, but means scoring writes `users.planExpiresAt`, breaking the "payment owns plan state" invariant. Rejected.
- **Per-row claim-with-lease** (`claimedAt + claimedBy` fields) — preferred for multi-replica deployments. Out of scope for v1.

## References

- `pkg/coins/shop/outbox.go` — `OutboxRow`, `EnqueueOutbox`, `DequeueDue`, `MarkProcessed`.
- `pkg/coins/shop/purchase.go` — the `KindPremiumTrial` arm of `applyEffect` enqueues the row.
- `services/payment/premium_trial_consumer.go` — the consumer added in PR 5.
- `seed/main.go` — declares the `(processedAt asc, kind asc)` index.
- ADR-0001 — the broader "transaction-or-no-write" invariant the outbox preserves across services.
