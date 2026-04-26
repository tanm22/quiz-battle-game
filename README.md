# Quiz Battle System

Real-time multiplayer quiz game with Go microservices, RabbitMQ event bus, Redis state, MongoDB persistence, and a Flutter client. Includes premium subscriptions (Razorpay), referral system, login streaks, daily rewards, push notifications (FCM), tournaments, a global leaderboard, and a server-authoritative coin economy with shop ([architecture](docs/architecture.md), [API](docs/api.md), [runbook](docs/runbook-coins.md)).

## Architecture

```
                              Flutter App (gRPC + Riverpod)
                              ============================
                                        |
            +-----------+----------+----+----+----------+-----------+
            |           |          |         |          |           |
       gRPC:50054  gRPC:50051 gRPC:50052 gRPC:50053 gRPC:50055 HTTP:8080
            |           |          |         |          |           |
       +----+----+ +----+-----+ +-+-------+ +----+----+ +----+----+----+
       |  Auth   | |Matchmking| |  Quiz   | |Scoring  | |   Payment    |
       | Service | | Service  | | Engine  | |/User Svc | |   Service    |
       +---------+ +----------+ +---------+ +---------+ +--------------+
            |           |          |    |         |          |
            |           |          |    |         |          |
            +-----+-----+----+----+----+---------+----------+
                  |          |         |
           +-----+---+ +----+----+ +--+------+
           | MongoDB  | |  Redis  | |RabbitMQ |
           | (persist)| | (state) | |(events) |
           +----------+ +---------+ +---------+
                                         |
                                   +-----+--------+
                                   | Notification  |
                                   | Service (FCM) |
                                   +--------------+
```

### Data Flow: A Match Lifecycle

```
1. Player taps "Play" in Flutter
2. Flutter -> Matchmaking.JoinMatchmaking (gRPC)
3. Matchmaking checks daily quota (Redis Lua script), adds to pool (Redis ZSET)
4. Matchmaking poller pairs players, creates room, publishes "match.created" -> RabbitMQ
5. Quiz Engine consumes "match.created", selects questions from MongoDB, stores in Redis
6. Quiz Engine broadcasts QuestionBroadcast via gRPC server stream to Flutter
7. Player answers -> Quiz.SubmitAnswer -> publishes "answer.submitted" -> RabbitMQ
8. Scoring consumes "answer.submitted", calculates score, updates Redis leaderboard (Lua)
9. Scoring publishes "leaderboard.updated" -> Quiz Engine broadcasts to streams
10. After all rounds: Quiz publishes "match.finished" -> Scoring persists to MongoDB
11. Scoring updates Elo ratings, win streaks, detects referral conversions
```

### Service Summary

| Service | Port | Key Responsibilities |
|---------|------|---------------------|
| **Auth** | 50054 | Google Sign-In, username/password, guest login, JWT, email verification, streak logic, daily rewards, notification crons |
| **Matchmaking** | 50051 | Player pool (Redis ZSET), room creation, daily quota gate (Lua script), match subscription streams |
| **Quiz Engine** | 50052 | Question selection, round orchestration, game event streaming, timer sync, tournaments |
| **Scoring/User** | 50053 | Score calculation, leaderboard (Lua), match history, home screen data, referral rewards, FCM tokens, global leaderboard |
| **Payment** | 50055 + 8080 | Razorpay order creation, webhook (HMAC verify + SETNX idempotency), plan management, expiry cron |
| **Notification** | -- | RabbitMQ consumer only: dispatches FCM push for streaks, rewards, tournaments, premium events |

Six Go services + infrastructure (Redis, RabbitMQ, MongoDB) = 9 containers total via Docker Compose.

## Tech Stack

