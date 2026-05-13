# ADR-0002 — RabbitMQ topic exchange over Kafka

## Status
Accepted — 2026-04-15.

## Context

The system needs an asynchronous, durable message bus between services. Two production-grade options:

- **Apache Kafka** — log-structured, partitioned, optimised for high-throughput ordered streams.
- **RabbitMQ** — broker-based, with rich routing (direct, topic, fanout, headers exchanges), acknowledgements, and a built-in management UI.

Our event shape is small and routed, not big and streamed:

| Property | Quiz Battle | Kafka's sweet spot |
|---|---|---|
| Event volume | Bounded by active matches: hundreds/s at peak | Millions/s |
| Ordering needs | Per-room only, and even there optional | Per-partition strict |
| Consumer count | Single consumer per event type | Many parallel readers |
| Routing | Per-message routing key (e.g., `coins.earn.match_win` to scoring, `notif.streak.warning` to notification) | Topic per stream; consumer-side filtering |
| Replay needs | Rare, manual | Routine, with offsets |
| Operational footprint | We want one container | Zookeeper or KRaft + brokers + clients |

The features we *do* need:

- Acknowledgement-based delivery (consumer NACKs → retry).
- Dead-letter queues for poison messages.
- A pattern like "publish `coins.earn.<source>`, one consumer binds `coins.earn.*`".
- A management UI for "what's in the queue right now?" during incidents.

## Decision

Use **RabbitMQ** with a single durable topic exchange named `sx` and per-consumer named queues.

Operational rules:

1. **One exchange.** Every event goes to `sx`. Producers don't declare exchanges.
2. **Per-consumer queue.** Each consumer declares its own queue and binds a routing-key pattern. A new earn source means publishing a new routing key — no consumer change.
3. **Manual ack on success.** Consumers `ack` only after the work is durably reflected (Mongo insert, ledger row, etc.). Crashes between work and ack are safe because consumers are idempotent (see [adr-0005](./0005-coin-ledger-transactional.md)).
4. **DLQ pattern.** Poison messages (decode error, missing required field) `nack` with `requeue=false` and end up in a `<queue-name>-dlq` for operator inspection.
5. **Transient errors retry.** `nack` with `requeue=true`.
6. **AMQP channels are not goroutine-safe.** Every `publish()` call goes through a per-service `sync.Mutex`-protected helper. Consumers get their own channel.

## Consequences

### Positive
- Adding a new event type is a one-line publish. No consumer reconfiguration.
- The management UI at `:15672` is the single most useful operational tool we have. During incidents you can watch queue depth, see message rates, and inspect payloads.
- DLQs make poison messages a known, debuggable failure mode rather than a silent stall.
- Acknowledgement semantics align with our idempotent-consumer pattern: at-least-once delivery + idempotent application = effectively exactly-once without two-phase commit.

### Negative
- No native replay. If you want to "see all events from yesterday," you can't — RabbitMQ deletes acked messages. We compensate by writing durable side-effects (Mongo) for anything we care about historically.
- No partitioning. If consumer throughput becomes a bottleneck we'll need to fan out to multiple consumer instances with a competing-consumers pattern (each picks up disjoint deliveries from the same queue). Today's volumes don't need it.
- AMQP channels' non-thread-safety is a footgun. The mutex wrapper helps but means an accidental direct `ch.PublishWithContext` is a bug — we rely on code review and consistency.

### Alternatives considered

**A. Kafka.** Stronger for replay, partition-ordered streams, and high throughput. Wrong fit: we don't have those needs and would pay the operational tax.

**B. Redis Streams / Pub-Sub.** Tempting because we already run Redis. Streams are decent but lack the operations toolbox (management UI, DLQ patterns, virtual hosts) and pub-sub has no durability. We use Redis for state, not transit.

**C. NATS JetStream.** Lighter than Kafka, comparable to RabbitMQ. Rejected because the team didn't have prior NATS experience and the gap from RabbitMQ to NATS is small for this workload.

**D. Direct gRPC calls between services.** Couples latency and failure modes; the asynchronous nature of "score this answer" / "grant these coins" maps poorly onto request-response. Rejected.

## References
- `pkg/log/PublishWithContext` — the wrapped publish helper.
- Each service's `consume*` function — declares the queue, binding, and dispatch.
- [api.md](../api.md) "RabbitMQ events" section — full routing-key catalogue.
