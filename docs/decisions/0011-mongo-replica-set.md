# ADR-0011 — MongoDB as a single-node replica set (`rs0`) in dev

## Status
Accepted — 2026-04-25.

## Context

MongoDB multi-document transactions require a replica set. They do not work on a standalone `mongod`. We need transactions because the coin ledger writes two collections (`coin_ledger` and `users`) in one atomic step (see [adr-0005](./0005-coin-ledger-transactional.md)), and the shop's transactional outbox writes three (`coin_ledger`, `users`, `coin_effect_outbox`).

For production we'd run a 3-node replica set. For dev we still need rs0 semantics, but we don't want three Mongo containers. A single-node replica set is the supported configuration: it satisfies the transaction prerequisite, costs no more resources than a standalone, and the code path is identical to production.

The only operational wrinkle is bootstrap: a fresh `mongod --replSet rs0` needs `rs.initiate(...)` once before it accepts writes. Where do you put that bootstrap?

Three options:

- **A. `/docker-entrypoint-initdb.d/init-rs.js`.** Mongo runs scripts here at first start. We tried it. Doesn't work — the entrypoint runs the script before docker-compose has wired the `mongo` DNS alias, so `isSelf` checks fail and the replica set never bootstraps.
- **B. A separate "init" container that waits for Mongo and runs `rs.initiate`.** Works, but adds a container that exists only to fire once and exit.
- **C. Idempotent `rs.initiate` inside the healthcheck.** The healthcheck runs `try { rs.status() } catch { rs.initiate(...) }` on every probe. The first probe initiates; subsequent probes are no-ops because `rs.status()` succeeds.

## Decision

Adopt **option C: idempotent `rs.initiate` in the Mongo healthcheck**.

The `docker-compose.yml` healthcheck for the `mongo` service:

```yaml
healthcheck:
  test:
    - "CMD-SHELL"
    - >-
      mongosh --quiet --eval '
        try { rs.status() } catch (e) {
          rs.initiate({_id:"rs0", members:[{_id:0, host:"mongo:27017"}]});
        }
        db.hello().isWritablePrimary
      ' | tail -n1 | grep -q true
  interval: 5s
  timeout: 10s
  retries: 30
  start_period: 15s
```

The healthcheck:

1. Runs `rs.status()`. If the replica set is already initiated, this succeeds and the catch branch is skipped.
2. If not initiated, runs `rs.initiate(...)` declaring the single-node replica set.
3. Finally checks `db.hello().isWritablePrimary` is `true` — the actual healthiness criterion.

The MONGO_URI in every service URL is suffixed with `?replicaSet=rs0`. This is **load-bearing** — without it, the driver doesn't activate replica-set semantics even though Mongo is running as one, and `WithTransaction` silently becomes a no-op. We learned this the hard way.

All depending services declare `depends_on: { mongo: { condition: service_healthy } }`, so they don't start until the replica set is writable.

## Consequences

### Positive
- One container does the work of standalone-or-RS. No extra init job, no `docker-entrypoint-initdb.d` script.
- Self-heals existing volumes. If you `docker compose up` against an old Mongo volume that pre-dates rs0, the first healthcheck initiates rs0 and the system moves forward.
- Dev and production codepaths are identical — same driver options, same transaction primitives, same retry semantics.

### Negative
- The healthcheck does slightly more work than a pure liveness check (running `rs.status()` every 5 seconds). Marginal cost.
- A volume that was initiated under a *different* replica-set name (e.g., `rs1`) won't auto-heal — you'd see an error and would need to wipe the volume. We've never seen this in practice; the name `rs0` is universal in the codebase.
- The single-node replica set in dev offers no real HA. That's expected and documented in known limitations.

## Alternatives considered

**A. `docker-entrypoint-initdb.d`** — already explained; broken due to DNS-alias timing.

**B. Sidecar init container.** Works; was the first thing we tried. Discarded once we found the healthcheck-with-try-catch pattern, because the sidecar added complexity for no benefit.

**C. Programmatic init in Go (each service tries to initiate on startup).** Six services racing to initiate rs0 is unnecessary. Healthcheck is the natural single owner.

## References
- `docker-compose.yml` — `mongo` service definition.
- `seed/main.go` — uses `coins.DefaultDBName`; doesn't itself initiate rs0.
- `pkg/coins/ledger.go::Grant` — the canonical transactional writer; fails loudly if rs0 isn't initiated.
- MongoDB single-node replica set guide: https://www.mongodb.com/docs/manual/tutorial/convert-standalone-to-replica-set/
