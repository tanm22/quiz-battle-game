# Demo script

A 10-15 minute live walkthrough that covers every system the platform offers: real-time gameplay, premium subscriptions, the coin economy, push notifications, friends, and admin observability. Designed to be run on a single laptop with two Android emulators, or one emulator + a physical phone.

## Goals

- Show that the backend is server-authoritative (the client never decides outcomes).
- Show that the backend is event-driven (operations cross service boundaries cleanly).
- Show that money paths (Razorpay) and idempotent paths (coins, plan) are correct under retries.
- Make every system observable to the audience — no "trust me, it worked" moments.

## Setup checklist (do this 5 minutes before the demo starts)

- [ ] Laptop has Docker Desktop running.
- [ ] `.env` exists at the repo root with:
  - `JWT_SECRET=...` (generated)
  - `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` (test keys)
  - `GOOGLE_CLIENT_ID` (if showing Google sign-in)
  - `RESEND_API_KEY` (if showing email OTP)
- [ ] `secrets/firebase-admin.json` is in place if you want to show real FCM pushes. If absent, you'll show stub-mode logs instead.
- [ ] `docker compose up --build -d` was run at least 2 minutes ago; all containers are healthy.
- [ ] Two Android emulators are booted, or one emulator + a phone on the same Wi-Fi as the host.
- [ ] On both clients, the Flutter app is installed and running. App is logged out.
- [ ] Browser tabs open and ready to switch to:
  - `http://localhost:8090` (admin dashboard)
  - `http://localhost:15672` (RabbitMQ management UI — `guest`/`guest`)
  - (optional) `http://localhost:21253/metrics` (scoring Prometheus metrics) — only if the audience wants to see raw counters
- [ ] Terminal window with `docker compose logs -f scoring payment quiz notification` ready to scroll.

If anything in the checklist is red, do a `docker compose down -v && docker compose up --build` and burn the 60 seconds before the audience arrives.

---

## Demo timeline (about 12 minutes)

### Act 1 — Boot and orient (1 min)

1. Open the admin dashboard at `http://localhost:8090`.
2. Talking points:
   - "Nine containers in a single Docker Compose: six Go services, plus Redis, RabbitMQ, MongoDB. The dashboard you're looking at is itself the seventh service — `admin` — read-only by design."
   - "Six test users seeded: alice, bob, charlie, diana, eve, frank. Password is `testpass123`. Two sample tournaments. Shop catalog seeded."

3. Show the dashboard's main panels: active rooms, RabbitMQ queue depth, recent matches, plan distribution.

### Act 2 — Live 1v1 match (3 min)

