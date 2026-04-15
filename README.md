# Quiz Battle System

Real-time multiplayer quiz game with Go microservices, RabbitMQ event bus, Redis state, MongoDB persistence, and a Flutter client. Includes premium subscriptions (Razorpay), referral system, login streaks, daily rewards, and push notifications (FCM).

## Architecture

```
Flutter App (gRPC)
    |
    +---> Auth :50054          (Google auth, JWT, streak, daily reward, cron jobs)
    +---> Matchmaking :50051   (player pool, room creation, quota gate)
    +---> Quiz Engine :50052   (questions, rounds, game streaming, tournaments)
    +---> Scoring/User :50053  (scores, persistence, home screen, referrals, FCM tokens)
    +---> Payment :50055/8080  (Razorpay orders, webhook, plan management)
    
    Notification Service       (RabbitMQ consumer only — FCM dispatch)
```

Six Go services + infrastructure (Redis, RabbitMQ, MongoDB) = 9 containers total.

| Service | Port | Key Responsibilities |
|---------|------|---------------------|
| **Auth** | 50054 | Google Sign-In, username/password, JWT, streak logic, daily reward, notification crons |
| **Matchmaking** | 50051 | Player pool (Redis ZSET), room creation, daily quota gate (Lua script) |
| **Quiz Engine** | 50052 | Question selection, round orchestration, game event streaming, tournaments |
| **Scoring/User** | 50053 | Score calculation, leaderboard, match history, home screen, referral rewards, FCM tokens |
| **Payment** | 50055 + 8080 | Razorpay order creation, webhook (HMAC verify + idempotency), plan expiry |
| **Notification** | — | RabbitMQ consumer: dispatches FCM push for all notification types |

## Quick Start

```bash
docker-compose up --build
```

Starts all 9 containers. Seed service runs first (questions, test users, indexes, tournaments).

**Test users:** alice, bob, charlie, diana, eve, frank (password: `testpass123`, ratings 950-1500)
**RabbitMQ UI:** http://localhost:15672 (guest/guest)
**Payment webhook:** http://localhost:8080/webhook/razorpay

## Environment Variables

| Variable | Service | Required | Purpose |
|----------|---------|----------|---------|
| `GOOGLE_CLIENT_ID` | Auth | For Google Sign-In | Google OAuth client ID |
| `RAZORPAY_KEY_ID` | Payment | For payments | Razorpay API key |
| `RAZORPAY_KEY_SECRET` | Payment | For payments | Razorpay API secret |
| `RAZORPAY_WEBHOOK_SECRET` | Payment | For payments | Webhook HMAC verification |
| `RESEND_API_KEY` | Auth | For email codes | Resend.com API key |
| `JWT_SECRET` | All | Yes | JWT signing secret |
| `FIREBASE_PROJECT_ID` | Notification | For FCM push | Firebase project id (default set in compose) |

**Firebase push notifications:** drop a real service-account JSON at
`secrets/firebase-admin.json` to enable FCM delivery. Without it, the
notification service runs in stub mode (logs only). See
[`secrets/README.md`](secrets/README.md) for setup.

## RabbitMQ Event Flow

| Event | Producer | Consumer | Purpose |
|-------|----------|----------|---------|
| `match.created` | Matchmaking | Quiz Engine | Select questions, start round 1 |
| `answer.submitted` | Quiz Engine | Scoring | Score answer, update leaderboard |
| `leaderboard.updated` | Scoring | Quiz Engine | Broadcast to game streams |
| `round.completed` | Quiz Engine | Quiz Engine | Advance to next round or finish |
| `match.finished` | Quiz Engine | Scoring | Persist match, update stats, detect referrals |
| `payment.captured` | Payment (HTTP) | Scoring | Upgrade user plan, invalidate cache |
| `referral.first_quiz_completed` | Scoring | Scoring | Grant referral coins, notify referrer |
| `notif.streak.warning` | Auth (cron) | Notification | FCM push: streak at risk |
| `notif.daily.reward` | Auth (cron) | Notification | FCM push: unclaimed reward |
| `notif.tournament.remind` | Quiz (ticker) | Notification | FCM push: tournament starting soon |
| `notif.premium.activated` | Scoring | Notification | FCM push: plan upgraded |
| `premium.expired` | Payment (cron) | Notification | FCM push: plan downgraded |

## Redis Key Schema

| Key | Type | TTL | Purpose |
|-----|------|-----|---------|
| `matchmaking:pool` | Sorted Set | — | Active matchmaking pool |
| `room:{id}:*` | Various | 30 min | Live match state |
| `user:{id}:daily_quota` | String (int) | IST midnight | Free user quiz counter |
| `user:{id}:plan` | String | 5 min | Cached plan (read-through) |
| `referral:code:{code}` | String | — | Referral code → userId |
| `webhook:idempotency:{payId}` | String | 72 hours | Duplicate webhook prevention |

## Key Design Decisions

- **Daily quota:** Lua script with unconditional EXPIREAT (ISSUE-03 corrected)
- **Streak:** MongoDB-only source of truth, no Redis copy (ISSUE-01)
- **Plan cache:** Write-invalidate (DEL on change), read-through from MongoDB (ISSUE-07)
- **Referral chain:** Game → referral event → User service → coin grant + notification (ISSUE-06)
- **Webhook safety:** `io.ReadAll` before HMAC verify, SETNX idempotency
- **Elo rating:** K=32 formula adjusts ratings based on opponent strength
- **Atomic leaderboard:** Redis Lua script for race-condition-free score updates
- **JWT auth:** golang-jwt/v5 with HS256 signing, algorithm validation

## Local Development

```bash
# Run infrastructure
docker-compose up redis rabbitmq mongo

# Seed database
go run ./seed

# Run services (separate terminals)
go run ./services/auth
go run ./services/matchmaking
go run ./services/quiz
go run ./services/scoring
go run ./services/payment
go run ./services/notification

# Run integration tests
go test -tags integration -v -timeout 3m ./test/e2e/
```

## Flutter

```bash
cd flutter
flutter pub get
flutter run                                        # Android emulator (default host: 10.0.2.2)
flutter run --dart-define=BACKEND_HOST=localhost    # Desktop/web
```

### Regenerate proto stubs
```bash
protoc --go_out=. --go-grpc_out=. --go_opt=paths=source_relative --go-grpc_opt=paths=source_relative proto/quiz.proto
protoc --dart_out=grpc:flutter/lib/proto proto/quiz.proto
```
