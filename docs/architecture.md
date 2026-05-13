# Architecture

A single-page tour of how Quiz Battle is built and *why* each piece looks the way it does. If a sentence sounds opinionated, the rationale is one click away in the linked ADR.

## Contents

1. [The 30,000-ft view](#the-30000-ft-view)
2. [Process boundaries (services)](#process-boundaries-services)
3. [Data planes (durable, live, transit)](#data-planes-durable-live-transit)
4. [Wire protocols and ports](#wire-protocols-and-ports)
5. [Match lifecycle, sequence by sequence](#match-lifecycle-sequence-by-sequence)
6. [Cross-cutting concerns](#cross-cutting-concerns)
7. [Failure modes and mitigations](#failure-modes-and-mitigations)
8. [Scaling envelope](#scaling-envelope)
9. [Why each major choice](#why-each-major-choice)

---

## The 30,000-ft view

Three pictures, three layers of zoom.

### Layer 1 — what the user sees

```
   Flutter app                                  Operator
   (Android, iOS, web, desktop)                 (browser)
        |                                          |
        | gRPC over HTTP/2 (plaintext locally,     | HTTP
        |   TLS at the edge in production)         |
        |                                          |
        v                                          v
   +-----------------------------------+    +---------------+
   |  Backend (6 services + admin)     |    | Admin (:8090) |
   +-----------------------------------+    +---------------+
```

### Layer 2 — services and their wires

```
                         Flutter
                            |
                  +---------+---------+---------+---------+---------+
                  |         |         |         |         |         |
                Auth   Matchmaking  Quiz    Scoring   Payment   (Notification
               50054      50051    50052     50053  50055+8080     consumes
                  \         |        |         |       |          RabbitMQ
                   \        |        |         |       |          only)
                    \       v        v         v       v
                     \  +---------------------------------+
                      \ |  Redis 7    RabbitMQ    MongoDB |
                       \|  :6379       :5672      :27017  |
                        +---------------------------------+
                                                |
                                                v
                                          Notification
                                          (RabbitMQ -> FCM)
```

### Layer 3 — request hot path during a match

```
  Player A (Flutter)             Player B (Flutter)
    |                              |
    | SubmitAnswer (gRPC unary)    | SubmitAnswer
    v                              v
  +--------------------+         +--------------------+
  | Quiz Engine #1     |         | Quiz Engine #1     |
  |                    |         | (same instance)    |
  |   HSETNX answer    |         |                    |
  |   publish          |---------+                    |
  |   "answer.submitted"          |                    |
  +--------+-----------+         +--------+-----------+
           |                              |
           v                              |
  +--------+-------+                      |
  | RabbitMQ "sx"  |                      |
  +--------+-------+                      |
           |                              |
           v                              |
  +--------+-------+                      |
  | Scoring        |                      |
  |   Lua: ZINCRBY |                      |
  |     room:R:lb  |                      |
  |   publish      |                      |
  |   "leaderboard.updated"               |
  +--------+-------+                      |
           |                              |
           v                              v
  Quiz Engine streams LeaderboardUpdate to both A and B over their
  open gRPC server-streaming RPCs (StreamGameEvents).
```

The hot path holds an exactly-once invariant *per answer*: even if the player taps twice or the network retries, only one ledger row is recorded, only one score increment is applied, and the leaderboard reaches a single consistent state. That property is what every other architectural choice is in service of.

---

## Process boundaries (services)

We chose six services + admin because each one owns a coherent slice of state, and each slice has a different failure profile. Killing matchmaking shouldn't take payments down; restarting quiz shouldn't log everyone out. See [adr-0001](./decisions/0001-microservices-split.md).

| Service | Owns | Key state writes | Why it's its own process |
|---|---|---|---|
| **Auth** | Identity + session lifecycle | `users` (insert/update on auth flows), refresh-token store | Stateless flows can fail loudly without affecting active matches |
| **Matchmaking** | Player pool, room creation | `matchmaking:pool` (Redis ZSET), room keys | One poller loop is simpler when it's the only one |
| **Quiz** | Round orchestration, gRPC streams | `room:*` keys, in-process stream channels | Streaming is naturally goroutine-heavy; isolation keeps memory bounded |
| **Scoring** | Score math, leaderboards, persistence, coins, friends, analytics | `match_history`, `coin_ledger`, `users.coins` (transactional), `friend_requests`, `tournament_*` | Most "user-facing reads" land here; collocating them keeps the wire light |
| **Payment** | Plan lifecycle, money | `payments`, `users.plan`, `users.planExpiresAt` | Razorpay webhook + signature math demands an HTTP port and tight access |
| **Notification** | FCM dispatch + policy gate | None (read-only Redis counters) | Pure consumer — restarting it doesn't drop a single user request |
| **Admin** | Operator-facing read-only dashboard | None | A stuck dashboard probe should never affect a player-facing service |

Each service's `main.go` is the canonical entry point — read those files top-to-bottom and you've seen the entire service.

---

## Data planes (durable, live, transit)

Three categories, three databases. The hardest bugs come from mixing them up, so we keep the rules simple.

### Durable: MongoDB

The replica-set-enabled (`--replSet rs0`) Mongo is the only thing that survives a `docker compose down -v`. See [adr-0011](./decisions/0011-mongo-replica-set.md) for why a single-node replica set, not a standalone.

| Collection | Purpose | Notable indexes |
|---|---|---|
| `users` | Profile, plan, coins, rating, streak, win-streak | unique(`username`), unique-sparse(`email`), unique-sparse(`googleId`), unique-sparse(`referralCode`), (`plan`, `planExpiresAt`) |
| `questions` | Question bank | (`difficulty`) — sampled via `$sample` aggregation |
| `match_history` | Completed matches (immutable) | unique(`roomId`), (`players.userId`) |
| `payments` | Razorpay transactions | unique(`razorpayOrderId`), (`userId`) |
| `referrals` | Referral edges + reward state | unique(`refereeId`), (`referrerId`) |
| `tournaments` | Tournament definitions + participants | (`startTime`, `status`), unique-sparse(`autoGenerated`, `weekKey`), (`status`, `endTime`, `winnersAwarded`) |
| `tournament_standings` | Per-(tournament, user) score row | unique(`tournamentId`, `userId`), (`tournamentId`, `score DESC`) |
| `tournament_payouts` | Durable work-list for prize delivery | unique(`tournamentId`, `userId`), (`status`) |
| `coin_ledger` | Every coin movement (audit trail) | unique(`userId`, `refId`, `reason`) — **idempotency key**; (`userId`, `createdAt DESC`) |
| `coin_effect_outbox` | Pending shop side-effects (currently: premium-trial extension) | (`processedAt`, `kind`) |
| `friend_requests` | Pending + accepted friend edges | unique(`fromUserId`, `toUserId`), (`toUserId`, `status`), (`fromUserId`, `status`), (`toUserId`, `fromUserId`) |
| `friend_challenge_outbox` | Friend-challenge notif work-list | (`processedAt`, `createdAt`) |
| `answer_log` | One row per question answered (analytics) | (`userId`, `createdAt DESC`), (`userId`, `topic`) |
| `rating_history` | Per-match rating snapshot | (`userId`, `createdAt ASC`) |

Two patterns recur:

- **Idempotency by unique key.** `coin_ledger`'s `(userId, refId, reason)` is the canonical example. Producers retry freely; the second insert hits the unique index, the writer catches duplicate-key, and returns the original row. No bookkeeping in the caller.
- **Outbox for cross-service effects.** Mongo transaction guarantees that the action (debit) and the *intent* of the side-effect (outbox row) commit together. A separate worker drains the outbox. See [adr-0007](./decisions/0007-premium-trial-outbox.md).

### Live: Redis

Every key in Redis is reproducible from durable state, so we treat Redis as cache + ephemeral coordination. Everything has an explicit TTL except the matchmaking pool and the referral-code map. See [adr-0003](./decisions/0003-redis-live-state.md).

Major key families (full reference in [api.md](./api.md)):

| Family | Type | TTL | Owner |
|---|---|---|---|
| `matchmaking:pool` | sorted set (score = rating) | none | matchmaking |
| `room:{id}:*` | hash, list, sorted set, strings | 30 min | quiz, scoring |
| `room:{id}:round:{n}:closed` | string (SETNX guard) | 30 s | quiz |
| `room:{id}:match_finalized` | string (SETNX guard) | 30 min | quiz |
| `user:{id}:daily_quota` | string (int, EXPIREAT IST midnight) | until midnight IST | matchmaking |
| `user:{id}:plan` | string (cached "free"/"premium") | 5 min, write-invalidated | scoring (read), payment (invalidate) |
| `emailcode:{email}:{purpose}` | string (6-digit OTP) | 10 min | auth |
| `webhook:idempotency:{paymentId}` | string (SETNX guard) | 72 h | payment |
| `notif:*` | counters, dedup keys | 24-48 h | notification |
| `presence:{userId}` | string | 60 s | scoring (Heartbeat) |
| `challenge:throttle:{a:b}` | string (canonical pair) | 30 s | scoring |

Two atomic operations do a lot of heavy lifting:

- **Lua scripts** for daily quota (read counter, increment, set EXPIREAT) and leaderboard updates (compute new score, ZADD, optionally publish). Lua is the only way to make multi-step Redis operations atomic without locks.
- **SETNX with TTL** for distributed mutual exclusion: room creation, round-close, webhook dedup, match finalization.

### Transit: RabbitMQ

A single topic exchange (`sx`) routes every cross-service event. Each consumer declares its own named queue and binds a routing-key pattern. The pattern is **publish-and-forget**: producers don't know who consumes, consumers don't know who produces. See [adr-0002](./decisions/0002-rabbitmq-over-kafka.md).

| Routing key | Producer | Consumer(s) |
|---|---|---|
| `match.created` | matchmaking | quiz |
| `answer.submitted` | quiz | scoring |
| `leaderboard.updated` | scoring | quiz |
| `round.completed` | quiz (self) | quiz |
| `match.finished` | quiz | scoring |
| `payment.captured` | payment (webhook + VerifyPayment) | scoring |
| `coins.earn.match_win` | quiz (finalize) | scoring |
| `coins.earn.tournament_placement` | scoring (finalization worker) | scoring |
| `coins.earn.referral_referrer` / `.referral_referee` | scoring (referral handler) | scoring |
| `referral.first_quiz_completed` | scoring | scoring |
| `notif.streak.warning` | auth (cron) | notification |
| `notif.daily.reward` | auth (cron) | notification |
| `notif.tournament.remind` | quiz (ticker) | notification |
| `notif.premium.activated` | scoring | notification |
| `notif.premium.expiry` | payment (cron) | notification |
| `notif.friend.challenge` | scoring | notification |
| `notif.match.invite` | scoring | notification |
| `premium.expired` | payment (cron) | notification |

Three queue patterns recur:

- **Consumer-private queue + topic binding.** E.g., `coin-earn-queue` binds `coins.earn.*`. Adding a new earn source means publishing a new routing key — no consumer change.
- **DLQ (dead-letter queue) for poison pills.** Bad payloads `nack` without requeue and end up in `coin-earn-dlq` for an operator. Transient errors `nack` with requeue and retry.
- **Manual ack on success.** A consumer that crashes after work but before ack re-receives the same delivery; the work itself is idempotent (per the Mongo unique index pattern).

---

## Wire protocols and ports

| Channel | Protocol | Notes |
|---|---|---|
| Client → service | gRPC over HTTP/2 | Plaintext inside the cluster; TLS at the edge in production. Server streaming is used for matchmaking subscribe + game events. |
| Service → service | None (deliberate) | We do not call services from other services synchronously. Cross-service interaction goes via RabbitMQ. |
| Service → Mongo | Mongo wire protocol | `replicaSet=rs0` in URI is load-bearing. |
| Service → Redis | RESP | Pipelined; we use Lua for multi-step atomic ops. |
| Service → RabbitMQ | AMQP 0.9.1 | Channels are not goroutine-safe; we wrap `publish` in a per-service mutex. |
| Razorpay → backend | HTTPS POST | `:8080/webhook/razorpay`; HMAC-SHA256 over the raw body. |
| Operator → admin | HTTPS / HTTP | `:8090/` and `:8090/api/stats`. |
| Prometheus → service | HTTP | `:2112/metrics` inside each container; mapped to 21251-21256 on the host. |

Exposed host ports:

| Port | Service | Use |
|---|---|---|
| 50051 | matchmaking | gRPC |
| 50052 | quiz | gRPC |
| 50053 | scoring | gRPC |
| 50054 | auth | gRPC |
| 50055 | payment | gRPC |
| 8080 | payment | HTTP webhook |
| 8090 | admin | HTTP dashboard |
| 6379 | redis | RESP |
| 27017 | mongo | Mongo wire |
| 5672 | rabbitmq | AMQP |
| 15672 | rabbitmq | management UI (`guest`/`guest`) |
| 21251-21256 | each service | Prometheus `/metrics` |

---

## Match lifecycle, sequence by sequence

The pipeline below is the one feature you must understand to make sense of anything else. It exercises every service, every database, every queue.

```
PLAYER A                MATCHMAKING            QUIZ                SCORING            MONGO/REDIS/RABBITMQ
   |                         |                  |                     |                          |
   | JoinMatchmaking         |                  |                     |                          |
   |------------------------>|                  |                     |                          |
   |                         | Lua: incr quota  |                     |                          |
   |                         |   set EXPIREAT   |                     |                          |
   |                         |   ZADD pool      |                     |                          |
   |<------ QUEUED ----------|                  |                     |                          |
   |                         |                  |                     |                          |
   | SubscribeToMatch (stream open)             |                     |                          |
   |------------------------>| (held open)      |                     |                          |
   |                         |                  |                     |                          |
   |                         |  poller (1 s)    |                     |                          |
   |                         |  finds A + B     |                     |                          |
   |                         |  SETNX room:lock |                     |                          |
   |                         |  ZREM both       |                     |                          |
   |                         |  HMSET room:players                    |                          |
   |                         |  publish match.created ----------------+--->[ RabbitMQ sx ]------>|
   |<------- MatchEvent -----| (and to B)       |                     |                          |
   |                         |                  | match.created<------+--------------------------|
   |                         |                  | selectQuestions $sample                        |
   |                         |                  |   from MongoDB                                 |
   |                         |                  | RPUSH room:R:questions                         |
   |                         |                  |                     |                          |
   | StreamGameEvents (open) |                  |                     |                          |
   |---------------------------------------->   |                     |                          |
   |                         |                  | round 1 deadline    |                          |
   |                         |                  | broadcast Question  |                          |
   |<----QuestionBroadcast---|----- gRPC stream-|                     |                          |
   |                         |                  |                     |                          |
   | SubmitAnswer            |                  |                     |                          |
   |---------------------------------------->   |                     |                          |
   |                         |                  | HSETNX room:R:answers:1 (idempotent)            |
   |                         |                  | SADD room:R:answered:1                         |
   |                         |                  | publish answer.submitted----------------------->|
   |                         |                  |                     | scoring consumes         |
   |                         |                  |                     | Lua: score + ZINCRBY     |
   |                         |                  |                     | publish leaderboard.updated-->
   |                         |                  | leaderboard.updated |                          |
   |<--LeaderboardUpdate-----|------------------|                     |                          |
   |                         |                  |                     |                          |
   |                         |                  | SCARD answered == roster -> early-close round  |
   |                         |                  | publish round.completed (self)                 |
   |                         |                  | start round 2 ... rounds 3, 4, 5               |
   |                         |                  |                     |                          |
   |                         |                  | All 5 rounds done   |                          |
   |                         |                  | SETNX room:match_finalized                     |
   |                         |                  | publish match.finished -----------------------+
   |                         |                  | publish coins.earn.match_win (winner) --------+
   |                         |                  |                     | scoring persists match  |
   |                         |                  |                     |   insert match_history  |
   |                         |                  |                     |   bulk update users     |
   |                         |                  |                     |   (rating, wins, win-streak, lifetime stats)
   |                         |                  |                     | earn-consumer Grant(100)|
   |                         |                  | broadcast MatchEnd  |                          |
   |<------ MatchEnd --------|------------------|                     |                          |
```

A few details that matter:

- **Server-authoritative timer.** The client never decides when a round ends. `deadline_unix` is set by the server and broadcast with the question; the client only animates the countdown.
- **Idempotent answer submission.** `HSETNX` makes "set my answer for round 3" a single atomic step, so a retry doesn't overwrite or double-publish. See [adr-0005](./decisions/0005-coin-ledger-transactional.md) for the analogous pattern on the durable side.
- **Exactly-once finalization.** Two clients dropping at the same moment can both observe "everyone is gone, finalize!". The `room:{id}:match_finalized` SETNX guard collapses the race.
- **At-least-once with idempotent consumers.** RabbitMQ guarantees at-least-once delivery; idempotency lives in the consumer (Mongo unique index, Redis SETNX, or both). So we get the *effect* of exactly-once without paying for two-phase commit.

---

## Cross-cutting concerns

### Authentication & authorization

The Flutter client carries a JWT (HS256) in `authorization: Bearer ...` gRPC metadata. A shared interceptor in `pkg/auth/` validates the token and stuffs `userId` into the request context. RPCs that need auth read it from context; RPCs that don't (e.g., `Register`, `Login`, `CheckUsername`, `SendEmailCode`) skip the interceptor or short-circuit it.

Refresh-token rotation lives in auth: a single-use refresh token mints a new access + new refresh (revoking the old in the same family). Replaying an already-rotated token revokes the whole family — standard reuse-detection. See [adr-0008](./decisions/0008-jwt-refresh-rotation.md).

### Rate limiting

Per-RPC, scoped where it matters most:

- Email OTP send: 1 per 60 s per email (Redis SETNX with 60 s TTL).
- SubmitAnswer: 60/min per user (`pkg/ratelimit/`, in-process token bucket) — the realistic ceiling is one answer per ~3 s, so this only kicks in on obvious abuse.

There is no global gRPC rate limit; that's a deliberate gap for v1.

### Observability

- **Structured logs.** `pkg/log/` wraps `slog` with context propagation. Every log line carries `service`, `traceId`, and any contextual IDs (roomId, userId).
- **Prometheus metrics.** Each service exposes `/metrics` on `:2112`. Counters for AMQP publish/consume, gauges for outbox lag (`outbox_pending_total`, `outbox_oldest_age_seconds`), histograms for RPC latency.
- **Admin dashboard.** `services/admin/` is a small HTML page that scrapes Mongo, Redis, RabbitMQ admin API and shows recent matches, queue depths, pool size, plan distribution. Read-only on purpose — see [adr-0010](./decisions/0010-notification-policy.md) for the philosophy of "operator dashboards do not write".

### Notifications policy gate

The notification service is not a thin "publish-to-FCM" forwarder. Before each push it consults `pkg/notif/policy.go`:

- **Quiet hours.** Default 23:00-08:00 in the user's timezone — no push during sleep.
- **Daily cap.** Default 5 pushes/day per user across all categories.
- **Per-category dedup window.** E.g., "streak warning" can fire at most once per hour.
- **Per-user opt-out.** Users toggle individual categories in app settings.

Dropped pushes increment a counter with the drop reason so we can audit policy effectiveness. See [adr-0010](./decisions/0010-notification-policy.md).

### Background workers

Started as goroutines in each service's `main.go`:

| Service | Worker | Trigger | What it does |
|---|---|---|---|
| matchmaking | pair poller | every 1 s | Pop nearest-rated pairs from the pool, create rooms |
| quiz | round-close ticker | per-round, 15 s timeout | Closes a round when no early-close happens |
| quiz | tournament reminder ticker | every 1 min | Publishes `notif.tournament.remind` for tournaments starting in 5/15/60 min |
| scoring | earn consumer | RabbitMQ | Routes `coins.earn.*` through `Ledger.Grant` |
| scoring | friend challenge outbox drainer | every 30 s | Retries stranded `notif.friend.challenge` pushes |
| scoring | tournament finalization worker | every 60 s | Finds completed tournaments, computes top-N, writes payouts, publishes `coins.earn.tournament_placement` |
| payment | premium-trial outbox consumer | every 1 s | Drains `coin_effect_outbox` rows of kind `premium_trial`, extends `users.planExpiresAt` |
| payment | outbox watcher | every 30 s | Publishes lag gauges; logs `outbox stuck` if oldest row >5 min |
| payment | plan-expiry cron | every 24 h | Finds users whose `planExpiresAt` passed, sets plan to free, publishes `premium.expired` |
| payment | premium-expiry warning cron | every 24 h | T-3 days warning, sets `premiumExpiryWarned`, publishes `notif.premium.expiry` |
| auth | streak warning cron | daily 20:00 IST | Publishes `notif.streak.warning` to users with a 2+ day streak who haven't claimed today |
| auth | daily reward cron | daily 09:00 IST | Publishes `notif.daily.reward` to users with an unclaimed reward |

Every cron uses a UTC-internal timer with an IST conversion at fire time; we don't rely on the container's TZ.

---

## Failure modes and mitigations

| If this happens | The system does this |
|---|---|
| RabbitMQ restarts | Producers fail next publish, consumers reconnect on next connection cycle, but **the AMQP channel itself doesn't auto-reconnect**. Restart the affected service. |
| Mongo primary steps down | Driver retries the operation on the new primary (transactions are retry-safe). |
| Redis flushes | All matchmaking sessions and live rooms reset. Durable state is unaffected. Players in flight see a stream-end error and rejoin. |
| Player disconnects mid-match | Their `StreamGameEvents` stream errors. The room stays open until the round timeout; if they don't come back, scoring counts them as "no answer". |
| Both players disconnect | Each connection-drop checks `connectedPlayersInRoom`. The last to drop triggers `finishMatch`, guarded by the `room:{id}:match_finalized` SETNX. |
| Razorpay webhook arrives twice | `SETNX webhook:idempotency:{paymentId}` makes the second arrival a no-op. |
| User taps "Buy" twice in 200ms | Same `idempotency_key` → `Ledger.Grant` either short-circuits (duplicate-key catch) or the unique index rejects the second insert. |
| Outbox consumer crashes mid-row | Next poll re-applies. The premium-trial extension uses **renewal-aware** logic (extend from the existing `planExpiresAt`, not from `now`) so re-applying after a `MarkProcessed` failure does grant an extra `days × 24h`. Window is small; full mitigation requires a `claimedAt` lease and isn't in v1. See [adr-0007](./decisions/0007-premium-trial-outbox.md). |
| FCM secret missing | Notification service runs in stub mode (logs only). Policy gate and dedup still execute. |
| Two services try to write `users.planExpiresAt` | They don't. Payment is the only writer; scoring signals intent via the outbox. See [adr-0007](./decisions/0007-premium-trial-outbox.md). |

---

## Scaling envelope

Today's single-instance deployment comfortably handles low-hundreds of concurrent matches (the gating factor is usually Mongo writes per second from `persistMatch`). Beyond that, the steps look like:

| Step | What changes |
|---|---|
| Horizontal-scale stateless services (auth, payment, admin) | Just run more instances; they share no in-process state. |
| Horizontal-scale matchmaking | Need a leader-election or coordinator queue — only one instance should run the 1-second pair poller. Otherwise N instances all pair the same player. |
| Horizontal-scale quiz | Need sticky-routing so both players' streams land on the same instance, *or* replace in-process stream channels with a Redis-pubsub fan-out. |
| Horizontal-scale scoring | Most paths are idempotent and stateless. The earn-consumer / outbox-consumer pattern doesn't yet have per-row claim leases; multi-instance scoring would race. |
| Multi-replica payment | The premium-trial consumer needs `claimedAt + claimedBy` fields (TODO; flagged in [adr-0007](./decisions/0007-premium-trial-outbox.md)). |
| Redis HA | Sentinel for single-master HA; Cluster for shard. |
| Mongo HA | Three-node replica set + read-preference tuning. |

---

## Why each major choice

Quick index of the architectural decisions and the documents that explain them.

| Choice | ADR |
|---|---|
| Split into six services rather than one monolith | [adr-0001](./decisions/0001-microservices-split.md) |
| RabbitMQ topic exchange over Kafka | [adr-0002](./decisions/0002-rabbitmq-over-kafka.md) |
| Redis for live match state + matchmaking pool | [adr-0003](./decisions/0003-redis-live-state.md) |
| gRPC + server streaming for client communication | [adr-0004](./decisions/0004-grpc-streaming.md) |
| Coin ledger uses Mongo transactions on rs0 | [adr-0005](./decisions/0005-coin-ledger-transactional.md) |
| Coin reward amounts (initial calibration) | [adr-0006](./decisions/0006-coin-reward-amounts.md) |
| Premium-trial extension via transactional outbox | [adr-0007](./decisions/0007-premium-trial-outbox.md) |
| JWT HS256 with refresh-rotation | [adr-0008](./decisions/0008-jwt-refresh-rotation.md) |
| Razorpay dual-path (client SDK + webhook backstop) | [adr-0009](./decisions/0009-razorpay-dual-path.md) |
| Notification policy gate (quiet hours, cap, dedup) | [adr-0010](./decisions/0010-notification-policy.md) |
| Single-node Mongo replica set in dev | [adr-0011](./decisions/0011-mongo-replica-set.md) |
| Flutter + Riverpod over alternatives | [adr-0012](./decisions/0012-flutter-riverpod.md) |