| Layer | Technology | Justification |
|-------|-----------|---------------|
| **Backend** | Go 1.25 | Low-latency, strong concurrency (goroutines), single-binary deployment, ideal for real-time game servers |
| **Client** | Flutter / Dart | Single codebase for Android + iOS + web, fast prototyping with hot reload, strong gRPC support via `grpc` package |
| **Communication** | gRPC + Protobuf | Type-safe contracts via `.proto`, efficient binary serialization, native server streaming for real-time game events |
| **Message Broker** | RabbitMQ | Reliable message delivery with acknowledgements, topic exchange for flexible routing patterns, built-in management UI for debugging. Chosen over Kafka because we need per-message routing (e.g., `match.created` vs `answer.submitted`) not high-throughput log streaming |
| **In-Memory State** | Redis 7 | Sub-millisecond reads for live match state, atomic Lua scripts for leaderboard + quota, sorted sets for matchmaking pool, SETNX for distributed guards |
| **Database** | MongoDB 6 | Flexible schema for evolving user profiles, native JSON-like documents match Go structs, sparse unique indexes for optional fields (email, googleId, referralCode) |
| **Payments** | Razorpay | Indian payment gateway supporting UPI/cards/netbanking, webhook-based async capture, test mode for development |
| **Push Notifications** | Firebase Cloud Messaging | Industry standard for Android/iOS push, multi-device token management, free tier sufficient for quiz app |
| **State Management** | Riverpod 3 | Compile-safe dependency injection for Flutter, auto-disposal of providers, built-in async state handling for gRPC calls |
| **Auth** | JWT (HS256) | Stateless authentication, gRPC metadata-compatible, `golang-jwt/v5` with algorithm validation to prevent `alg:none` attacks |
| **Containerization** | Docker + multi-stage build | Single Dockerfile builds all 7 binaries (6 services + seed), Alpine runtime image (~20MB), health checks + dependency ordering in Compose |

## Quick Start

### Prerequisites

- Docker and Docker Compose
- (Optional) Go 1.25+, Flutter 3.7+, `protoc` for local development

### Run Everything

```bash
# Clone and start all 9 containers
git clone <repo-url>
cd quiz-battle

# Set environment variables (copy and fill in secrets)
cp .env.example .env
# Edit .env with your API keys (see Environment Variables below)
source .env

# Start all services
docker-compose up --build
```

The seed container runs first and creates:
- MongoDB indexes (unique on username, email, googleId, referralCode, razorpayOrderId)
- 50+ quiz questions across multiple topics and difficulties
- 6 test users: `alice`, `bob`, `charlie`, `diana`, `eve`, `frank` (password: `testpass123`)
- 2 sample tournaments (one premium-only, one open)

### Verify Services

| Endpoint | URL |
|----------|-----|
| RabbitMQ Management UI | http://localhost:15672 (guest / guest) |
| Razorpay Webhook | http://localhost:8080/webhook/razorpay |
| Auth gRPC | localhost:50054 |
| Matchmaking gRPC | localhost:50051 |
| Quiz gRPC | localhost:50052 |
| Scoring gRPC | localhost:50053 |
| Payment gRPC | localhost:50055 |

## Environment Variables

| Variable | Service | Required | Purpose |
|----------|---------|----------|---------|
| `JWT_SECRET` | All services | Yes | JWT signing key (HS256). Must be identical across all services for token validation |
| `GOOGLE_CLIENT_ID` | Auth | For Google Sign-In | Google OAuth 2.0 client ID. Obtained from Google Cloud Console |
| `RAZORPAY_KEY_ID` | Payment | For payments | Razorpay API key ID (starts with `rzp_test_` or `rzp_live_`) |
| `RAZORPAY_KEY_SECRET` | Payment | For payments | Razorpay API key secret for server-side order creation |
| `RAZORPAY_WEBHOOK_SECRET` | Payment | For payments | HMAC-SHA256 secret for webhook signature verification. Set in Razorpay Dashboard > Webhooks |
| `RESEND_API_KEY` | Auth | For email OTP | Resend.com API key for sending email verification codes |
| `FIREBASE_PROJECT_ID` | Notification | For FCM | Firebase project ID (default set in compose). Only needed if service-account JSON lacks `project_id` |
| `MONGO_URI` | All services | Auto-set in Docker | MongoDB connection string (default: `mongodb://mongo:27017/quizbattle`) |
| `REDIS_ADDR` | Auth, Matchmaking, Quiz, Scoring, Payment | Auto-set in Docker | Redis address (default: `redis:6379`) |
| `RABBITMQ_URL` | All except Notification uses conn | Auto-set in Docker | AMQP URL (default: `amqp://guest:guest@rabbitmq:5672/`) |

**Firebase push notifications:** Place a real service-account JSON at `secrets/firebase-admin.json` to enable FCM delivery. Without it, the notification service runs in stub mode (logs only). See [`secrets/README.md`](secrets/README.md).

## API Documentation

All service-to-client communication uses gRPC with Protobuf. The single proto definition is at [`proto/quiz.proto`](proto/quiz.proto).

### AuthService (port 50054)

