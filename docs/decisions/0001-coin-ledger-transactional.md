# ADR 0001 — Coin Ledger uses Mongo Transactions on a Single-Node Replica Set

## Status
Accepted — 2026-04-26.

## Context
Section 4.3 of `problem-03.md` mandates a server-authoritative coin economy:

> Server-authoritative balance (never trust the client). Full transaction ledger in
> MongoDB: `coin_ledger` (userId, delta, reason, refId, balanceAfter, createdAt).
> Never mutate balance without a ledger entry.

Without atomicity between the ledger insert and the `users.coins` increment, a crash
between the two writes leaves the system inconsistent in either direction:

- Ledger row written, balance not updated → user is "owed" coins; balance reads lie.
- Balance updated, ledger row not written → audit trail has a gap; cannot reconcile.

Phase 2 wrote balances with bare `$inc` and no ledger. We have to break that pattern
without breaking existing call sites.

## Decision
1. **Run Mongo as `--replSet rs0`.** Single node in dev (`docker-compose.yml`); 3-node in
   production. This is the prerequisite for Mongo's multi-document transactions; on a
   standalone Mongo, sessions still work but `WithTransaction` is a no-op and we lose
   the invariant.
2. **All balance changes go through `pkg/coins.Ledger.Grant`.** Grant opens a Mongo
   session and uses `WithTransaction` to insert the ledger row and `$inc` `users.coins`
   together. There is no other public API that mutates `users.coins`.
3. **Idempotency lives in the persistence layer.** A unique compound index on
   `(userId, refId, reason)` makes a duplicate insert fail with a duplicate-key error;
   Grant catches that, fetches the existing row, and returns it without mutating
   anything. Producers therefore retry events freely.
4. **`balanceAfter` is computed inside the transaction** from `users.coins` read in the
   same session, so it is always consistent with the increment that follows.

## Consequences

### Positive
- Single source of truth. `users.coins` is a fast cache; `coin_ledger` is the audit
  trail. The transaction keeps them in lockstep.
- Producers (streak/match/referral/tournament/shop) become simple. They emit events
  with a natural refId and never worry about double-credit.
- The ledger is queryable for support ("why does user X have 250 coins?") and for the
  user-facing history screen (PR 7).

### Negative
- Single-node replica set adds a tiny ops wrinkle in dev (a healthcheck hook that
  initiates `rs0`). Standard for production-grade Mongo regardless.
- Transactions add latency (~5-15ms in our environment) versus a bare `$inc`. Acceptable
  for grants which are not on the answer-submission hot path.
- `dev` databases that pre-date this PR need to be wiped or have `rs0` initiated
  manually. Documented in the PR description.

## Alternatives considered

**A. Two-phase ledger-then-balance with a `status` field.** Insert the ledger row with
`status: "pending"`, run `$inc`, flip to `status: "confirmed"`. Readers filter on
confirmed; a sweeper repairs orphans. Implementable without transactions but requires
reader-side filtering and a janitor process. More moving parts, weaker invariants. Worse
for newcomers reading the code.

**B. Event-sourced balance derived from ledger sum.** No `users.coins` cache; balance is
always `db.coin_ledger.aggregate([{$match:{userId}}, {$group:{_id:null, sum:{$sum:"$delta"}}}])`.
Defeats fast balance reads at scale and adds aggregation pipeline complexity for a
feature this scoped. Reasonable in a system that already heavily uses event sourcing;
ours doesn't.

**C. Application-level mutex per user.** Serialise grants per userId in-process. Doesn't
survive multiple service instances and doesn't compose across services that all need to
mutate `users.coins`.

(A) was the runner-up. We picked the transaction path because the operational cost of
running rs0 is low, the code is simpler, and the invariant is enforced by the database
rather than by every reader.

## Migration

`pkg/coins.Ledger.Grant` is additive. Existing call sites that bare-`$inc` user.coins
(`auth.ClaimDailyReward`, scoring's referral consumer, the tournament_payouts pipeline)
are migrated PR-by-PR — PR 1 covers the first two; the tournament migration ships in a
follow-up.

## References
- `problem-03.md` §4.3 — Coins & Shop requirements.
- `pkg/coins/ledger.go` — `Grant`, `GetBalance`, `GetLedger`.
- `seed/main.go` — `uniq_user_ref_reason` and `idx_user_recent` indexes.
- MongoDB transactions docs: https://www.mongodb.com/docs/manual/core/transactions/
