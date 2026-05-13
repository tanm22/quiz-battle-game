# ADR-0005 — Coin ledger uses Mongo transactions on a single-node replica set

## Status
Accepted — 2026-04-26.

## Context

The §4.3 spec mandates a server-authoritative coin economy:

> Server-authoritative balance (never trust the client). Full transaction ledger in MongoDB: `coin_ledger (userId, delta, reason, refId, balanceAfter, createdAt)`. Never mutate balance without a ledger entry.

Without atomicity between the ledger insert and the `users.coins` `$inc`, a crash between the two writes leaves the system inconsistent:

- Ledger row written, balance not updated → user is "owed" coins; balance reads lie.
- Balance updated, ledger row not written → audit trail has a gap; cannot reconcile.

The earlier (Phase 2) code wrote balances with bare `$inc` and no ledger. We need to break that pattern without breaking existing call sites.

The system also has multiple coin producers running concurrently: the earn consumer (match wins, referrals, tournaments), the daily-reward path in auth, the shop purchase path in scoring. They all need the same write to be safe under contention.

## Decision

1. **Run Mongo as `--replSet rs0`.** Single node in dev (`docker-compose.yml`); 3-node in production. This is the prerequisite for multi-document transactions — on a standalone Mongo, sessions still work but `WithTransaction` is effectively a no-op and we lose the invariant. See [adr-0011](./0011-mongo-replica-set.md) for the rs0 boot story.
2. **All balance changes go through `pkg/coins.Ledger.Grant`.** Grant opens a Mongo session and uses `WithTransaction` to insert the ledger row and `$inc users.coins` together. There is no other public API that mutates `users.coins`. Bare `$inc` calls in the codebase are a code-review red flag.
3. **Idempotency lives in the persistence layer.** A unique compound index on `(userId, refId, reason)` makes a duplicate insert fail with a duplicate-key error. `Grant` catches that, fetches the existing row, and returns it without mutating anything. Producers therefore retry events freely.
4. **`balanceAfter` is computed inside the transaction** from `users.coins` read in the same session, so it's always consistent with the increment that follows.

## Consequences

### Positive
- Single source of truth. `users.coins` is the fast read cache; `coin_ledger` is the audit trail. The transaction keeps them in lockstep.
- Producers (streak, match, referral, tournament, shop) become simple. They emit events with a natural `refId` and never worry about double-credit.
- The ledger is queryable for support ("why does user X have 250 coins?") and for the user-facing history screen (`GetCoinLedger` RPC).
- The compound unique index does double duty: it's the consumer's idempotency key *and* the index that backs cursor-paginated history reads (after combination with `(userId, createdAt DESC)`).

### Negative
- Single-node replica set adds a small ops wrinkle in dev (a healthcheck script that idempotently runs `rs.initiate(...)`). Standard for production-grade Mongo regardless.
- Transactions add ~5-15 ms of latency in our environment versus a bare `$inc`. Acceptable for grants which are not on the answer-submission hot path.
- Dev databases that pre-date this PR need to be wiped or have `rs0` initiated manually. Documented in the PR description.

### Alternatives considered

**A. Two-phase ledger-then-balance with a `status` field.** Insert the ledger row with `status: "pending"`, run `$inc`, flip to `status: "confirmed"`. Readers filter on confirmed; a sweeper repairs orphans. Implementable without transactions but requires reader-side filtering and a janitor process. More moving parts, weaker invariants. Worse for newcomers reading the code.

**B. Event-sourced balance derived from ledger sum.** No `users.coins` cache; balance is always `db.coin_ledger.aggregate([{$match:{userId}}, {$group:{_id:null, sum:{$sum:"$delta"}}}])`. Defeats fast balance reads at scale and adds aggregation pipeline complexity for a feature this scoped. Reasonable in a system that already heavily uses event sourcing; ours doesn't.

**C. Application-level mutex per user.** Serialise grants per userId in-process. Doesn't survive multiple service instances and doesn't compose across services that all need to mutate `users.coins`.

(A) was the runner-up. We picked the transaction path because the operational cost of running rs0 is low, the code is simpler, and the invariant is enforced by the database rather than by every reader.

## Migration

`pkg/coins.Ledger.Grant` is additive. Existing call sites that bare-`$inc`'d `users.coins` (auth's `ClaimDailyReward`, scoring's referral consumer, the tournament-payouts pipeline) were migrated PR-by-PR. The compound unique index on `coin_ledger` is the safety net — a regression that re-introduces double-grant would manifest as a duplicate-key error in logs, not a silent over-credit.

## References
- `pkg/coins/ledger.go::Grant`, `GetBalance`, `GetLedger`.
- `seed/main.go` — `uniq_user_ref_reason` and `idx_user_recent` indexes.
- `runbook.md` "Granting coins manually" — the canonical admin-grant flow.
- MongoDB transactions docs: https://www.mongodb.com/docs/manual/core/transactions/