| RPC | Request | Response | Auth | Description |
|-----|---------|----------|------|-------------|
| `Register` | `username`, `password`, `email?`, `referral_code?` | `AuthResponse` (user_id, token, profile fields, streak, reward) | No | Create account with optional referral code |
| `Login` | `username`, `password` | `AuthResponse` | No | Login with credentials, auto-processes daily streak |
| `GuestLogin` | -- | `AuthResponse` | No | Create anonymous account (plan = "free") |
| `GoogleSignIn` | `id_token`, `referral_code?` | `GoogleSignInResponse` (token, UserProfile, is_new_user, streak_updated, reward) | No | Google OAuth sign-in/sign-up, creates user if new |
| `GetProfile` | -- | `ProfileResponse` (profile fields + streak) | Yes | Get authenticated user's profile |
| `SendEmailCode` | `email`, `purpose` ("login"/"reset"/"link") | `sent: bool` | No | Send 6-digit OTP via Resend. Rate limited: 1 per 60s per email |
| `VerifyEmailCode` | `email`, `code` | `verified: bool`, `token?`, `user_id?` | No | Verify OTP. Returns JWT for login flow. Max 3 attempts |
| `LoginWithEmail` | `email` | `sent: bool` | No | Passwordless email login (sends code) |
| `LinkEmail` | `email`, `code` | `linked: bool` | Yes | Link email to authenticated account |
| `ResetPassword` | `email`, `code`, `new_password` | `success: bool` | No | Reset password with verified OTP |
| `CheckUsername` | `username` | `available: bool` | No | Check username availability |
| `DeleteAccount` | -- | `deleted: bool` | Yes | Permanently delete account and referrals |
| `ClaimDailyReward` | -- | `RewardGrant` (coins, badge, bonus_quizzes), `StreakInfo` | Yes | Claim daily streak reward. Atomic: prevents double-claim via `$ne` filter on rewardClaimedDate |
| `GetStreakInfo` | -- | `StreakInfo` (current, longest, last_claimed_date) | Yes | Get current streak state |

### MatchmakingService (port 50051)

| RPC | Request | Response | Auth | Description |
|-----|---------|----------|------|-------------|
| `JoinMatchmaking` | `user_id`, `rating` | `status` (QUEUED / ALREADY_IN_QUEUE) | Yes | Enter matchmaking pool. Free users: daily quota checked via Lua script. Premium: unlimited |
| `LeaveMatchmaking` | `user_id` | `removed: bool` | Yes | Leave pool. Refunds daily quota if removed before match |
| `SubscribeToMatch` | `user_id`, `sequence_number` | **stream** `MatchEvent` (room_id, players, seq) | Yes | Server-sent stream. Fires when a match is found. Supports reconnection via sequence_number |

### QuizService (port 50052)

| RPC | Request | Response | Auth | Description |
|-----|---------|----------|------|-------------|
| `GetRoomQuestions` | `room_id` | `questions[]` (id, text, options, difficulty, topic) | Yes | Fetch questions for a room. Correct answers are NOT included |
| `SubmitAnswer` | `room_id`, `user_id`, `round`, `option_index`, `client_timestamp` | `accepted: bool` | Yes | Submit answer. Published to RabbitMQ for async scoring |
| `StreamGameEvents` | `room_id`, `user_id`, `sequence_number` | **stream** `GameEvent` (oneof: question, leaderboard, round_result, match_end, player_joined, timer_sync) | Yes | Real-time game stream. Reconnection-safe via sequence_number |
| `GetTournamentList` | -- | `tournaments[]` (id, name, times, status, participant_count, required_plan, prize) | Yes | List all tournaments |
| `JoinTournament` | `tournament_id` | `success: bool` | Yes | Join tournament. Validates plan requirement |

### ScoringService (port 50053)

| RPC | Request | Response | Auth | Description |
|-----|---------|----------|------|-------------|
| `CalculateScore` | `room_id`, `user_id`, `round`, `option_index`, `answer_time_ms` | `score`, `correct: bool`, `speed_multiplier` | Internal | Score a single answer (called internally via RabbitMQ, not directly by client) |
| `GetLeaderboard` | `room_id` | `entries[]` (user_id, username, score, rank, plan) | Yes | Get live match leaderboard from Redis |
| `GetMatchHistory` | `limit?`, `offset?` | `matches[]` (room_id, winner, players[], rounds, duration, created_at) | Yes | Paginated match history |
| `GetHomeScreenData` | -- | `UserProfile`, `quota_remaining`, `quota_limit`, `leaderboard_preview[]` | Yes | Aggregated home screen: profile + quota + top players |
| `GetReferralDashboard` | -- | `referral_code`, `total_invites`, `conversions`, `coins_earned` | Yes | Referral program stats |
| `ApplyReferralCode` | `code` | `success: bool` | Yes | Apply a referral code (one-time per user) |
| `UpdateFCMToken` | `token` | `success: bool` | Yes | Register FCM token for push notifications (deduped) |
| `GetGlobalLeaderboard` | `time_filter` ("daily"/"weekly"/"alltime") | `entries[]` (user_id, username, score, rank, plan) | Yes | Global leaderboard with time filters |

