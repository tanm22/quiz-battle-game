# ADR 0001: Coin Ledger uses Mongo Transactions on a Single-Node Replica Set

## Status

Accepted — 2026-04-26.

## Context

Section 4.3 of `problem-03.md` mandates: server-authoritative balances, an immutable ledger (`coin_ledger` with `userId`, `delta`, `reason`, `refId`, `balanceAfter`, `createdAt`), and *"never mutate balance without a ledger entry"*. Without atomicity, a crash between the balance update and the ledger insert produces inconsistency in either direction — phantom coins (write-balance, lose-ledger) or phantom debits (write-ledger, lose-balance). Both are unacceptable for a coin economy.

## Decision

- Run Mongo as `--replSet rs0` (single node in dev, 3-node in prod) so transactions are available. Single-node rs0 is the standard pattern for local development with transactions; the operational overhead is one healthcheck `rs.initiate()` call.
- All balance mutations go through `pkg/coins.Ledger.Grant` (or `GrantInSession` when an outer orchestrator already holds a session). `Grant` opens a session, calls `WithTransaction`, and inside the callback inserts the `coin_ledger` row and `$inc`s `users.coins` together. Either both writes commit or neither does.
- Idempotency is enforced at the persistence layer by a unique compound index on `(userId, refId, reason)`. Repeat calls for the same triple return the existing entry without mutating state. Producers use natural keys (`match:<roomId>`, `streak:<userId>:<date>`, `referral:<id>:<role>`, `tournament:<id>:user:<uid>`) so the same real-world event always hashes to the same row.
- `balanceAfter` is computed inside the transaction from `users.coins` read in the same session, so it is consistent with the increment.
- Concurrent first-time grants race on `InsertOne`. The loser's session aborts with `E11000`; the recovery path in `Grant` (out-of-session) re-reads the winner with default read concern, so callers see a clean entry rather than an error.

## Consequences

**Pros:**

- Single source of truth for balances. Reads of `users.coins` are always consistent with the ledger.
- Idempotency at the persistence layer keeps producer code simple — they can publish at-least-once and retry on failure without worrying about double-credit.
- The ledger is append-only and immutable, which gives a free audit trail for every coin movement.

**Cons:**

- Single-node replica set adds tiny ops overhead in dev (~one extra healthcheck step). Standard for production-grade Mongo anyway.
- Transactions add latency (~5–15 ms in our environment for a two-write txn). Acceptable: grants are NOT on the hot quiz-answer path, only on streak/match-end/referral/shop-purchase paths which already do remote work (FCM, etc.).
- Session-bound reads use snapshot isolation, which means inside an aborted txn we cannot see a concurrent committer's just-written row. The dup-key recovery path must re-read OUTSIDE any session — easy to get wrong, so the comment in `grantInSession` explicitly forbids in-session dup-key recovery.

## Alternatives considered

- **Two-phase ledger-then-balance with a pending status field**: implementable without transactions but requires reader-side filtering of pending rows and a sweeper for orphans (cases where the second write never lands). More moving parts, weaker invariants, and a window of inconsistency that's hard to bound.
- **Event-sourced balance derived from ledger sum**: defeats fast balance reads at scale (every `GetBalance` becomes an aggregate over the user's full history) and adds materialization complexity for a feature this scoped.
- **Application-level "ledger first, then balance" with a recovery worker**: same trade-offs as the two-phase pattern; saves the rs0 setup but adds a stateful worker that has to handle a crash schedule.

## Operational notes

- Existing direct-`$inc` call sites (`auth.ClaimDailyReward`, `scoring` referral consumer) are migrated to `coins.Grant` in the same PR that introduces this ADR.
- The first time the seed service runs against a fresh `rs0` Mongo, it creates both the unique index and the `(userId, createdAt desc)` pagination index. CI bootstraps an `rs0` sidecar; local dev relies on `docker-compose.yml` running `mongo:7 --replSet rs0`.
- The transaction-execution latency budget is tight enough that we accept it for grants but explicitly DO NOT use a transaction on the answer-submission path. That path remains Redis-only with eventual reconciliation through `match.finished`.
