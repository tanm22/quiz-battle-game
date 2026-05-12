# Runbook — Coins & Shop

Operational cheatsheet for the §4.3 coin economy. Keep this short — when
something is on fire, scrolling is the enemy.

## Health checklist

```
docker compose ps mongo rabbitmq scoring payment auth
docker compose logs --tail=200 scoring | grep -iE 'earn-consumer|coin'
docker compose logs --tail=200 payment | grep premium-trial
```

Things that should be true on a healthy stack:

- `coin-earn-queue` exists and is bound to `coins.earn.*` on exchange `sx`.
- `coin-earn-dlq` is empty (or close to it). A growing DLQ means a producer
  is publishing malformed payloads — inspect with the RabbitMQ admin UI.
- `services/payment`'s consumer log fires every ~second when there are
  unprocessed outbox rows; otherwise it's silent.

## Seeding the shop catalog

The catalog is reseeded from `seed/shop_items.json` whenever the seed
binary runs (it upserts by `_id`, so re-running is safe):

```sh
docker compose run --rm seed
```

To add a new SKU: edit `seed/shop_items.json`, add the kind to
`pkg/coins/shop/catalog.go`'s `Kind*` constants and the validators if
the shop logic needs special handling, then re-seed.

## Inspecting a user's balance and history

```sh
docker compose exec mongo mongosh quizbattle --quiet --eval '
  const u = db.users.findOne({_id: "USER_ID"}, {coins:1});
  print("balance:", u && u.coins);
  print("recent ledger rows:");
  db.coin_ledger.find({userId:"USER_ID"})
    .sort({createdAt:-1}).limit(20)
    .forEach(r => print(r.createdAt.toISOString(), r.delta, r.reason, r.refId));
'
```

If `users.coins` and the ledger sum disagree, that's a bug — the
ledger-and-balance pair is supposed to commit atomically (ADR-0001).
File an issue with both numbers.

## Stuck premium-trial outbox rows

Outbox rows older than ~5 seconds with `processedAt: null` indicate the
consumer is failing. Check the payment service log first; common causes:

- Mongo unreachable (the entire stack is degraded — fix Mongo).
- User document missing for `userId` (the consumer logs and marks the
  row processed in this case; should be self-healing).
- Bug in `applyPremiumTrialRow` — file an issue.

To see stuck rows:

```sh
docker compose exec mongo mongosh quizbattle --quiet --eval '
  db.coin_effect_outbox.find({processedAt: null}).forEach(printjson)
'
```

Manual fix: do **not** edit the row directly. Instead, replay the consumer
on it by removing `processedAt` (already null) and waiting a second — or
restart the payment service.

## Outbox watcher metrics

The payment service runs a 30s-tick watcher over `coin_effect_outbox`
that publishes two Prometheus gauges per kind:

- `outbox_pending_total{kind="premium_trial"}` — count of rows with
  `processedAt: null`. Healthy steady-state: 0 (consumer drains within
  one 1s poll). A non-zero value lingering across two scrape intervals
  means the consumer is behind or stuck.
- `outbox_oldest_age_seconds{kind="premium_trial"}` — age of the oldest
  unprocessed row, 0 when the queue is empty. This is the primary
  stuck-consumer signal: under normal operation it should stay under
  ~2s; sustained values above tens of seconds mean apply latency is
  growing; values above 5 minutes mean the consumer goroutine is wedged.

When `outbox_oldest_age_seconds` exceeds **300s (5 minutes)** for a
given kind, the watcher emits a structured `outbox stuck` error log with
the kind, pending count, and oldest age. That loud log is the floor;
in production you'd add a Prometheus alert rule like
`outbox_oldest_age_seconds > 600` `for: 5m` and page on it.

## Granting coins manually

Direct `db.coin_ledger.insertOne(...)` is **wrong**. The ledger insert and
the `users.coins $inc` must commit together inside a Mongo transaction or
the two will drift. Use a small admin script that calls `coins.Grant` with
`reason: ReasonAdminAdjustment` and a `refId` of your choice (e.g.,
`admin:<ticket>:<userId>`):

```go
package main

import (
    "context"
    "log"
    "os"

    "go.mongodb.org/mongo-driver/v2/mongo"
    "go.mongodb.org/mongo-driver/v2/mongo/options"

    "quiz-battle/pkg/coins"
)

func main() {
    uri := os.Getenv("MONGO_URI")
    c, err := mongo.Connect(options.Client().ApplyURI(uri))
    if err != nil { log.Fatal(err) }

    l := coins.NewLedger(c, coins.DefaultDBName)
    entry, err := l.Grant(context.Background(), "USER_ID", 500,
        coins.ReasonAdminAdjustment, "admin:ticket-1234:USER_ID",
        map[string]string{"reason": "support credit"})
    if err != nil { log.Fatal(err) }
    log.Printf("granted: %+v", entry)
}
```

The `refId` makes the grant idempotent — re-running the script with the
same `refId` is a no-op.

## On-call quickref

| Symptom | First thing to check |
|---------|----------------------|
| User says "I bought X but didn't get it" | `coin_effect_outbox` for unprocessed rows; payment service log |
| User says "I got charged twice" | Same `idempotency_key` in two ledger rows? Should be impossible — file a bug |
| User says "I didn't get my match-win coins" | Look for the `coins.earn.match_win` event in scoring's earn-consumer log; check `coin-earn-dlq` |
| Stuck `referral-event-queue` | Check `referral-event-dlq` for the poison message; redrive after fixing the producer |

## References

- `pkg/coins/ledger.go::Grant` — the only sanctioned writer of `users.coins`.
- `services/scoring/earn_consumer.go` — `coins.earn.*` dispatch.
- `services/payment/premium_trial_consumer.go` — outbox poll.
- `seed/main.go` — index declarations.
- ADR-0001 / 0002 / 0003.