### PaymentService (port 50055 gRPC + port 8080 HTTP)

| RPC | Request | Response | Auth | Description |
|-----|---------|----------|------|-------------|
| `CreateOrder` | `plan_duration` ("monthly"/"yearly") | `order_id`, `key_id`, `amount` (paise), `currency` | Yes | Create Razorpay order. Monthly: 14900 paise, Yearly: 149900 paise |
| `GetPlanStatus` | -- | `plan` ("free"/"premium"), `expires_at` | Yes | Current subscription status |
| `GetPaymentHistory` | `limit?`, `offset?` | `payments[]` (order_id, amount, currency, status, plan_duration, created_at) | Yes | Paginated payment records |

**HTTP Endpoint:**

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/webhook/razorpay` | HMAC-SHA256 signature in `X-Razorpay-Signature` header | Razorpay payment webhook. Reads full body before HMAC verify. SETNX idempotency with 72h TTL prevents duplicate processing. On success: updates order status, sets user plan, invalidates Redis plan cache, publishes `payment.captured` event |

## RabbitMQ Event Flow

All events flow through the `sx` topic exchange. Each service declares its own queues bound to specific routing keys.

| Routing Key | Producer | Consumer | Payload | Purpose |
|------------|----------|----------|---------|---------|
| `match.created` | Matchmaking | Quiz Engine | `{roomId, players[]}` | Select questions, store in Redis, start round 1 |
| `answer.submitted` | Quiz Engine | Scoring | `{roomId, userId, round, optionIndex, clientTimestamp, serverTimestamp}` | Score answer, update Redis leaderboard atomically |
| `leaderboard.updated` | Scoring | Quiz Engine | `{roomId, entries[]}` | Broadcast leaderboard to game streams |
| `round.completed` | Quiz Engine | Quiz Engine | `{roomId, round}` | Self-consume: advance to next round or finish match |
| `match.finished` | Quiz Engine | Scoring | `{roomId, winner, players[], rounds, duration}` | Persist match to MongoDB, update Elo ratings, win streaks, detect referral conversions |
| `payment.captured` | Payment (webhook) | Scoring | `{userId, plan, orderId}` | Upgrade user plan in MongoDB, invalidate Redis plan cache |
| `referral.first_quiz_completed` | Scoring | Scoring | `{referrerId, refereeId}` | Grant referral coins to referrer, mark referral as converted |
| `notif.streak.warning` | Auth (cron, 20:00 IST) | Notification | `{userId, event, currentStreak}` | FCM push: "Your X-day streak is at risk!" |
| `notif.daily.reward` | Auth (cron, 09:00 IST) | Notification | `{userId, event}` | FCM push: "Claim your daily reward!" |
| `notif.tournament.remind` | Quiz (ticker) | Notification | `{userId, event, tournamentName, minutesUntilStart}` | FCM push: "Tournament starting in N minutes" |
| `notif.premium.activated` | Scoring | Notification | `{userId, event, plan}` | FCM push: "Welcome to Premium!" |
| `notif.premium.expiry` | Payment (cron, daily) | Notification | `{userId, event, expiresAt}` | FCM push: 3-day warning before plan expiry |
| `premium.expired` | Payment (cron, daily) | Notification | `{userId, event}` | FCM push: "Your premium plan has expired" |

## Redis Key Schema

All keys are defined in [`pkg/keys/keys.go`](pkg/keys/keys.go) as a single source of truth shared by all services.

| Key Pattern | Type | TTL | Purpose |
|-------------|------|-----|---------|
| `matchmaking:pool` | Sorted Set | -- | Active matchmaking pool. Score = Elo rating |
| `room:{id}:state` | String (JSON) | 30 min | Room state: playerIds, status, round, createdAt |
| `room:{id}:players` | Hash | 30 min | userId -> PlayerInfo JSON (username, rating, plan) |
| `room:{id}:round` | String (int) | 30 min | Current round index |
| `room:{id}:questions` | List | 30 min | Ordered question IDs for the match |
| `room:{id}:leaderboard` | Sorted Set | 30 min | Live scores. Updated atomically via Lua script |
| `room:{id}:answers:{round}` | Hash | 30 min | userId -> answer JSON. Written via HSETNX for idempotency |
| `room:{id}:round:{round}:closed` | String | 30 sec | SETNX guard preventing duplicate round advancement |
| `room:lock:{id}` | String | 10 sec | Distributed lock for room creation (SETNX) |
| `user:{id}:daily_quota` | String (int) | IST midnight | Free user quiz counter. INCR via Lua with EXPIREAT |
| `user:{id}:plan` | String | 5 min | Cached plan. Write-invalidate (DEL on change), read-through from MongoDB |
| `referral:code:{code}` | String | -- | Referral code -> userId mapping (persistent) |
| `webhook:idempotency:{payId}` | String | 72 hours | Razorpay webhook duplicate prevention (SETNX) |
| `emailcode:{email}:{purpose}` | String | 10 min | Email verification OTP code |
| `emailrate:{email}` | String | 60 sec | Email send rate limiter (SETNX) |
| `match_invite:{from}:{to}` | String | 30 min | Throttle duplicate match invite notifications |

## MongoDB Collections

| Collection | Key Fields | Indexes | Purpose |
|-----------|-----------|---------|---------|
| `users` | _id, username, email, googleId, plan, rating, coins, streak, referralCode, winStreak | unique(username), unique(email, sparse), unique(googleId, sparse), unique(referralCode, sparse), compound(plan, planExpiresAt) | User profiles and game stats |
| `questions` | text, options, correctIndex, difficulty, topic | difficulty | Quiz question bank |
| `match_history` | roomId, winner, players[], rounds, duration | unique(roomId), players.userId | Completed match records |
| `payments` | userId, razorpayOrderId, amount, status, planDuration | unique(razorpayOrderId), userId | Payment transaction log |
| `referrals` | referrerId, refereeId, referralCode, status, rewardGranted | unique(refereeId), referrerId | Referral tracking and reward state |
| `tournaments` | name, startTime, endTime, status, requiredPlan, participants[] | compound(startTime, status) | Tournament definitions and participation |

## Design Decisions

### Why Redis for Matchmaking and Live Game State?

Live match data (leaderboards, answers, room state) needs sub-millisecond reads and atomic updates. Redis sorted sets give O(log N) ranked access for the matchmaking pool, and Lua scripts provide atomic read-modify-write for leaderboards without distributed locks. All room keys auto-expire after 30 minutes, eliminating stale state cleanup.

### Why RabbitMQ over Kafka?

This system needs per-message routing (e.g., `match.created` goes to Quiz, `answer.submitted` goes to Scoring) with acknowledgement-based delivery. RabbitMQ's topic exchange maps directly to this pattern. Kafka's strength is high-throughput ordered log streaming, which we don't need -- our event volume is bounded by active matches, not a firehose. RabbitMQ also provides a management UI out of the box for debugging event flow.

### Scoring Formula

```
base_points = correct ? 100 : 0
speed_multiplier = max(0.5, 1.0 - (answer_time_ms / 15000))
round_score = base_points * speed_multiplier
```

Faster answers earn up to 1.0x multiplier; the slowest valid answer still earns 0.5x. `answer_time_ms` is clamped to [0, 15000] server-side to prevent client timestamp manipulation.

### Elo Rating System

K=32 formula: `new_rating = old_rating + K * (actual - expected)` where `expected = 1 / (1 + 10^((opponent_rating - player_rating) / 400))`. Beating a higher-rated opponent yields more points than beating a lower-rated one.

### Daily Quota (Free Users)

Free users get 5 quizzes per day (IST timezone). Implemented as a Redis Lua script that atomically INCRs a counter and sets EXPIREAT to next IST midnight. The Lua script guarantees no race between checking and incrementing. Leaving matchmaking before a match refunds the quota (guarded against stale-counter edge case).

### Atomic Streak and Reward Claiming

MongoDB `UpdateOne` with `$ne: today` filter on `lastClaimedDate` / `rewardClaimedDate` ensures that concurrent login requests can't double-process streaks or farm daily reward coins. If `ModifiedCount == 0`, the streak/reward was already processed by another request.

### Answer Idempotency

Player answers use Redis `HSETNX` (hash set-if-not-exists) instead of separate EXISTS + SET. This single atomic operation prevents the TOCTOU race where two goroutines could both see "not answered" and both record the answer.

### AMQP Thread Safety

RabbitMQ channels are NOT thread-safe. All services that publish from multiple goroutines use a `sync.Mutex`-protected `publish()` helper method to serialize channel access.

### Plan Cache Strategy

Write-invalidate pattern: `DEL user:{id}:plan` on any plan change (payment, expiry), read-through from MongoDB with 5-minute TTL. This avoids stale cache reads after payment while keeping hot-path reads fast.

### Webhook Security

Razorpay webhook handler: (1) reads full request body with `io.ReadAll` before HMAC-SHA256 verification (streaming verification is fragile), (2) SETNX idempotency key with 72-hour TTL prevents duplicate processing, (3) HTTP client has 10-second timeout for Razorpay API calls.

## Project Structure

```
quiz-battle/
  proto/quiz.proto           # Single Protobuf definition for all services
  pkg/
    auth/                    # JWT middleware (interceptor + token creation)
    keys/                    # Redis key names + helper functions (single source of truth)
    models/                  # Shared Go structs (User, Payment, Tournament, etc.)
  services/
    auth/main.go             # Auth service (Google, email, streak, cron jobs)
    matchmaking/main.go      # Matchmaking service (pool, room creation, quota)
    quiz/main.go             # Quiz engine (rounds, streaming, tournaments)
    scoring/main.go          # Scoring service (leaderboard, match history, referrals)
    payment/main.go          # Payment service (Razorpay, webhook, plan management)
    notification/main.go     # Notification service (FCM consumer)
  seed/
    main.go                  # Database seeder (indexes, questions, test users, tournaments)
    questions.json           # Quiz question bank
  secrets/
    firebase-admin.json      # Firebase service account (gitignored)
  flutter/
    lib/
      main.dart              # App entry point, theme, gRPC channel setup
      proto/                 # Generated Dart protobuf/gRPC stubs
      providers/             # Riverpod providers (auth, game, scoring, payment)
      screens/               # 12 screens (home, gameplay, matchmaking, login, etc.)
      widgets/               # Shared widgets (OTP input, animated toast, etc.)
      theme/                 # AppColors, shared theme constants
  docker-compose.yml         # 9-container orchestration
  Dockerfile                 # Multi-stage: Go builder + Alpine runtime
  .env                       # Environment variables (gitignored)
