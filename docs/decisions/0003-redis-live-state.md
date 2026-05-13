# ADR-0003 — Redis for live game state, matchmaking, and short-lived coordination

## Status
Accepted — 2026-04-15.

## Context

Three categories of state need a home outside of Mongo:

1. **The matchmaking pool.** A constantly-mutating set of (userId, rating) pairs that the pair-poller reads thousands of times a second. Mongo queries would be wasteful; we don't need durability for in-flight matchmaking sessions (the user just rejoins on reconnect).
2. **Live match state.** Per-room hashes (players), strings (current round), sorted sets (leaderboard), and per-round answer hashes. Sub-millisecond reads are required because the streaming code path reads several of these per `SubmitAnswer`. Match data is cheap to reconstruct on player rejoin (the answer log is durable; the leaderboard isn't, but a 30-minute room lifetime makes this acceptable).
3. **Distributed coordination.** Room-creation locks, round-close guards, webhook idempotency, email send rate limits, daily quotas. Each one is a small string with a TTL.

Mongo can technically do all of this, but the access patterns map poorly:

- Sorted set ranking is `find().sort()` in Mongo — fine for paginated reads, not fine for "increment one user's score and re-rank in O(log N)".
- Atomic increment-with-TTL doesn't exist in Mongo without an `UpdateOne` round-trip and a separate TTL index.
- Sub-millisecond reads aren't realistic on Mongo without aggressive caching, which is what Redis is anyway.

## Decision

Use **Redis 7** as the live-state store. Treat Redis as **cache + coordination**, not durable storage. Everything in Redis is either reproducible from Mongo or short-lived enough that losing it on a Redis flush is acceptable.

Specific rules:

1. **Every key has an explicit TTL** except the matchmaking pool (`matchmaking:pool`) and the referral-code map (`referral:code:{code}`), which are intentionally persistent in-memory caches.
2. **Lua scripts for multi-step atomic operations.** Two examples:
   - Daily quota: `LOAD`, check, `INCR`, `EXPIREAT` next IST midnight. Lua keeps these four operations atomic — without it we'd have a TOCTOU race that lets a free user run a 6th match.
   - Leaderboard update: read player + opponent scores, compute new rating, `ZADD`, optionally publish.
3. **SETNX for distributed mutual exclusion** with sensible TTLs: room creation lock (10 s), round-close guard (30 s), match-finalization guard (30 min), webhook idempotency (72 h).
4. **`HSETNX` for idempotent hash inserts.** Used for player answers (`room:R:answers:N` hash, fields keyed by userId). A retry sets the field exactly once.
5. **All key names live in `pkg/keys/keys.go`.** Single source of truth shared by every service; a typo would silently disable a feature in only one service.

## Consequences

### Positive
- The Lua + SETNX pattern gives us strong correctness guarantees with no service-level locks.
- Self-cleaning state: rooms TTL out 30 minutes after creation, OTPs after 10 minutes, presence keys after 60 seconds. No janitor process.
- The matchmaking pool ZSET supports `ZRANGEBYSCORE` in `O(log N + M)`, which is the fundamental matchmaking primitive ("find players within ±100 rating of me").

### Negative
- A Redis flush wipes the matchmaking pool and breaks any in-flight matches. The Flutter client sees a stream end and the user rejoins; not catastrophic but not invisible.
- Single instance — no Sentinel or Cluster. Documented in known limitations.
- Lua scripts are written inline as Go strings. They're tested but not as discoverable as separate `.lua` files would be; this is a minor cost we accept.

### Alternatives considered

**A. Mongo for everything.** Already discussed — wrong access pattern for ranked sets and atomic counters with TTL.

**B. In-process state per service.** Would scale linearly with instance count; doesn't survive restarts. Tied to single-instance deployment in a way Redis isn't (we can later switch to Redis Cluster).

**C. Redis + RedisJSON / RediSearch modules.** Useful in a larger system; we don't need their features.

## References
- `pkg/keys/keys.go` — all key names and helper functions.
- `services/matchmaking/main.go` — Lua quota script and `ZADD` / `ZREM` pool ops.
- `services/quiz/main.go` — room state, round close, match finalization.
- `services/scoring/main.go` — leaderboard Lua, in-match streak counter.
