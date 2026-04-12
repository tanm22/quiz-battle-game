# Quiz Battle System

Real-time multiplayer quiz game with Go microservices, RabbitMQ event bus, Redis state, MongoDB persistence, and a Flutter client.

## Architecture

```
Flutter App (gRPC) --> Matchmaking :50051 --[match.created]--> Quiz Engine :50052
                                                                    |
                                                          [answer.submitted]
                                                                    v
                                                             Scoring :50053
                                                                    |
                                                       [leaderboard.updated]
                                                                    v
                                                        Quiz Engine (broadcast)
```

Four independent Go services communicate via RabbitMQ topic exchange (`sx`):

| Service | Port | Responsibilities |
|---------|------|-----------------|
| **Auth** | 50054 | Registration, login, guest mode, email verification, JWT |
| **Matchmaking** | 50051 | Player pool (Redis ZSET), room creation, match notifications |
| **Quiz Engine** | 50052 | Question selection, round orchestration, game event streaming |
| **Scoring** | 50053 | Score calculation (gRPC), leaderboard (Redis Lua), persistence (MongoDB) |

## Quick Start

```bash
docker-compose up --build
```

This starts Redis, RabbitMQ, MongoDB, seeds the database (51 questions, 6 test users), and launches all four services. The seed runs automatically before services start.

**Test users:** alice, bob, charlie, diana, eve, frank (password: `testpass123`, ratings 950-1500)

**RabbitMQ UI:** http://localhost:15672 (guest/guest)

## Local Development

### Prerequisites
- Go 1.24+
- Redis, RabbitMQ, MongoDB running locally (or via `docker-compose up redis rabbitmq mongo`)

### Run services individually
```bash
go run ./services/auth
go run ./services/matchmaking
go run ./services/quiz
go run ./services/scoring
```

### Seed the database
```bash
go run ./seed
```

### Run integration tests
Requires all services + infrastructure running:
```bash
go test -tags integration -v -timeout 3m ./test/e2e/
```

## Flutter App

### Setup
```bash
cd flutter
flutter pub get
```

### Run on Android emulator
```bash
flutter run
```
Default backend host is `10.0.2.2` (Android emulator loopback to host).

### Run on desktop/web (localhost)
```bash
flutter run --dart-define=BACKEND_HOST=localhost
```

### Regenerate proto
```bash
protoc --go_out=. --go-grpc_out=. proto/quiz.proto
protoc --dart_out=grpc:flutter/lib/proto proto/quiz.proto
```

## RabbitMQ Event Flow

| Event | Producer | Consumer | Purpose |
|-------|----------|----------|---------|
| `match.created` | Matchmaking | Quiz Engine | Select questions, start round 1 |
| `answer.submitted` | Quiz Engine | Scoring Worker | Score answer, update leaderboard |
| `leaderboard.updated` | Scoring | Quiz Engine | Broadcast to game streams |
| `round.completed` | Quiz Engine | Quiz Engine | Advance to next round or finish |
| `match.finished` | Quiz Engine | Persistence + Analytics | Write match_history, update stats |

## Key Design Decisions

- **Atomic leaderboard:** Redis Lua script for race-condition-free score updates
- **SETNX round guard:** Prevents double round completion when timer and last answer race
- **Idempotent answers:** HEXISTS check before scoring prevents duplicate scoring on retry
- **Elo rating:** K=32 formula adjusts ratings based on opponent strength
- **gRPC streaming:** Server-streaming for real-time game events with reconnection snapshots
- **JWT auth:** golang-jwt/v5 with HS256 signing, 24h expiry