```

## Local Development

```bash
# Run infrastructure only
docker-compose up redis rabbitmq mongo

# Seed database
cd /path/to/quiz-battle
go run ./seed

# Run each service (separate terminals)
go run ./services/auth
go run ./services/matchmaking
go run ./services/quiz
go run ./services/scoring
go run ./services/payment
go run ./services/notification
```

### Flutter

```bash
cd flutter
flutter pub get

# Android emulator (default host: 10.0.2.2)
flutter run

# Desktop or web
flutter run --dart-define=BACKEND_HOST=localhost

# Waydroid (Linux Android container)
flutter run --dart-define=BACKEND_HOST=192.168.240.1
```

### Regenerate Proto Stubs

```bash
# Go stubs
protoc --go_out=. --go-grpc_out=. \
  --go_opt=paths=source_relative --go-grpc_opt=paths=source_relative \
  proto/quiz.proto

# Dart stubs
protoc --dart_out=grpc:flutter/lib/proto proto/quiz.proto
```

## Known Limitations

- **No TLS on gRPC:** Services communicate over plaintext gRPC. Production deployment would need TLS certificates or a service mesh.
- **Single Redis instance:** No Redis Cluster or Sentinel. Acceptable for demo scale but not production HA.
- **No horizontal scaling:** Each service runs as a single instance. The matchmaking poller and RabbitMQ consumers would need coordination (e.g., consumer groups, leader election) for multi-instance deployment.
- **AMQP channel recovery:** If the RabbitMQ connection drops, services don't auto-reconnect the AMQP channel. A restart is required.
- **Tournament system:** Basic implementation -- join and list only. No bracket generation, scheduled match orchestration, or live tournament leaderboard.
- **No rate limiting on gRPC:** Email codes are rate-limited, but gRPC endpoints lack general rate limiting.
- **Notification stub mode:** Without a real Firebase service-account JSON, push notifications are logged but not delivered.

## Future Improvements

- WebSocket gateway for browser clients alongside gRPC
- Redis Sentinel / Cluster for high availability
- OpenTelemetry tracing across services
- Tournament bracket system with automated scheduling
- Friend system and direct challenge invitations
- Question contribution and moderation pipeline
- Admin dashboard for content and user management
