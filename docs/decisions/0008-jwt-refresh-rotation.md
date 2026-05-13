# ADR-0008 — JWT (HS256) access tokens with single-use refresh-token rotation

## Status
Accepted — 2026-04-30.

## Context

The original auth surface issued a single long-lived JWT on login and validated it on every request. That's the simplest possible model and it works — but it has two problems:

1. **No revocation.** A stolen token is valid until it expires. The honest knob is "shorten the expiry," which trades security for UX (users get logged out more often).
2. **No theft detection.** If a token leaks, we have no signal until something visibly bad happens.

The industry-standard mitigation is the **refresh-token rotation** pattern:

- The user gets a short-lived **access token** (~15 minutes here) for normal API calls.
- The user also gets a long-lived **refresh token** stored in secure storage.
- When the access token expires, the client presents the refresh token and gets a new access + new refresh token. The old refresh is revoked.
- If a revoked refresh token is presented (= someone other than the legitimate client is using it), the entire **family** is revoked. Both attacker and legitimate user are logged out, which is the right outcome — the legitimate user re-logs-in, the attacker is locked out.

## Decision

Use **HS256-signed JWTs for the access token** + **single-use refresh tokens with family-based reuse defense** for re-issue.

### Tokens

| Token | Format | Lifetime | Carried where |
|---|---|---|---|
| Access | JWT (HS256) | ~15 minutes (`expires_in` returned alongside) | gRPC metadata `authorization: Bearer <jwt>` |
| Refresh | Opaque (random 256-bit hex), stored server-side | 30 days, rolling on each rotation | Flutter secure storage; sent in `RefreshToken` / `Logout` RPC body |

### Why HS256 (not RS256)?

We don't need asymmetric signing because every validator is also under our control. HS256 is simpler — one secret, no key rotation choreography — and faster. Critically, the JWT library is configured to **reject `alg:none` and any non-HS256 algorithm**; this is the well-known `alg` confusion attack and the validator code calls it out explicitly.

The shared secret `JWT_SECRET` is required at every service's startup (compose enforces `:?`). A missing or mismatched secret fails closed: the service won't boot.

### Refresh-token rotation

- The refresh token is opaque (not a JWT). We don't want JWT validation drift to apply to refresh.
- Each refresh token belongs to a **family** identified by the original login. Rotation issues a new token in the same family.
- Each refresh row has `revokedAt`. Presenting a revoked token → revoke the whole family and return `Unauthenticated`.
- The auth service is the only writer to the refresh store. Other services don't need to know refresh tokens exist.

### Service identity (gRPC interceptor)

`pkg/auth/Interceptor` does three things:

1. Read `authorization` from incoming metadata.
2. Parse + verify the JWT with `JWT_SECRET`. Reject anything not HS256.
3. Stuff `userId` into `context.Context`. Downstream handlers use a helper `auth.UserIDFromContext(ctx)`.

Public RPCs (`Register`, `Login`, `GuestLogin`, `GoogleSignIn`, `SendEmailCode`, `VerifyEmailCode`, `CheckUsername`) bypass the interceptor.

## Consequences

### Positive
- Stolen access tokens are limited to a ~15-minute blast radius.
- Theft of a refresh token is detected as soon as either party tries to rotate — the legitimate client and the attacker race; the loser is logged out across the family.
- HS256 keeps the secret-management story to a single env var. Easy to share via Docker secrets in production.

### Negative
- Client complexity: Flutter must track access vs refresh, retry on `Unauthenticated`, and surface a re-login dialog if refresh fails.
- A misconfigured `JWT_SECRET` (e.g., different in one service) silently invalidates that service's auth. Mitigated by the `:?` requirement in compose.
- Refresh-token rotation requires server-side state; we store rows in Mongo (`refresh_tokens` collection). The rows are small, but they're a write per login + per rotation.

### Alternatives considered

- **Just long-lived JWTs.** Original state. Rejected for the no-revocation problem.
- **Session cookies + CSRF.** Web-friendly but awkward for gRPC and Flutter; we'd lose the auth-in-metadata uniformity.
- **OAuth2 with an external IdP.** Overkill for our user model. Google sign-in is an *input* to our auth service, not a replacement for it.
- **RS256 with a public/private keypair.** Useful when validators are outside our trust boundary (e.g., third-party services validate our tokens). They aren't, so the asymmetric overhead doesn't buy us anything.

## References
- `pkg/auth/jwt.go` — sign + validate.
- `pkg/auth/interceptor.go` — gRPC unary + stream interceptors.
- `services/auth/main.go::RefreshToken`, `Logout`.
- `flutter/lib/services/auth_service.dart` — client-side rotation + retry on 401.
- JWT alg-confusion writeup: https://auth0.com/blog/critical-vulnerabilities-in-json-web-token-libraries/
