# API Reference

Every gRPC RPC, every HTTP endpoint, every RabbitMQ event the Quiz Battle backend speaks. The single source of truth for the gRPC surface is `proto/quiz.proto` in the repo; this document is the human-readable cross-reference, plus the wire-level details that aren't in the proto file.

## Contents

1. [Conventions](#conventions)
2. [AuthService — `:50054`](#authservice--50054)
3. [MatchmakingService — `:50051`](#matchmakingservice--50051)
4. [QuizService — `:50052`](#quizservice--50052)
5. [ScoringService — `:50053`](#scoringservice--50053)
6. [PaymentService — `:50055` (gRPC) and `:8080` (HTTP)](#paymentservice--50055-grpc-and-8080-http)
7. [Admin — `:8090` (HTTP)](#admin--8090-http)
8. [Metrics — `:2112/metrics` per service](#metrics--2112metrics-per-service)
9. [RabbitMQ events](#rabbitmq-events)
10. [Redis key reference](#redis-key-reference)
11. [Error codes](#error-codes)

---

## Conventions

- **Auth.** Unless marked "no auth", an RPC requires a JWT in gRPC metadata as `authorization: Bearer <token>`. The interceptor in `pkg/auth/` validates the token and injects `userId` into the request `context.Context`.
- **Request/response messages.** Names follow `<RPCName>Request` / `<RPCName>Response`. Field types come from `proto/quiz.proto`.
- **Timestamps.** Unix epoch in milliseconds unless the field name says `_unix` (seconds) or `_date` (YYYY-MM-DD string, always IST). The streak fields are IST dates because the daily-reward clock is IST.
- **Money.** All Razorpay amounts are in *paise* (1/100 of a rupee) per Razorpay's API.
- **Pagination.** Two styles: integer `limit`/`offset` (legacy) and opaque `page_token`/`page_size` (new). Newer RPCs use the token form because it tolerates inserts during pagination.
- **Error model.**
  - gRPC-level failures (auth, missing field, server error) return a non-OK `status.Status` with `codes.Unauthenticated`, `codes.InvalidArgument`, `codes.Internal`, etc.
  - *Domain* failures (e.g., "balance too low") return a successful response with `success=false` and a string `error_code`. This is deliberate — domain failures are not exceptional and the client should not have to differentiate them from network errors.

---

## AuthService — `:50054`

Owns identity. Handles password, Google, guest, and passwordless-email sign-in flows; daily streak; daily reward; refresh-token rotation; profile updates.

### `Register`
No auth. Creates a username/password account. `email` and `referral_code` are optional.

| Field (request) | Type | Required | Notes |
|---|---|:-:|---|
| `username` | string | ✓ | Unique, validated by `pkg/validate/`. |
| `password` | string | ✓ | Bcrypt-hashed before insert. |
| `email` | string |   | If set, must be unique. Sparse-unique index in Mongo. |
| `referral_code` | string |   | If set, must resolve to an existing user. Records a `referrals` row in pending state. |

Response: `AuthResponse` (`user_id`, `username`, `token`, `refresh_token`, `expires_in`, `rating`, `matches_played`, `wins`, `email`, `is_guest=false`, `plan="free"`, `coins`, `streak`, `referral_code`, `streak_updated`, `reward`, `onboarding_completed`).

### `Login`
No auth. Username + password. Also processes today's streak if not yet processed (atomic via `$ne: today` filter on `lastLoginDate`).

### `GuestLogin`
No auth. Creates an anonymous account with a generated username and no password. `is_guest=true`. Guest accounts can later be promoted by setting an email or linking Google.

### `GoogleSignIn`
No auth. Verifies a Google `id_token` against Google's certs (validates `aud == GOOGLE_CLIENT_ID`). Looks up or creates the user by `googleId`. Returns `GoogleSignInResponse` (`token`, `refresh_token`, `expires_in`, `user_profile`, `is_new_user`, `streak_updated`, `reward`).

### `GetProfile`
Auth. Returns the calling user's full `ProfileResponse`.

### `UpdateProfile`
Auth. Updates `display_name`, `avatar_url`, `preferred_topics`, `onboarding_completed`.

### `CheckUsername`
No auth. Returns `available: bool`. Cheap — index lookup.

### `DeleteAccount`
Auth. Hard-deletes the user record, their referral row, and ends any active session. Idempotent.

### Email OTP family (no auth except `LinkEmail`)

All four share the same Redis-backed OTP store:

- `emailcode:{email}:{purpose}` — 6-digit code, 10-min TTL.
- `emailrate:{email}` — SETNX with 60-second TTL, prevents send spam.

| RPC | Purpose | Notes |
|---|---|---|
| `SendEmailCode` | Send a code. `purpose` is `"login"`, `"reset"`, or `"link"`. | Calls Resend.com; failures are surfaced as `codes.Internal`. |
| `VerifyEmailCode` | Verify a code. On `purpose="login"`, returns a JWT + refresh token. | Max 3 attempts per code; over-cap deletes the code. |
| `LoginWithEmail` | Convenience: `SendEmailCode` with `purpose="login"`. | Saves the client a parameter. |
| `LinkEmail` | Auth. Links a verified email to an authenticated account. | `purpose="link"` code required. |
| `ResetPassword` | Reset a forgotten password via verified `purpose="reset"` code. | Bcrypt-hashes the new password. |

### Streak + daily reward

| RPC | Auth | Behavior |
|---|---|---|
| `GetStreakInfo` | ✓ | Returns `{current, longest, last_claimed_date}`. |
| `ClaimDailyReward` | ✓ | Atomic claim. `UpdateOne` with `$ne: today` on `rewardClaimedDate` — if `ModifiedCount==0`, reward already claimed; surface that to the user. Reward ladder is `rewardForDay(streakDay)` in `services/auth/main.go`. |

### Refresh-token rotation

| RPC | Auth | Behavior |
|---|---|---|
| `RefreshToken` | refresh-token in body | Single-use rotation. Mints a new access + new refresh in the same family; revokes the old refresh. If the presented token has already been rotated, the whole family is revoked (reuse defense). |
| `Logout` | refresh-token in body | Revokes the whole family. Idempotent. |

See [adr-0008](./decisions/0008-jwt-refresh-rotation.md) for the security model.

---

## MatchmakingService — `:50051`

### `JoinMatchmaking`
Auth. Enter the matchmaking pool.

| Request | Type | Notes |
|---|---|---|
| `user_id` | string | Must match the JWT. The interceptor enforces this. |
| `rating` | int32 | Current Elo rating from the user document. |

Behavior:

1. Lua script `incrQuotaIfBelowLimit`:
   - Read `user:{id}:daily_quota`.
   - If user is free and counter ≥ 5, return rejected.
   - Else `INCR` and `EXPIREAT` next IST midnight.
2. `ZADD matchmaking:pool` with score = rating.
3. Return `{status: QUEUED}` (or `ALREADY_IN_QUEUE` if you were already there).

Errors: `codes.Unauthenticated`, `codes.ResourceExhausted` (quota exceeded).

### `LeaveMatchmaking`
Auth. `ZREM` from pool. Refunds the quota counter if the user is removed before a match was created. Returns `{removed: bool}`.

### `SubscribeToMatch`
Auth. **Server-streaming.** Holds open until a match is found for this user.

| Request | Type | Notes |
|---|---|---|
| `user_id` | string | Must match JWT. |
| `sequence_number` | int64 | Last event seq seen, for reconnection. Pass `0` on first connect. |

Each `MatchEvent` carries `{room_id, players[], sequence_number}`. The stream closes after a single event — clients call `JoinMatchmaking` again to re-enter.

---

## QuizService — `:50052`

### `GetRoomQuestions`
Auth. Returns the 5 questions for a room *without* `correctIndex`. The server is the only place that knows the answers.

### `SubmitAnswer`
Auth. Single-shot answer submission.

| Request | Type | Notes |
|---|---|---|
| `room_id` | string | |
| `user_id` | string | Must match JWT. |
| `round` | int32 | 1-indexed. |
| `option_index` | int32 | 0-indexed. |
| `client_timestamp` | int64 | Used to compute answer time. Server clamps `answer_time_ms` to `[0, 15000]`. |

Behavior:

- Rate-limit: 60/min per user.
- `HSETNX room:{id}:answers:{round}` makes the write idempotent.
- `SADD room:{id}:answered:{round}` and compare to roster: if all players answered, fire early `round.completed` (don't wait the 15 s timer).
- Publish `answer.submitted` to RabbitMQ.

Response: `{accepted: bool}`.

### `StreamGameEvents`
Auth. **Server-streaming.** Live game events for the calling user in a given room.

Reconnection: pass the last `sequence_number` you saw; the server resumes from there. Events come as a `oneof`:

| Event | Fields | When |
|---|---|---|
| `QuestionBroadcast` | `question_id`, `text`, `options[]`, `deadline_unix`, `round` | Start of each round |
| `LeaderboardUpdate` | `entries[]` (user_id, username, score, rank, plan) | After every scored answer |
| `RoundResult` | `round`, `correct_index` | After a round closes |
| `MatchEnd` | `room_id`, `winner`, `players[]` (PlayerResult), `rounds`, `duration` | After round 5 |
| `PlayerJoined` | `user_id`, `username`, `plan` | When a player's stream attaches |
| `TimerSync` | `deadline_unix` | Periodic; lets the client correct clock drift |

`PlayerResult` includes `coins_awarded` (server-authoritative; 100 for rank 1, 0 otherwise).

### Tournaments

| RPC | Auth | Behavior |
|---|---|---|
| `GetTournamentList` | ✓ | List active + upcoming + recently-completed tournaments. |
| `JoinTournament` | ✓ | Adds the caller to `tournaments.participants[]`. Validates `requiredPlan`. |
| `GetTournament` | ✓ | Full detail view. |
| `GetTournamentLeaderboard` | ✓ | Live standings (sorted, server-ranked). |

---

## ScoringService — `:50053`

This service owns most user-facing reads. It's named "scoring" historically; today it's better described as "the user service".

### Match results

| RPC | Auth | Notes |
|---|---|---|
| `CalculateScore` | internal | Score a single answer. Called via RabbitMQ, never directly by clients. |
| `GetLeaderboard` | ✓ | Returns the live `room:{id}:leaderboard` sorted set. |
| `GetMatchHistory` | ✓ | Paginated. `limit` defaults to 20. |

### Home + profile aggregates

| RPC | Auth | Notes |
|---|---|---|
| `GetHomeScreenData` | ✓ | `{profile, quota_remaining, quota_limit, leaderboard_preview[]}`. Aggregates 3 reads into one request to keep the home screen snappy. |
| `GetGlobalLeaderboard` | ✓ | `time_filter` is `"daily" \| "weekly" \| "alltime"` (default). |

### Referrals

| RPC | Auth | Notes |
|---|---|---|
| `GetReferralDashboard` | ✓ | Code, invites, conversions, coins earned. |
| `ApplyReferralCode` | ✓ | One-time per user. Records a `referrals` row in pending state. Conversion triggers later when the referee completes their first quiz. |

### FCM token

| RPC | Auth | Notes |
|---|---|---|
| `UpdateFCMToken` | ✓ | Dedupes; the user's `fcmTokens` array stores up to 5 most-recent tokens. |

### Coins & ledger

| RPC | Auth | Notes |
|---|---|---|
| `GetCoinBalance` | ✓ | Reads `users.coins`. Kept atomically consistent with `coin_ledger` (ADR-0005). |
| `GetCoinLedger` | ✓ | Paged, newest-first. Page size clamped 1-100; defaults to 25. |

`CoinLedgerEntry` fields: `id`, `delta` (signed), `reason` (e.g., `match_win`, `referral_referrer`, `shop_purchase`, `admin_adjustment`), `ref_id` (the idempotency key), `balance_after`, `created_at_unix_ms`, `metadata` (map).

### Shop

| RPC | Auth | Notes |
|---|---|---|
| `GetShopCatalog` | ✓ | Every `ShopItem` (active + inactive — UI hides inactive). |
| `GetShopInventory` | ✓ | Owned cosmetics, equipped IDs, reroll charges, streak-freeze flag, balance. |
| `PurchaseShopItem` | ✓ | Atomic debit + effect. See below. |
| `EquipCosmetic` | ✓ | Sets `equippedCosmeticId` / `equippedNameColor` if owned. |
| `ConsumeReroll` | ✓ | Atomic `$inc rerollCharges: -1`. Returns post-decrement count. |

`ShopItem.kind` values: `cosmetic.avatar_frame`, `cosmetic.name_color`, `streak_freeze`, `premium_trial`, `reroll_topic`. SKUs are seeded from `seed/shop_items.json`.

**`PurchaseShopItem`** request: `item_id`, `idempotency_key` (UUID generated client-side per user-initiated tap). Response: `{success, ledger_entry_id, new_balance, error_code}`.

Domain `error_code` values:
- `INSUFFICIENT` — balance < `priceCoins`.
- `INACTIVE` — `shop_items.active==false`.
- `WEEKLY_CAP` — streak_freeze only; one per ISO week.
- `UNKNOWN` — `item_id` not in catalog.

Effect handling:
- `cosmetic.*` — appended to `ownedCosmetics[]`. Already-owned cosmetics fail with `ALREADY_OWNED` (also `INSUFFICIENT` rolls back the debit if any race occurs).
- `streak_freeze` — sets `streakFreezeHeld=true` and `streakFreezeWeekIso="YYYY-Www"`. Once-per-week cap.
- `premium_trial` — enqueues `coin_effect_outbox` row of kind `"premium_trial"` for the payment service to drain. See [adr-0007](./decisions/0007-premium-trial-outbox.md).
- `reroll_topic` — `$inc rerollCharges: +1`.

### Friends & challenges

| RPC | Auth | Notes |
|---|---|---|
| `SendFriendRequest` | ✓ | Exactly one of `target_username` / `target_referral_code`. Idempotent on `(fromUserId, toUserId)`. Auto-accept on reverse-direction collision (Bob already sent Alice → both become friends). |
| `RespondToFriendRequest` | ✓ | Accept or reject a pending incoming request. |
| `GetFriendsList` | ✓ | Accepted friendships; `online` derived from `presence:{userId}` TTL. |
| `GetFriendRequests` | ✓ | Pending incoming requests. |
| `Heartbeat` | ✓ | Refreshes `presence:{userId}` TTL (60 s). Client calls every ~30 s while app is open. |
| `ChallengeFriend` | ✓ | Creates a private 1v1 room with the caller and a friend. Publishes `notif.friend.challenge`. Returns the room id. |

Error codes for `SendFriendRequest`: `USER_NOT_FOUND`, `ALREADY_FRIENDS`, `ALREADY_PENDING`, `SELF`, `INVALID_ARGUMENT`.

### Notification preferences

| RPC | Auth | Notes |
|---|---|---|
| `GetNotificationPrefs` | ✓ | Per-category mute flags + timezone. Quiet hours and the daily cap are server-side product defaults, not user-tunable. |
| `UpdateNotificationPrefs` | ✓ | Set per-category mute + timezone. |
| `MarkNotificationOpened` | ✓ | Client fires when the user taps a push. Bumps a per-(user, category, day) open counter via SETNX dedup. |

### Analytics

| RPC | Auth | Notes |
|---|---|---|
| `GetUserAnalytics` | ✓ | Lifetime per-topic accuracy + response-time percentiles + 30-day daily rating series. All from `answer_log` and `rating_history` aggregations. |
| `GetMonthlyRecap` | ✓ | "Your `<Month>`" recap card: matches played, wins, win rate, most-played topic, longest streak as of end-of-month. |

---

## PaymentService — `:50055` (gRPC) and `:8080` (HTTP)

### gRPC RPCs

| RPC | Auth | Notes |
|---|---|---|
| `CreateOrder` | ✓ | Hits Razorpay `POST /v1/orders` with the plan amount. Inserts a `payments` row in `status="created"`. Returns `{order_id, key_id, amount_paise, currency}`. |
| `VerifyPayment` | ✓ | Client-side fast path. Recompute HMAC-SHA256 of `order_id + "\|" + payment_id` with the secret; compare with `razorpay_signature`. On match, `capturePayment` (idempotent via SETNX). |
| `GetPlanStatus` | ✓ | Returns `{plan, expires_at}`. |
| `GetPaymentHistory` | ✓ | Paginated payment records. |

**Plans** (configured in `services/payment/main.go::CreateOrder`):

| Plan | Amount (paise) | Duration |
|---|---:|---|
| `monthly` | 29 900 (₹299) | 30 days |
| `yearly` | 299 900 (₹2 999) | 365 days |

### HTTP endpoints

| Method | Path | Auth | Notes |
|---|---|---|---|
| `POST` | `/webhook/razorpay` | HMAC-SHA256 signature in `X-Razorpay-Signature` | Razorpay webhook backstop. Reads full body before HMAC verify (streaming verification is fragile). SETNX `webhook:idempotency:{paymentId}` with 72 h TTL. |

The signature uses two distinct HMAC secrets, with two distinct inputs:

- **VerifyPayment (client → backend)**: HMAC-SHA256(`RAZORPAY_KEY_SECRET`, `order_id + "|" + payment_id`).
- **Webhook (Razorpay → backend)**: HMAC-SHA256(`RAZORPAY_WEBHOOK_SECRET`, `raw_request_body`).

Both paths converge on the same `capturePayment(orderID, paymentID)` helper. SETNX collapses races between client callback and webhook; whoever arrives first publishes `payment.captured`, the other becomes a no-op.

`capturePayment` does:

1. SETNX guard.
2. `payments.status = "captured"` (Mongo).
3. Set `users.plan="premium"`, `users.planExpiresAt=now + duration`. `$unset premiumExpiryWarned`.
4. Invalidate the `user:{id}:plan` Redis cache.
5. Publish `payment.captured` (scoring consumes; primarily for cache invalidation + welcome push).

See [adr-0009](./decisions/0009-razorpay-dual-path.md).

---

## Admin — `:8090` (HTTP)

Read-only operator console. Lives in its own binary (`services/admin/main.go`) so a stuck dashboard probe can't affect any user-facing service.

| Method | Path | Notes |
|---|---|---|
| `GET` | `/` | HTML dashboard: recent matches, active rooms, RabbitMQ queue depths, Redis pool size, payments today, plan distribution. |
| `GET` | `/api/stats` | JSON payload backing the dashboard. Convenient for ad-hoc tooling. |

Admin queries the RabbitMQ HTTP API at `:15672` with the credentials in `RABBITMQ_USER` / `RABBITMQ_PASSWORD`. Mongo and Redis are queried directly via standard drivers, read-only. No writes are issued from this binary.

---

## Metrics — `:2112/metrics` per service

Every service runs a Prometheus HTTP server on `:2112`. The compose file maps the container ports to `21251-21256` on the host.

Common metrics across all services:

| Metric | Type | Labels | Meaning |
|---|---|---|---|
| `amqp_publishes_total` | counter | `routing_key`, `status` | Publish counts (`ok` / `err`). |
| `amqp_consumes_total` | counter | `queue`, `status` | Consume counts (`ok` / `err`). |
| `grpc_request_duration_seconds` | histogram | `method`, `code` | Per-RPC latency. |

Per-service:

- `services/payment`: `outbox_pending_total{kind}`, `outbox_oldest_age_seconds{kind}`, `razorpay_calls_total{kind, status}`.
- `services/notification`: `notif_dispatch_total{category, result}`, `notif_dropped_total{category, reason}`.
- `services/quiz`: `quiz_round_close_reason_total{reason}` (`early`/`timer`), `quiz_active_rooms`.
- `services/matchmaking`: `mm_pool_size`, `mm_pair_latency_seconds`.

The list is not exhaustive — grep `pkg/metrics/` and each service's `main.go` for the authoritative roster.

---

## RabbitMQ events

All events flow through a single topic exchange named `sx` (durable). Each consumer declares its own named queue and binds a routing-key pattern. Producers don't know who consumes; consumers don't know who produces.

### Game lifecycle

| Routing key | Producer | Consumer | Payload | Purpose |
|---|---|---|---|---|
| `match.created` | matchmaking | quiz | `{roomId, players[]}` | Start a match: select questions, cache in Redis, kick off round 1. |
| `answer.submitted` | quiz | scoring | `{roomId, userId, round, optionIndex, clientTimestamp, serverTimestamp}` | Score the answer, update the leaderboard. |
| `leaderboard.updated` | scoring | quiz | `{roomId, entries[]}` | Broadcast to open streams. |
| `round.completed` | quiz (self) | quiz | `{roomId, round}` | Advance to next round or finish match. |
| `match.finished` | quiz | scoring | `{roomId, winner, players[], rounds, duration}` | Persist to `match_history`, update users (rating, wins, win-streak, lifetime stats), append `answer_log` and `rating_history`. |

### Coins

| Routing key | Producer | Consumer | Payload |
|---|---|---|---|
| `coins.earn.match_win` | quiz (finalize) | scoring (earn consumer) | `{userId, amount, refId="match:{roomId}:user:{userId}"}` |
| `coins.earn.tournament_placement` | scoring (finalization worker) | scoring | `{userId, amount, refId="tournament:{tournamentId}:user:{userId}"}` |
| `coins.earn.referral_referrer` | scoring | scoring | `{userId, amount, refId="referral:{referralId}:referrer"}` |
| `coins.earn.referral_referee` | scoring | scoring | `{userId, amount, refId="referral:{referralId}:referee"}` |
| `referral.first_quiz_completed` | scoring | scoring (referral handler) | `{referrerId, refereeId}` | Triggers the two referral grants above. |

**Bad payloads** (decode error, missing field, non-positive amount) are `Nack`ed without requeue, ending up in `coin-earn-dlq` for operator inspection. **Transient errors** `Nack` with requeue and retry on next delivery.

### Payments

| Routing key | Producer | Consumer | Payload |
|---|---|---|---|
| `payment.captured` | payment (webhook + VerifyPayment) | scoring | `{userId, plan, orderId}` |
| `premium.expired` | payment (cron) | notification | `{userId}` |

### Notifications

| Routing key | Producer | Consumer | Trigger |
|---|---|---|---|
| `notif.streak.warning` | auth (cron 20:00 IST) | notification | Users with a 2+ day streak who haven't claimed today |
| `notif.daily.reward` | auth (cron 09:00 IST) | notification | Users with an unclaimed daily reward |
| `notif.tournament.remind` | quiz (per-minute ticker) | notification | Tournaments starting in 5, 15, or 60 minutes |
| `notif.premium.activated` | scoring | notification | After payment.captured persists |
| `notif.premium.expiry` | payment (daily cron) | notification | 3-day warning before plan expires |
| `notif.match.invite` | scoring (ChallengeFriend / DM invite) | notification | Player invited another to a match |
| `notif.friend.challenge` | scoring (ChallengeFriend) | notification | Friend challenge sent |

All `notif.*` deliveries pass through the policy gate in the notification service (quiet hours, daily cap, dedup window, per-user opt-out). See [adr-0010](./decisions/0010-notification-policy.md).

### Premium trial (outbox)

Not a RabbitMQ event — Mongo-backed. Listed here because it's a sibling pattern.

- Producer: `services/scoring` `Purchase.Buy` for `premium.trial.3d`.
- Mechanism: insert a `coin_effect_outbox` row of kind `premium_trial` inside the same Mongo transaction as the debit.
- Consumer: `services/payment.startPremiumTrialConsumer` polls every 1 s, applies the effect, marks the row processed.
- See [adr-0007](./decisions/0007-premium-trial-outbox.md).

---

## Redis key reference

All keys are defined as constants and helper functions in `pkg/keys/keys.go`. Treat that file as the source of truth — anything you see here in name-form is `KeyConstantName` there.

| Key | Type | TTL | Owner | Purpose |
|---|---|---|---|---|
| `matchmaking:pool` | sorted set | none | matchmaking | Score = current rating. |
| `room:{id}:state` | string (JSON) | 30 min | quiz | Room metadata: players, status, round, createdAt. |
| `room:{id}:players` | hash | 30 min | quiz | `userId -> PlayerInfo JSON`. |
| `room:{id}:round` | string (int) | 30 min | quiz | Current round index. |
| `room:{id}:questions` | list | 30 min | quiz | Ordered question IDs. |
| `room:{id}:leaderboard` | sorted set | 30 min | scoring | Live scores. Atomic via Lua. |
| `room:{id}:answers:{round}` | hash | 30 min | quiz | `userId -> answer JSON`. `HSETNX` for idempotency. |
| `room:{id}:answered:{round}` | set | 30 min | quiz | `userId` set for early-close detection. |
| `room:{id}:round:{n}:closed` | string | 30 s | quiz | SETNX guard against duplicate round close. |
| `room:{id}:match_finalized` | string | 30 min | quiz | SETNX guard ensuring `finishMatch` runs once. |
| `room:{id}:streak:{userId}` | string (int) | 30 min | scoring | Per-user in-match consecutive-correct counter. |
| `room:{id}:correctorder:{round}` | string (int) | 30 min | scoring | Per-round counter for first-correct bonus. |
| `room:lock:{id}` | string | 10 s | matchmaking | Distributed lock for room creation. |
| `user:{id}:daily_quota` | string (int) | EXPIREAT IST midnight | matchmaking | Free-tier daily quiz count. |
| `user:{id}:plan` | string | 5 min | scoring (R), payment (W-invalidate) | Cached plan. |
| `emailcode:{email}:{purpose}` | string | 10 min | auth | 6-digit OTP. |
| `emailrate:{email}` | string | 60 s | auth | SETNX send rate limit. |
| `referral:code:{code}` | string | none | auth | `code -> userId`. |
| `webhook:idempotency:{paymentId}` | string | 72 h | payment | Razorpay webhook dedup. |
| `presence:{userId}` | string | 60 s | scoring | Online flag for friends list. |
| `challenge:throttle:{a}:{b}` | string (roomId) | 30 s | scoring | Mutual-challenge collapse. Canonicalized: same key for A→B and B→A. |
| `match_invite:{from}:{to}` | string | 30 min | scoring | Throttle duplicate match-invite pushes. |
| `notif:dailycap:{userId}:{YYYY-MM-DD}` | string (int) | 48 h | notification | Per-user-per-day push cap counter. |
| `notif:dedup:{userId}:{category}` | string | varies | notification | SETNX dedup inside a category window. |
| `notif:metric:sent:{category}:{YYYY-MM-DD}` | string (int) | 7 d | notification | Global per-day sent counter. |
| `notif:metric:opened:{category}:{YYYY-MM-DD}` | string (int) | 7 d | notification | Global per-day opened counter. |
| `notif:metric:dropped:{category}:{reason}:{YYYY-MM-DD}` | string (int) | 7 d | notification | Drops by reason (quiet hours, cap, dedup, opt-out). |
| `notif:opened_dedup:{userId}:{category}:{YYYY-MM-DD}` | string | 24 h | notification | One-bump-per-day per (user, category). |

---

## Error codes

### gRPC `codes.*`

Standard, returned in `status.Status`:

- `Unauthenticated` — missing or invalid JWT, expired access token, signature mismatch.
- `PermissionDenied` — token belongs to a different user than the request claims, or the user lacks plan rights.
- `InvalidArgument` — required field missing, format invalid, body too long.
- `NotFound` — entity does not exist (user, room, tournament, item).
- `AlreadyExists` — unique-index violation surfaced as a domain failure.
- `FailedPrecondition` — state-machine guard (e.g., `JoinTournament` on a completed tournament).
- `ResourceExhausted` — rate limit hit (email OTP send, daily quota, SubmitAnswer flood).
- `Internal` — unexpected; check service logs.
- `Unavailable` — Mongo/Redis/RabbitMQ briefly unreachable; client should retry.

### Domain `error_code` strings (string field on response)

These are *not* `codes.*` — they're successful gRPC responses with `success=false`. Categories listed in the RPC sections above; for reference:

- **Shop purchase**: `INSUFFICIENT`, `INACTIVE`, `WEEKLY_CAP`, `UNKNOWN`, `ALREADY_OWNED`.
- **Equip cosmetic**: `UNKNOWN`, `NOT_OWNED`, `NOT_EQUIPPABLE`.
- **Reroll**: `NO_CHARGES`.
- **Friend request**: `USER_NOT_FOUND`, `ALREADY_FRIENDS`, `ALREADY_PENDING`, `SELF`, `INVALID_ARGUMENT`.
- **Respond to friend request**: `NOT_FOUND`, `NOT_RECIPIENT`, `ALREADY_RESPONDED`.
- **Challenge friend**: `NOT_FRIENDS`, `OFFLINE`.

The hybrid design (gRPC code vs. domain string) keeps the client's error UX simple — domain errors map directly to in-app messages without parsing `status.Status`.
