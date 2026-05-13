# ADR-0009 — Razorpay dual-path capture (client SDK + webhook backstop)

## Status
Accepted — 2026-04-22.

## Context

Razorpay's standard upgrade flow:

1. Backend creates an order (`POST /v1/orders`) and returns an `order_id` to the client.
2. Client opens the Razorpay SDK with the order ID; user pays via UPI / card / netbanking.
3. SDK invokes a success callback with `(payment_id, order_id, signature)`.
4. Backend verifies the signature and marks the payment captured.

The signature in step 4 is HMAC-SHA256 of `order_id + "|" + payment_id` with the API secret. If we trust only this client-side path, two failure modes can drop the upgrade:

- **App crash between SDK success and our backend call.** Payment is captured at Razorpay, but our backend never knows.
- **Network failure on the success-callback round trip.** Same outcome.

The Razorpay-recommended belt-and-braces is to **also** subscribe to a webhook on `payment.captured` and `payment.failed`. Razorpay re-delivers the webhook with backoff if our endpoint fails or 5xx's, so the eventual-capture window is bounded.

But two delivery paths mean two writers and two race conditions:

- Both paths arrive within milliseconds (network is fast) → who wins?
- The user's plan is upgraded twice → double `planExpiresAt` extension.
- A duplicate `payment.captured` event is published → scoring consumes it twice.

## Decision

Implement **both** paths and converge them on a single `capturePayment(orderID, paymentID)` helper guarded by a **SETNX idempotency key**:

```
key:   webhook:idempotency:<paymentId>
TTL:   72 hours
```

`capturePayment` does:

1. `SETNX(key, "captured", EX 72h)`. If the key already exists, return early — someone else got there first.
2. Update `payments.status = "captured"`.
3. Set `users.plan = "premium"`, `users.planExpiresAt = now + duration`, `$unset premiumExpiryWarned`.
4. Invalidate the `user:{id}:plan` Redis cache (DEL).
5. Publish `payment.captured` to RabbitMQ.

### Path 1 — Client-side `VerifyPayment` gRPC

Flutter calls `PaymentService.VerifyPayment` with the three values from the SDK callback. The handler recomputes HMAC and `hmac.Equal`s before invoking `capturePayment`. Returns `{success, plan, expires_at}` synchronously. Works in dev without ngrok.

### Path 2 — Webhook HTTP POST

`POST /webhook/razorpay` on `:8080`:

1. Read **the full request body** with `io.ReadAll` first. (Streaming the body into a JSON decoder defeats HMAC verification because the body bytes are no longer available.)
2. Compute HMAC-SHA256 of the body with `RAZORPAY_WEBHOOK_SECRET`.
3. `hmac.Equal` against `X-Razorpay-Signature`.
4. Parse the JSON payload.
5. Call `capturePayment`.
6. Always return `200 OK` after the SETNX guard, even on duplicate. Razorpay's retry semantics treat `5xx` as "retry"; an honest "I already processed this" is `200`.

### HTTP client timeout

The Razorpay-side `capturePayment` (which calls `POST /v1/payments/{id}/capture` on Razorpay) uses an `http.Client` with a 10-second timeout. The default `http.Client` has none, and a hung Razorpay call would block a payment goroutine indefinitely.

## Consequences

### Positive
- Dev experience: `VerifyPayment` works without exposing a public webhook URL (no ngrok / cloudflared).
- Production resilience: the webhook backstops the client-side path. If the SDK callback drops, the user still upgrades (with up to a few seconds of delay).
- Single capture pipeline: both paths converge on one helper, so logic drift between the paths is impossible by construction.
- The 72-hour SETNX TTL accommodates Razorpay's retry window (~24 h) with generous headroom.

### Negative
- Two code paths to maintain. Worth it; the alternative is choosing one path and accepting its failure mode.
- The `VerifyPayment` RPC is authenticated by JWT, but the webhook is authenticated by HMAC over the body. Different signature schemes — but both prove the request was originated by Razorpay (or, in the gRPC case, by the rightful user holding their token).
- The user's plan cache in scoring is invalidated by `DEL user:{id}:plan` on the writer side. A reader who reads between `payments.status` flip and the DEL would see stale state. Window is sub-millisecond and we accept it.

## Alternatives considered

**A. Only client-side `VerifyPayment`.** Simple; loses the backstop. Bad UX on app crash mid-callback.

**B. Only webhook.** Requires a public URL for dev (ngrok). Worse for demos and local testing.

**C. Database-level idempotency on `payments.razorpayPaymentId`.** Works, but two writers can still race before the unique-key catches it, and you'd need to special-case the duplicate-key error. Redis SETNX is cleaner — fail-fast at the start instead of fail-late at the database.

**D. Compensating transactions if both paths capture twice.** A reconciliation worker that rolls back over-captures. Way more code than a SETNX guard.

## References
- `services/payment/main.go::CreateOrder`, `VerifyPayment`, `handleWebhook`, `capturePayment`.
- `services/payment/webhook_handler_test.go`, `webhook_signature_test.go`.
- `flutter/lib/screens/payment_screen.dart::_openCheckout`, `_handlePaymentSuccess`.
- `flutter/android/app/src/main/AndroidManifest.xml` — Razorpay `CheckoutActivity` declaration (required on Android).
- Razorpay docs on webhook signature verification: https://razorpay.com/docs/webhooks/validate-test/
