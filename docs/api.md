# API — Coins & Shop RPCs and Events

Reference for every gRPC RPC and RabbitMQ routing key introduced by §4.3.
All RPCs are auth-gated unless noted; the JWT travels in the
`authorization: Bearer …` metadata header.

## Service: `quiz.ScoringService` (gRPC :50053)

### `GetCoinBalance`

Single-document read of `users.coins`. The cache is kept consistent with
`coin_ledger` by every `Grant`'s transaction (ADR-0001).

| Field | Type | Direction | Notes |
|-------|------|-----------|-------|
| `balance` | `int64` | response | Current cached balance |

Errors: `Unauthenticated`, `NotFound` (user record missing), `Internal`.

### `GetCoinLedger`

Lifetime ledger entries newest-first, paged by an opaque cursor.

Request:
- `page_size` (`int32`) — `<=0` defaults to 25; clamped to a max of 100.
- `page_token` (`string`) — empty for first page; opaque otherwise.

Response:
- `entries` (`repeated CoinLedgerEntry`)
- `next_page_token` (`string`) — empty when there are no more pages.

`CoinLedgerEntry` fields: `id`, `delta`, `reason`, `ref_id`, `balance_after`,
`created_at_unix_ms`, `metadata`.

### `GetShopCatalog` / `GetShopInventory`

Catalog returns every `ShopItem` (active + inactive — UI hides inactive).
Inventory returns owned cosmetics, equipped IDs, reroll charges, streak
freeze flag, and balance.

`ShopItem.kind` is one of: `cosmetic.avatar_frame`, `cosmetic.name_color`,
`streak_freeze`, `premium_trial`, `reroll_topic`. SKUs are seeded from
`seed/shop_items.json`.

### `PurchaseShopItem`

Hybrid error model: gRPC-level errors (`Unauthenticated`, `InvalidArgument`)
come back as gRPC status; business errors come back on a successful response
with `success=false` and `error_code` set.

Request: `item_id`, `idempotency_key` (UUID generated client-side once per
user-initiated purchase action — the server keys its replay fast-path on
this key).

Response: `success`, `ledger_entry_id`, `new_balance`, `error_code`.

Domain `error_code` values:
- `INSUFFICIENT` — balance < `priceCoins`.
- `INACTIVE` — `shop_items.active == false`.
- `WEEKLY_CAP` — only `streak_freeze.weekly`; one per ISO week.
- `UNKNOWN` — `item_id` not in catalog.

### `EquipCosmetic`

Activate an owned avatar frame or name color. The
`(_id + ownedCosmetics)` filter on `UpdateOne` is the authorisation
guard — it succeeds only when the user owns the item.

Request: `item_id`. Response: `success`, `error_code`.

Domain `error_code` values:
- `UNKNOWN` — `item_id` not in catalog.
- `NOT_OWNED` — user doesn't own the item.
- `NOT_EQUIPPABLE` — item is not a cosmetic kind.

### `ConsumeReroll`

Atomically decrement `rerollCharges`. `roomId`/`roundId` are accepted but
not yet persisted (forward-compat for an audit trail).

Response: `success`, `charges_remaining`, `error_code` (`NO_CHARGES` when
the user is out).

## RabbitMQ topology (exchange `sx`)

### Earn pipeline

Every earn-source publishes `coins.earn.<source>` to the topic exchange
`sx`. The single `coin-earn-queue` (declared by `services/scoring`) binds
the `coins.earn.*` pattern, and `handleEarnEvent` dispatches each delivery
to `pkg/coins.Ledger.Grant`.

| Routing key | Source | RefID convention |
|-------------|--------|------------------|
| `coins.earn.match_win` | `services/quiz.finishMatch` | `match:<roomId>:user:<userId>` |
| `coins.earn.tournament_placement` | tournament finalisation | `tournament:<tournamentId>:user:<userId>` |
| `coins.earn.referral_referrer` | referral handler | `referral:<referralId>:referrer` |
| `coins.earn.referral_referee` | referral handler | `referral:<referralId>:referee` |

Bad payloads (decode error, missing field, non-positive amount) `Nack` to
`coin-earn-dlq`. Transient errors `Nack` with `requeue=true` and retry on
the next delivery.

### Premium-trial outbox

Purchase of `premium.trial.3d` enqueues a `coin_effect_outbox` row with
`kind="premium_trial"` inside the same Mongo transaction as the debit.
The 1-second consumer in `services/payment` drains rows and extends
`users.planExpiresAt`. See ADR-0003.

## Flutter integration

`flutter/lib/services/coins_service.dart` is the typed wrapper. Every RPC
flows through it; tests substitute a fake by overriding
`coinsServiceProvider`.

Riverpod providers in `flutter/lib/providers/coins_state.dart`:

| Provider | Backing call | Invalidated by |
|----------|--------------|----------------|
| `coinBalanceProvider` | `GetCoinBalance` | `PurchaseConfirmModal` on success |
| `shopCatalogProvider` | `GetShopCatalog` | shop screen Retry button |
| `shopInventoryProvider` | `GetShopInventory` | `PurchaseConfirmModal`, `EquipScreen` on success |