1. On Emulator 1: log in as `alice`. On Emulator 2: log in as `bob`.
2. Both tap **Play**. Within ~3 seconds (the matchmaking poller's 1-second tick + RabbitMQ + question selection round-trip), both see a game start.
3. Narrate the data flow as it happens:
   - "Matchmaking adds them to a Redis sorted set keyed by Elo rating."
   - "Once two near-rated players are in the pool, the matchmaking poller pairs them, creates a room, and publishes `match.created` on RabbitMQ."
   - "The quiz service consumes it, samples 5 weighted-random questions from MongoDB, caches them in Redis, and opens server-streaming gRPC channels to each player."
4. Switch to the RabbitMQ admin tab. Show the queues for `coin-earn-queue`, `friend-event-queue`, and so on — point out that they exist *because consumers declared them*, not because anyone configured them in advance.
5. Play the 5 rounds. Have one player tap fast, the other tap slowly, to show the speed multiplier in action.
6. At match end, the winner's home screen shows +100 coins; the loser's shows the rating change.

**If something hiccups:** the most common demo failure is a slow emulator. The 15-second round timer protects you — even a wedged client just times out the round and the match continues.

### Act 3 — Coin ledger and shop (2 min)

1. On the winner's phone: tap their profile → **Coin History**.
2. Talking points:
   - "Every coin movement is in `coin_ledger`. The unique compound index on `(userId, refId, reason)` is the idempotency key — match retries can't double-grant. See ADR-0005."
   - "Reading the cached balance from `users.coins` is fast; the audit trail is queryable."
3. Tap **Shop**. Show the catalog (avatar frames, name colors, streak freeze, premium trial, reroll topic).
4. Buy an avatar frame. Point out the balance update happens in-place because Riverpod invalidates `coinBalanceProvider` and `shopInventoryProvider` on success.
5. Equip the frame on the profile screen — instant visual feedback.

### Act 4 — Premium upgrade via Razorpay (3 min)

1. On the loser's phone (so the audience sees the upgrade story on a "free" user): tap **Premium** → **Upgrade Now**.
2. The Razorpay sheet opens. Pay with the test card `4111 1111 1111 1111` (any future expiry, any CVV).
3. After Razorpay's success callback:
   - Flutter calls `PaymentService.VerifyPayment` over gRPC.
   - Backend recomputes HMAC, captures the payment (idempotent SETNX), upgrades the user's plan, invalidates the Redis plan cache, publishes `payment.captured`.
   - The home screen flips to "Premium" within ~2 seconds.
4. Talking points:
   - "Razorpay re-sends a webhook as a backstop. Whichever path reaches the SETNX guard first wins; the other is a no-op. See ADR-0009."
   - "If you wanted, we could buy a 3-day trial from the shop instead. That uses a transactional outbox to coordinate two services without coupling them. See ADR-0007."

5. Toggle terminal to show `docker compose logs payment` — the `[payment] captured` log line is visible.

### Act 5 — Notifications (1 min)

1. On the home screen of either user, tap a notification preference toggle (e.g., disable "Tournament reminders"). Show that the per-user opt-out is persisted server-side via `UpdateNotificationPrefs`.
2. Trigger a streak warning manually (run from the terminal):

   ```bash
   docker compose exec rabbitmq rabbitmqadmin publish \
     exchange=sx routing_key=notif.streak.warning \
     payload='{"userId":"<aliceUserId>","currentStreak":2,"event":"notif.streak.warning"}'
   ```
3. Talking points:
   - "Every push passes through a server-side policy gate: per-user opt-out, then quiet hours (23:00-08:00 in the user's timezone), then daily cap (5/day), then per-category dedup. Drops are counted with their reason in Redis so we can audit later. See ADR-0010."
   - "If `secrets/firebase-admin.json` is configured, this turns into a real FCM push. Without it, the notification service logs the dispatch and we're good for a demo."
4. Show `docker compose logs notification | grep streak.warning` — either `dispatched` or `dropped reason=quiet_hours`, depending on the time of day.

### Act 6 — Friends and challenges (1 min, optional)

1. On alice's phone: **Friends** → search bob's username → send request.
2. On bob's phone: pending request appears → accept.
3. alice taps the friend → **Challenge**.
4. A 1v1 room opens; both phones jump straight into a private match. Same gameplay code path as matchmaking, but the room is created directly (no daily quota debit).

### Act 7 — Admin dashboard recap (1 min)

1. Back to `http://localhost:8090`.
2. Talking points:
   - The completed match is in recent activity.
   - The plan distribution shows one more "premium" user than at the start.
   - Recent payments shows the new entry.
3. "Everything you saw is also in MongoDB, queryable in `mongosh` directly. The dashboard is just one read view; the production rollout would scrape Prometheus + alert on the gauges every service exposes on `:2112/metrics`."

### Act 8 — Q&A bait (1 min)

Have these ready:

- "What happens if the player closes the app mid-match?" — Their stream errors. The room stays alive until the round timeout. If both drop, the last drop triggers `finishMatch`, guarded by SETNX so it fires exactly once.
- "What if the Razorpay webhook arrives twice?" — Redis SETNX on `webhook:idempotency:<paymentId>` collapses the second arrival to a no-op.
- "What if a player taps Buy twice?" — Client sends a UUID `idempotency_key`. On the server side, the coin ledger's `(userId, refId, reason)` unique index rejects the duplicate; the first row is returned to the client.
- "How does the daily quota work?" — Redis Lua script reads counter, compares to limit, increments, and `EXPIREAT`s next IST midnight. All four operations atomic.
- "How would you horizontal-scale this?" — Auth and payment are stateless and trivial to scale. Quiz and matchmaking need extra work (sticky routing or Redis-pubsub fan-out for streams; leader election for the matchmaking pair-poller). Listed under "Scaling envelope" in architecture.md.

---

## Recording a screencast

If you want a take-home version of the demo, record with `ffmpeg`:

```bash
# Screen capture (macOS):
ffmpeg -f avfoundation -i "1" -framerate 30 -c:v libx264 -pix_fmt yuv420p demo.mp4

# Android emulator capture (alternative):
adb -s emulator-5554 shell screenrecord /sdcard/demo.mp4 --time-limit 180
adb -s emulator-5554 pull /sdcard/demo.mp4 emulator1.mp4
```

Split your screen between the two emulators and the admin dashboard. Narrate over the recording in post if needed.

> **Replace this with a hosted recording.** If you publish a definitive recording, swap this section for a link.

---

## Demo failure recovery

| If this fails | Do this |
|---|---|
| Both emulators stuck on matchmaking | RabbitMQ might be down; `docker compose ps rabbitmq` and restart. |
| Match starts but rounds never advance | Check `docker compose logs quiz` for "round closed" lines. If absent, the round-close timer is wedged — restart quiz. |
| Razorpay flow won't open | Check Android emulator has Google Play services up to date. The Razorpay SDK depends on Play. |
| Payment succeeds but plan doesn't flip | The fast path (`VerifyPayment`) may have failed silently. Wait 5 s for the webhook backstop, or check `docker compose logs payment`. |
| Coins don't update on home | Force-refresh: pull down on the home screen, or kill and reopen the app. Riverpod cache is per-app-instance. |
| Admin dashboard shows nothing | The dashboard reads RabbitMQ admin API; check the `RABBITMQ_USER` / `_PASSWORD` env vars on the admin container. |
| A test card declines | You used the failure-case card. Switch to `4111 1111 1111 1111`. |

If everything goes sideways: `docker compose down -v && docker compose up --build`, smile, and pivot to a 2-minute live read of the codebase ("here's how a match starts: matchmaking publishes, quiz consumes, …"). The architecture diagrams in `architecture.md` and the API tables in `api.md` are useful as a backup talking surface.
