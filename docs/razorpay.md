# Razorpay — Payment Integration

End-to-end reference for the premium-subscription flow: order creation,
client-side signature verification, webhook fallback, and the failure /
retry path.

## Plans

Both prices are configured in `services/payment/main.go::CreateOrder`.

| Plan | Amount (paise) | Duration |
|------|---------------:|----------|
| Monthly | 29,900 (₹299) | 30 days |
| Yearly  | 2,99,900 (₹2,999) | 365 days |

## Flow (happy path)

```
Flutter                    Payment Service           MongoDB / Redis / RabbitMQ
  │                              │                          │
  ├─ CreateOrder (gRPC) ────────►│                          │
  │  { plan: "monthly" }         │                          │
  │                              ├─ POST /v1/orders ─►(Razorpay)
  │                              │◄─ { id, amount }         │
  │                              ├─ INSERT payments ───────►│
  │◄─ { order_id, key, amount } ─┤  { status: "created" }   │
  │                              │                          │
  ├─ razorpay.open({order_id})   │                          │
  │  (UPI / card / netbanking)   │                          │
  │                              │                          │
  ├─ EVENT_PAYMENT_SUCCESS ──┐   │                          │
  │  { order_id, payment_id, │   │                          │
  │    signature }           │   │                          │
  │                          │   │                          │
  ├─ VerifyPayment (gRPC) ───┴──►│                          │
  │                              ├─ HMAC verify             │
  │                              ├─ capturePayment ────────►│
  │                              │   • SETNX(idem:paymentId)│
  │                              │   • payments.status=captured
  │                              │   • publish payment.captured ─►(RabbitMQ)
  │◄─ { success, plan, expiresAt}┤                          │
  │                              │                          │
  │                              │  scoring service ◄───────┤
  │                              │  consumes payment.captured
  │                              │  → users.plan = "premium"
  │                              │    users.planExpiresAt = ...
  │                              │                          │
  ├─ GetPlanStatus (poll) ──────►│                          │
  │◄─ { plan: "premium",         │                          │
  │     expires_at: ... }        │                          │
```

## Why both VerifyPayment AND a webhook?

| Path | When it fires | Why we keep it |
|------|---------------|----------------|
| `VerifyPayment` (Flutter → gRPC) | Razorpay SDK success callback in the app | Synchronous, works in dev without ngrok or any public URL |
| `/webhook/razorpay` (Razorpay → HTTP) | Razorpay's server fires post-capture | Backstop — fires even if the app process is killed mid-callback or the network drops between SDK and our backend |

Both go through the same `capturePayment(orderID, paymentID)` helper. The
**SETNX idempotency guard** keyed on `paymentID` collapses races: whoever
gets there first publishes `payment.captured`; the other becomes a
no-op. Razorpay re-deliveries collapse the same way.

## Signature contracts

Two distinct HMAC-SHA256 signatures, with two distinct inputs:

**Client-side (Flutter → VerifyPayment)**
```
sig = HMAC-SHA256(razorpay_key_secret, order_id + "|" + payment_id)
```
Razorpay's SDK fills `sig` into the success callback. Backend
recomputes and `hmac.Equal`s.

**Webhook (Razorpay → /webhook/razorpay)**
```
sig = HMAC-SHA256(razorpay_webhook_secret, raw_request_body)
```
Verified before parsing the JSON, so a tampered payload can't sneak
past the structural parse.

## Endpoints

| Type | Path / RPC | Auth | Purpose |
|------|------------|------|---------|
| gRPC | `PaymentService.CreateOrder` | JWT | Create Razorpay order, save pending row |
| gRPC | `PaymentService.VerifyPayment` | JWT | HMAC verify + activate premium synchronously |
| gRPC | `PaymentService.GetPlanStatus` | JWT | Read current plan + expiry from MongoDB |
| gRPC | `PaymentService.GetPaymentHistory` | JWT | Last 20 payments |
| HTTP | `POST /webhook/razorpay` | Webhook secret | Backstop capture path (no JWT) |

## Required env vars

