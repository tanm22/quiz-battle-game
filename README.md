# Quiz Battle

A real-time, server-authoritative multiplayer quiz game. Two players are paired by skill rating, answer the same five questions on a synchronized timer, and the faster-correct player wins coins, rating, and a place on the leaderboard. The system also ships premium subscriptions (Razorpay), a referral program, daily streak rewards, push notifications (FCM), tournaments, friend challenges, and a coin economy with shop.

> **New reader, start here.** Skim this file end-to-end, then read [architecture.md](docs/architecture.md) for the "why" behind the design. The other docs answer narrower questions: [api.md](docs/api.md) for RPC/event reference, [runbook.md](docs/runbook.md) when something is broken, [demo-script.md](docs/demo-script.md) when presenting, [CONTRIBUTING.md](./CONTRIBUTING.md) before opening a PR, and the [docs/decisions/](docs/decisions/) ADRs when you need to know *why* a particular decision was made.

---

## Contents

1. [What this is](#what-this-is)
2. [Architecture at a glance](#architecture-at-a-glance)
3. [Tech stack and why](#tech-stack-and-why)
4. [Quick start (Docker)](#quick-start-docker)
5. [Environment variables](#environment-variables)
6. [Verifying it works](#verifying-it-works)
7. [Demo checklist](#demo-checklist)
8. [Running services locally (no Docker)](#running-services-locally-no-docker)
9. [Regenerating proto stubs](#regenerating-proto-stubs)
10. [Repository layout](#repository-layout)
11. [Known limitations](#known-limitations)
12. [Where to go next](#where-to-go-next)

---

## What this is

Quiz Battle is a backend + Flutter app that simulates a "Kahoot-meets-chess-ladder" experience:

- **Real-time matches** — two players, 5 rounds of multiple choice, 15-second timer per round, live leaderboard streamed over gRPC.
- **Skill ladder** — every match updates an Elo rating (the same math chess.com uses) so matchmaking gradually pairs you with players near your level.
- **Economy** — winning matches earns coins; coins buy cosmetics, a streak-freeze, or a 3-day premium trial in the shop.
- **Premium subscription** — Razorpay-backed monthly/yearly plan that unlocks more daily quizzes, all question topics, and tournament entry.
- **Social** — friends list, direct challenges, referral codes with rewards on both sides, and a global leaderboard with daily/weekly/all-time filters.

The codebase is intentionally split into six independent Go services that talk over gRPC and a RabbitMQ event bus. The split lets each piece be scaled, restarted, or replaced without taking the whole game down. See [adr-0001](docs/decisions/0001-microservices-split.md) for why we chose this shape.

> **Jargon glossary.** *gRPC* — a fast, type-safe way for services to talk via small binary messages, kind of like calling functions in another program. *Proto / Protobuf* — the IDL (interface definition language) you write to declare those messages and the RPCs that take them. *RabbitMQ* — a message broker that acts as a post office between services: senders drop letters in, the broker routes them, consumers pick them up. *Redis* — an in-memory key-value store; we use it for live game state and fast counters. *MongoDB* — the durable document database where everything that must survive a restart lives.

---

## Architecture at a glance

```
                              Flutter App (gRPC + Riverpod)
                              ============================
                                          |
        +--------+-----------+----------+------+----------+-----------+
        |        |           |          |      |          |           |
   gRPC:50054 gRPC:50051 gRPC:50052 gRPC:50053 gRPC:50055 HTTP:8080  HTTP:8090
        |        |           |          |      |          |           |
   +----+----+ +-+--------+ +-+------+ +-+----+ +-+-----+ +-+-----+ +-+-----+
   | Auth    | |Matchmking| |  Quiz  | |Scoring | |Payment | |Webhook| | Admin |
   | Service | | Service  | | Engine | |/User   | |Service | | HTTP  | | Dash  |
   +---------+ +----------+ +--------+ +--------+ +--------+ +-------+ +-------+
        \         |             |          |          |
         \        |             |          |          |
          +-------+-------+-----+----+-----+----------+
                  |             |          |
            +-----+----+ +------+--+ +-----+----+      +--------------+
            | MongoDB  | |  Redis  | | RabbitMQ |----->| Notification |
            | (durable)| | (live)  | | (events) |      | Service (FCM)|
            +----------+ +---------+ +----------+      +--------------+
```

**Nine containers in total:** Redis, RabbitMQ, MongoDB (replica set `rs0`), seed (runs once), and the six Go services — auth, matchmaking, quiz, scoring, payment, notification — plus a read-only admin dashboard. Everything is wired in `docker-compose.yml`.

### A match, end-to-end

```
1. Player taps Play in Flutter.
2. Flutter --> Matchmaking.JoinMatchmaking (gRPC).
3. Matchmaking checks daily quota (Redis Lua), adds player to Redis sorted set.
4. Matchmaking poller pairs two nearest-rated players, creates a room.
5. Matchmaking publishes match.created on RabbitMQ (exchange "sx").
6. Quiz Engine consumes match.created, picks 5 questions from Mongo, caches in Redis.
7. Quiz Engine opens a server-streamed gRPC channel to each player.
8. Round 1 starts: Quiz broadcasts QuestionBroadcast with a deadline timestamp.
9. Player taps an option --> Quiz.SubmitAnswer --> publish answer.submitted.
10. Scoring consumes answer.submitted, runs the formula, updates the Redis leaderboard.
11. Scoring publishes leaderboard.updated; Quiz streams it to both clients.
12. Round closes (early if both answered, else at deadline). Repeat for rounds 2-5.
13. Quiz publishes match.finished --> Scoring persists to Mongo, updates Elo + win streak.
14. Quiz publishes coins.earn.match_win for the winner --> Scoring grants 100 coins.
```

Every step is recoverable: rooms have a 30-minute TTL, the leaderboard is a sorted set with atomic Lua updates, and a SETNX guard makes finalization fire exactly once per room.

> Deeper diagrams and the "why each piece exists" discussion are in [architecture.md](docs/architecture.md).

### Services in one line each

| Service | gRPC port | HTTP port | Job |
|---|---|---|---|
| **Auth** | 50054 | — | Sign up, log in (password / Google / passwordless email), JWT, streak, daily reward, refresh-token rotation, notification crons |
| **Matchmaking** | 50051 | — | Player pool (Redis sorted set), pair players, create rooms, daily quota gate |
| **Quiz** | 50052 | — | Round orchestration, gRPC server-stream of game events, timer sync, tournaments |
| **Scoring** | 50053 | — | Scoring formula, leaderboard, match history, Elo updates, coin ledger, shop, friends, analytics |
| **Payment** | 50055 | 8080 | Razorpay orders, webhook, signature verification, plan lifecycle, premium-trial outbox consumer |
| **Notification** | — | — | Pure consumer: turns notification events into FCM pushes; runs the policy gate (quiet hours, dedup, daily cap) |
| **Admin** | — | 8090 | Read-only operator dashboard that queries Mongo + Redis + RabbitMQ |

---

## Tech stack and why

| Layer | Choice | One-line reason |
|---|---|---|
| Backend | Go 1.25 | Single binary per service, cheap goroutines for streaming, fast cold start |
| Client | Flutter / Dart | One codebase for Android, iOS, web; great gRPC support |
| Service-to-client RPC | gRPC + Protobuf | Type-safe contracts, native server streaming for live game events |
| Message bus | RabbitMQ (topic exchange `sx`) | Per-message routing + ack-based delivery; better fit than Kafka for our event shape ([adr-0002](docs/decisions/0002-rabbitmq-over-kafka.md)) |
| Live state | Redis 7 | Sub-ms reads, atomic Lua scripts for quota + leaderboard, TTLs for self-cleaning state ([adr-0003](docs/decisions/0003-redis-live-state.md)) |
| Durable store | MongoDB 6 (single-node `rs0`) | Flexible documents match Go structs; replica set enables multi-doc transactions ([adr-0011](docs/decisions/0011-mongo-replica-set.md)) |
| Payments | Razorpay (test mode by default) | Indian-market gateway with UPI + cards, webhook + client SDK ([adr-0009](docs/decisions/0009-razorpay-dual-path.md)) |
| Push | Firebase Cloud Messaging | Free tier, multi-device tokens, Android + iOS in one API |
| Auth tokens | JWT HS256 + refresh-rotation | Stateless, gRPC-metadata friendly, refresh family revoke on reuse ([adr-0008](docs/decisions/0008-jwt-refresh-rotation.md)) |
| Containerization | Multi-stage Dockerfile + Compose | One image builds all 7 binaries; Alpine runtime stays small |

---

## Quick start (Docker)

This is the only path you need for a demo or first run. It boots all 9 containers and seeds the database.

### 1. Prerequisites

- Docker Desktop (or Docker Engine + Compose plugin)
- ~3 GB free RAM
- Free TCP ports: 6379, 27017, 5672, 15672, 50051-50055, 8080, 8090, 21251-21256

### 2. Clone and configure

```bash
git clone <repo-url>
cd quiz-battle
cp .env.example .env   # if .env.example exists; otherwise create .env yourself
```

At minimum, set `JWT_SECRET` in `.env`. The compose file refuses to start any service without it (deliberate — see [adr-0008](docs/decisions/0008-jwt-refresh-rotation.md)).

```bash
echo "JWT_SECRET=$(openssl rand -hex 32)" >> .env
```

For Razorpay, Google sign-in, email OTP, or FCM, see [Environment variables](#environment-variables) below. None of them are required to boot the stack — the affected features just degrade gracefully (e.g., FCM logs in stub mode).

### 3. Boot the stack

```bash
docker compose up --build
```

The boot sequence is intentional:

1. `redis`, `rabbitmq`, `mongo` come up.
2. The Mongo healthcheck idempotently runs `rs.initiate(...)` so multi-document transactions work.
3. `seed` runs once: creates Mongo indexes, inserts 50+ questions, 6 test users, 2 tournaments, shop SKUs.
4. The six service containers start once `seed` finishes.

Healthy first boot takes 30-60 seconds. If `seed` exits 0 and all six services show "listening on :50051" etc., you're done.

### 4. Test users

The seeder creates these accounts (password `testpass123` for every account):

| Username | Rating | Wins / Played | Notes |
|---|---:|---:|---|
| `alice` | 1400 | 15 / 20 | Solid mid-tier |
| `bob` | 1250 | 8 / 18 | Used in default demo |
| `charlie` | 1100 | 5 / 15 | Lower rated |
| `diana` | 1350 | 12 / 22 | |
| `eve` | 950 | 3 / 12 | Newest |
| `frank` | 1500 | 20 / 25 | Top of the seeded list |

---

## Environment variables

Everything is read once per service at startup via `os.Getenv`. The compose file passes a curated subset to each container.

### Required for boot

| Var | Used by | Purpose |
|---|---|---|
| `JWT_SECRET` | every service | HS256 signing key. Must be identical across services or tokens won't validate. |

### Required for features

| Var | Used by | Purpose |
|---|---|---|
| `GOOGLE_CLIENT_ID` | auth | OAuth 2.0 client ID for the **Sign in with Google** flow. Without it, `GoogleSignIn` returns an error and the button on the login screen is hidden. |
| `RAZORPAY_KEY_ID` | payment | Razorpay public key (`rzp_test_...` for sandbox). |
| `RAZORPAY_KEY_SECRET` | payment | Razorpay secret for server-side order creation + client-callback HMAC verification. |
| `RAZORPAY_WEBHOOK_SECRET` | payment | Webhook HMAC-SHA256 secret. Backstop only — the client-side `VerifyPayment` path also works without it. |
| `RESEND_API_KEY` | auth | Resend.com API key for sending the 6-digit email OTP. Without it, `SendEmailCode` returns an error. |
| `FIREBASE_PROJECT_ID` | notification | Falls back to the value embedded in `secrets/firebase-admin.json` when set there; only needed if the service-account JSON omits `project_id`. |

### Auto-set inside Compose

These resolve to in-network addresses and don't need to be touched for the default Docker setup. Override them if you're running services on bare metal.

| Var | Default | Notes |
|---|---|---|
| `REDIS_ADDR` | `redis:6379` | |
| `RABBITMQ_URL` | `amqp://guest:guest@rabbitmq:5672/` | Change credentials in `docker-compose.yml` if you expose RabbitMQ outside Docker. |
| `MONGO_URI` | `mongodb://mongo:27017/quizbattle?replicaSet=rs0` | The `replicaSet=rs0` suffix is **load-bearing** — it tells the driver to use replica-set semantics, which is what enables transactions. |
| `GOOGLE_APPLICATION_CREDENTIALS` | `/run/secrets/firebase-admin.json` | Path inside the notification container; backed by `./secrets/` via a read-only bind mount. |

### Secrets (file-based)

| Path | Required for | What goes in it |
|---|---|---|
| `secrets/firebase-admin.json` | FCM push delivery | A Firebase service-account JSON downloaded from Firebase Console → Service accounts → Generate key. Without this file the notification service runs in stub mode (logs only, no pushes). |

---

## Verifying it works

After `docker compose up` settles:

```bash
# 1. Containers are healthy
docker compose ps

# 2. Mongo replica set is initialized
docker compose exec mongo mongosh --quiet --eval 'rs.status().myState'  # expect 1

# 3. RabbitMQ exchange + queues exist
open http://localhost:15672                # guest / guest
# expect: exchange "sx" (topic), queues for coin-earn, notif, friends, etc.

# 4. The admin dashboard reports live counts
open http://localhost:8090

# 5. Auth service answers an unauthenticated RPC
grpcurl -plaintext -d '{"username":"alice"}' localhost:50054 quiz.AuthService/CheckUsername
# {"available": false}
```

The `make status` target in the repo bundles many of these checks into one report; see [runbook.md](docs/runbook.md).

---

## Demo checklist

The fastest sanity demo, on a fresh machine. ~5 minutes wall-clock. The full narrative + screenshots live in [demo-script.md](docs/demo-script.md).

- [ ] `docker compose up --build` finishes with all services listening.
- [ ] Open the Flutter app on two emulators (or two physical devices on the same Wi-Fi as the host).
- [ ] Log in as `alice` on one, `bob` on the other (`testpass123`).
- [ ] Both tap **Play** → matchmaking pairs them within ~3 s (poll interval is 1 s).
- [ ] A 5-round game runs to completion; the leaderboard updates live; coins appear on the winner's home screen.
- [ ] Open `http://localhost:8090` and confirm the match shows up in recent activity.
- [ ] Tap **Premium → Upgrade Now** on alice. Pay with Razorpay test card `4111 1111 1111 1111` (any future expiry, any CVV). Plan flips to "premium" within ~2 s.
- [ ] Tap **Shop**, buy a 50-coin avatar frame, equip it on the profile screen.
- [ ] Tap **Daily Reward** the next IST day to demonstrate streak rollover. (Or fast-forward by editing the user's `lastClaimedDate` in Mongo — instructions in [runbook.md](docs/runbook.md).)

---

## Running services locally (no Docker)

You almost never need this — Compose is faster. But if you want to attach a debugger or hot-reload one service, run the infra in Docker and the service on bare metal:

```bash
# Boot only the infrastructure
docker compose up -d redis rabbitmq mongo

# In another terminal, seed once
go run ./seed

# Now run any individual service against the local infra
JWT_SECRET=dev-secret REDIS_ADDR=localhost:6379 \
RABBITMQ_URL=amqp://guest:guest@localhost:5672/ \
MONGO_URI=mongodb://localhost:27017/quizbattle?replicaSet=rs0 \
  go run ./services/auth
```

You can run any subset; just point Flutter at `localhost` (`--dart-define=BACKEND_HOST=localhost`) and the services you didn't start will appear unreachable to the client.

### Flutter

```bash
cd flutter
flutter pub get

# Android emulator (special host alias for the host machine)
flutter run

# Desktop / web / iOS simulator
flutter run --dart-define=BACKEND_HOST=localhost

# A physical Android phone on the same Wi-Fi
flutter run --dart-define=BACKEND_HOST=<your-laptop-LAN-IP>
```

---

## Regenerating proto stubs

The single source of truth is `proto/quiz.proto`. Generated files are committed so a fresh clone works without `protoc`.

```bash
make proto         # regenerates both Go and Dart stubs
make proto-go      # Go only
make proto-dart    # Dart only — requires `dart pub global activate protoc_plugin`
```

If `make proto-dart` fails with "plugin not found", install the Dart plugin: `dart pub global activate protoc_plugin` and make sure `~/.pub-cache/bin` is on your `PATH`.

---

## Repository layout

```
quiz-battle/
  proto/quiz.proto              # The single .proto for every service
  pkg/                          # Shared Go libraries
    auth/                       # JWT middleware (interceptor + token mint)
    coins/                      # Ledger, shop, outbox primitives
    config/                     # Env-var loading helpers
    keys/                       # Redis key names (single source of truth)
    log/                        # Structured slog setup + context propagation
    metrics/                    # Prometheus metric registries
    models/                     # User, Payment, Tournament Go structs
    notif/                      # Notification policy primitives
    ratelimit/                  # Token-bucket limiters
    validate/                   # Field-length + format validators
  services/
    auth/                       # Auth (50054)
    matchmaking/                # Matchmaking (50051)
    quiz/                       # Quiz engine (50052)
    scoring/                    # Scoring / user / coins / shop / friends (50053)
    payment/                    # Razorpay + webhook (50055, 8080)
    notification/               # FCM consumer
    admin/                      # Read-only dashboard (8090)
  seed/
    main.go                     # One-shot index + test data + shop catalog seeder
    questions.json              # Quiz question bank
    shop_items.json             # Shop SKUs
  secrets/                      # firebase-admin.json (gitignored)
  flutter/                      # Flutter client
    lib/
      main.dart                 # App entry, theme, gRPC channel setup
      proto/                    # Generated Dart proto/gRPC stubs
      providers/                # Riverpod state (auth, game, scoring, payment, coins)
      services/                 # Typed gRPC wrappers
      screens/                  # 20+ screens (home, gameplay, login, shop, friends, ...)
      widgets/                  # Shared widgets
      theme/                    # Colors, typography
  scripts/
    coverage.sh                 # Per-function coverage gate (>=70% on key code)
    status.sh                   # `make status` — health probe across services
  docker-compose.yml            # 9-container orchestration
  Dockerfile                    # Multi-stage Go builder + Alpine runtime
  Makefile                      # proto / test / vet / lint / build / status / coverage
  .env                          # Local environment (gitignored)
```

---

## Known limitations

These are deliberate scope cuts. If you're sizing the gap between "demo-ready" and "production-ready," start here.

- **No TLS on gRPC inside the cluster.** Plaintext is acceptable for a single host; production should terminate TLS at a reverse proxy. See `docs/deployment-tls.md` in the repo for a worked example.
- **Single Redis, single Mongo node.** No Sentinel, no shard. Fine for demo scale; not HA.
- **Each service is a single instance.** The matchmaking poller, RabbitMQ consumers, and the premium-trial outbox worker assume a single instance per service. Running two replicas of the payment service today would let both consumers race on outbox rows. See [adr-0007](docs/decisions/0007-premium-trial-outbox.md).
- **AMQP channel does not auto-reconnect.** If RabbitMQ restarts, restart the affected services.
- **Tournaments are minimal.** Listing + joining + a finalization worker that pays out the prize pool. There's no bracket UI or scheduled match-orchestration layer.
- **No general gRPC rate limit.** Per-RPC limits exist where they matter (email OTP send, SubmitAnswer); the rest is unbounded.
- **FCM stub mode when secret missing.** Without `secrets/firebase-admin.json`, the notification service logs deliveries instead of sending them.

A full gap analysis lives in the Downloads folder under `2026-05-12-production-hardening-gaps.md`.

---

## Where to go next

- **Understand the design** — [architecture.md](docs/architecture.md)
- **Call an RPC or subscribe to an event** — [api.md](docs/api.md)
- **Operate the system** — [runbook.md](docs/runbook.md)
- **Demo it** — [demo-script.md](docs/demo-script.md)
- **Open a PR** — [CONTRIBUTING.md](./CONTRIBUTING.md)
- **Argue with a design choice** — read the relevant `docs/decisions/NNNN-*.md` ADR first; it probably anticipated your objection.
