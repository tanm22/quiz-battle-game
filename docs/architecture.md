# Architecture — Coins & Shop (§4.3)

This document covers the coin-economy slice of Quiz Battle. For the broader
system architecture, see the top-level `README.md`.

## Components

```
                    Flutter (Riverpod + gRPC)
                    ┌─────────────────────────────────┐
                    │ CoinBalanceChip · ShopScreen ·  │
                    │ PurchaseConfirmModal · Equip ·  │
                    │ CoinLedgerScreen                │
                    └─────────────────────────────────┘
                              │ (gRPC :50053)
                              ▼
   ┌──────────────────────────────────────────────────────────────────┐
   │ services/scoring                                                 │
   │   GetCoinBalance      → users.coins                              │
   │   GetCoinLedger       → coin_ledger (paged, newest-first)        │
   │   GetShopCatalog      → shop_items                               │
   │   GetShopInventory    → users.* (cosmetics + reroll + freeze)    │
   │   PurchaseShopItem    → pkg/coins/shop.Purchase.Buy (txn)        │
   │   EquipCosmetic       → users.equippedCosmeticId / NameColor     │
   │   ConsumeReroll       → users.rerollCharges $inc (atomic)        │
   └──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
   ┌──────────────────────────────────────────────────────────────────┐
   │ pkg/coins (shared, server-authoritative)                         │
   │   Ledger.Grant         transactional (debit + ledger row)        │
   │   shop.Purchase.Buy    debit + per-kind effect, atomic           │
   │   shop.Outbox*         deferred cross-service effects            │
   │                                                                  │
   │ EarnEvent pipeline (RabbitMQ topic exchange "sx")                │
   │   coins.earn.match_win                                           │
   │   coins.earn.tournament_placement                                │
   │   coins.earn.referral_referrer / referral_referee                │
   │   coin-earn-queue → handleEarnEvent → Ledger.Grant               │
   └──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
   ┌──────────────────────────────────────────────────────────────────┐
   │ services/payment (premium-trial outbox consumer)                 │
   │   1-second poll on coin_effect_outbox kind="premium_trial"       │
   │   → users.planExpiresAt extension (renewal-aware)                │
   └──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    MongoDB (rs0): users · coin_ledger ·
                                   shop_items · coin_effect_outbox
```

## Server-authoritative invariants

Every coin movement obeys two rules, enforced by the persistence layer:

1. **Transactional ledger** (ADR-0001). `users.coins` and `coin_ledger` are
   written together inside a Mongo transaction. The unique compound index on
   `(userId, refId, reason)` is the idempotency key — concurrent racers and
   message redeliveries collapse onto a single ledger row.

2. **Outbox for cross-service effects** (ADR-0003). When a purchase has a
   side effect that lives in another service (today: premium-trial extension
   in `services/payment`), the effect intent is enqueued in
   `coin_effect_outbox` inside the same transaction as the debit. A 1-second
   poll in the owning service drains the queue and applies the effect.

## Reward calibration

ADR-0002 anchors the economy on **1 match win = 100 coins** and back-computes
the rest of the table. Reward amounts are intentionally hardcoded today; a
future PR can lift them into a config collection if A/B testing becomes
useful.

## Flutter client

The Riverpod providers in `flutter/lib/providers/coins_state.dart` cache:

- `coinBalanceProvider` — current balance, surfaced by `CoinBalanceChip`.
- `shopCatalogProvider` — SKU list.
- `shopInventoryProvider` — owned cosmetics + equipped IDs + reroll charges.

Mutating actions invalidate the relevant providers so the UI re-renders
without a manual refresh:

- `PurchaseConfirmModal` invalidates balance + inventory on success.
- `EquipScreen` tile invalidates inventory on success.
- The ledger screen owns its own paginated state.

## References

- ADR-0001 — Coin ledger uses Mongo transactions on rs0.
- ADR-0002 — Coin reward amounts (initial calibration).
- ADR-0003 — Premium trial extension via transactional outbox.
- `pkg/coins/ledger.go`, `pkg/coins/events.go`, `pkg/coins/shop/`
- `services/scoring/coins.go`, `services/scoring/equip.go`,
  `services/scoring/shop.go`, `services/scoring/earn_consumer.go`
- `services/payment/premium_trial_consumer.go`
