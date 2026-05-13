# ADR-0001 — Split the backend into six services (plus admin)

## Status
Accepted — 2026-04-15.

## Context

A single-binary monolith would be the cheapest thing to ship for a quiz game with low concurrency. We chose to split anyway. The case for splitting:

- **Different failure profiles per concern.** A bug in the payment webhook handler should not take down active matches. A goroutine leak in the gRPC streaming code shouldn't kill auth. Separate processes give us blast-radius isolation for free.
- **Different concurrency profiles.** The matchmaking poller is a single-threaded loop. The quiz engine holds thousands of long-lived streaming goroutines. The auth service is dominated by short, request-response RPCs. Co-locating these in one process means tuning is a single-knob compromise.
- **Different rate-of-change.** The auth and payment surfaces are slow-moving and security-sensitive; quiz and scoring evolve every PR as we add features. Separate deployables mean a careful release of payment doesn't have to coordinate with a feature-rich release of scoring.
- **It's also a forcing function.** Drawing service lines makes us explicit about what state belongs to whom. The "who owns this Mongo collection?" question has a one-name answer.

The case against:

- More moving parts. Six binaries, six deploys, six log streams.
- More boilerplate per service (gRPC setup, AMQP wiring, metrics server).
- Cross-service interactions push you toward eventual consistency; you must accept it.

## Decision

Split into six Go services plus a read-only admin binary. The line is drawn around state ownership:

| Service | Owns |
|---|---|
| auth | identity + refresh-token store, streak / reward bookkeeping |
| matchmaking | matchmaking pool, room creation handshake |
| quiz | round orchestration, gRPC streaming, question selection, tournaments |
| scoring | match persistence, leaderboards, coins/shop/ledger, friends, analytics, FCM token registry |
| payment | plan lifecycle, Razorpay integration, webhook |
| notification | FCM dispatch + policy gate |
| admin | read-only operator dashboard |

Cross-service interactions go through RabbitMQ (events) or shared databases — *never* via synchronous service-to-service gRPC. The one near-exception is the JWT, which every service validates locally using the shared secret; that's not an RPC, it's a stateless library call.

## Consequences

### Positive
- Restart-safe deploys per service. The Flutter app survives a payment-service restart with no visible interruption (orders fail fast on retry; in-flight matches are unaffected).
- Easy to reason about. "Who writes `users.plan`?" — payment. "Who writes `users.coins`?" — scoring (through `Ledger.Grant`). One name each.
- Background workers don't leak into the wrong process: the premium-trial outbox consumer is in payment because payment is the only writer of `planExpiresAt`.

### Negative
- Boilerplate in each `main.go` (Mongo connect, Redis connect, AMQP connect, gRPC + metrics serving). We accept the duplication — extracting it to a framework would obscure the per-service startup story for new readers. The shared bits (logging, validation, key names) live in `pkg/`.
- Eventual consistency between services. A payment captures in payment service, but the user's `plan` cache in scoring is stale for up to 5 minutes — we mitigate via write-invalidation, but acknowledge the window.

### Alternatives considered

**A. Single monolith with goroutine-isolated subsystems.** Simpler ops; lose the blast-radius story. Rejected.

**B. Two services: edge (gRPC) + worker (consumers).** A common pattern, but it merges quiz and matchmaking into one process where they have very different concurrency profiles. Rejected.

**C. Per-feature microservices (8+).** Coins + Shop as its own service, Tournaments as its own, etc. Pure overhead — these features share state liberally with scoring. Rejected.

## References
- `services/*/main.go` — entry points.
- `docker-compose.yml` — the deployment topology.
- [adr-0002](./0002-rabbitmq-over-kafka.md) for how services actually talk.