Set these on the `payment` service. Local dev: drop into a `.env` next
to `docker-compose.yml`.

```
RAZORPAY_KEY_ID=rzp_test_...
RAZORPAY_KEY_SECRET=...
RAZORPAY_WEBHOOK_SECRET=...     # optional; webhook is a backstop
JWT_SECRET=<same value as auth + scoring services>
MONGO_URI=mongodb://mongo:27017/quizbattle?replicaSet=rs0
RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672/
REDIS_ADDR=redis:6379
```

**Never commit production keys.** `.env` is gitignored; CI uses test keys
via repo secrets if added.

## Flutter side — Razorpay options

`flutter/lib/screens/payment_screen.dart::_openCheckout` passes the
following to `razorpay.open()`:

- `key`, `amount`, `order_id`, `currency`, `name`, `description` — standard.
- `theme.color` — `#6D59C4` (the app's accent purple).
- `config.display.blocks` + `sequence` — UPI block first, then default
  blocks (card, netbanking, wallets). Pushes UPI to the top of the
  picker which matches actual usage in the target market.

## Failure handling

`_handlePaymentError` differentiates by Razorpay error code:

- **Code 0** — user actively cancelled. Silently dismiss; no dialog.
- **Other codes** — show an `AlertDialog` with the message + code + a
  **Try again** button. Try-again calls `_openCheckout(_lastOrder)`
  which reuses the **same** Razorpay order, so no duplicate `payments`
  row is created and no second debit attempt fires until the user
  retries the actual payment.

## Verification mismatch

If `VerifyPayment` returns a `PermissionDenied` for an "invalid payment
signature", that's either:
- A real tampering attempt (rare; rejected), or
- Your `RAZORPAY_KEY_SECRET` env var doesn't match the key the order
  was created under (most common — happens after rotating test keys).

The webhook path will continue to fire and eventually capture the
payment, so the user's plan still upgrades — just with a delay.

## Premium-trial vs paid premium

Two paths can grant premium; they don't fight:

| Source | Field on user | Duration | How activated |
|--------|---------------|----------|---------------|
| Razorpay payment | `plan = "premium"`, `planExpiresAt` | 30 / 365 days | `VerifyPayment` (or webhook) → scoring consumer |
| Shop premium-trial SKU | same `plan = "premium"`, same `planExpiresAt` extended | +3 days per purchase | `services/payment/premium_trial_consumer.go` (renewal-aware extension, ADR-0003) |

Both write the same `users.planExpiresAt`. The trial consumer extends
from the existing expiry if it's in the future, so a paid subscriber
who later buys a trial keeps their paid time AND gets the trial days
appended.

## Testing

Razorpay test credentials (use these in `RAZORPAY_KEY_ID` / `_SECRET`).

| Method | Value | Result |
|--------|-------|--------|
| Card | `4111 1111 1111 1111` (any future expiry, any CVV) | Success |
| Card | `4000 0000 0000 0002` | Failure — exercises the Try-again dialog |
| UPI  | `success@razorpay` | Success (no real bank account needed) |
| UPI  | `failure@razorpay` | Failure — exercises the Try-again dialog |

End-to-end smoke test:
1. `docker compose up -d --build` — boots all services.
2. Open the app, log in, hit Premium → Upgrade Now.
3. Pay with `success@razorpay` (UPI) or `4111…` (card) and "any/123/000".
4. Watch the payment service log — expect `[payment] captured: payment=...`.
5. Plan flips to "premium" within 1–2s of `VerifyPayment` resolving.

## References

- `proto/quiz.proto` — `PaymentService` RPCs and message shapes.
- `services/payment/main.go` — `CreateOrder`, `VerifyPayment`,
  `handleWebhook`, `capturePayment`.
- `flutter/lib/screens/payment_screen.dart` — UI + Razorpay SDK wiring.
- `flutter/android/app/src/main/AndroidManifest.xml` — Razorpay
  `CheckoutActivity` declaration (required, otherwise the SDK throws
  `ActivityNotFoundException` on Android).
- ADR-0003 — premium-trial outbox flow (related, separate path).
