# Deployment: TLS Termination

## Current state

All inter-service gRPC traffic uses plaintext TCP. The Razorpay webhook
HTTP endpoint on `services/payment` listens on `:8080` over HTTP. This
is acceptable for local docker-compose development but **not for any
deployment reachable from the public internet**.

## Deployment expectation

Run a TLS-terminating reverse proxy (nginx, Caddy, Envoy, or your
cloud provider's managed load balancer) in front of:

1. **Public client traffic** — Flutter clients connecting to the gRPC
   services. Terminate TLS at the proxy and forward plaintext gRPC to
   the upstreams over a trusted private network. HTTP/2 must be used
   between the proxy and the upstream — gRPC requires it.

2. **Razorpay webhook** — terminate at `https://<your-domain>/payment/webhook`
   and forward to `payment:8080`. Razorpay refuses to deliver webhooks
   to plain HTTP endpoints in production, and the request body is
   HMAC-verified against `RAZORPAY_WEBHOOK_SECRET` regardless.

## Minimum nginx snippet

```nginx
upstream auth_grpc        { server auth:50054; }
upstream matchmaking_grpc { server matchmaking:50051; }
upstream quiz_grpc        { server quiz:50052; }
upstream scoring_grpc     { server scoring:50053; }
upstream payment_grpc     { server payment:50055; }
upstream payment_http     { server payment:8080; }

server {
    listen 443 ssl http2;
    server_name api.example.com;
    ssl_certificate     /etc/ssl/certs/api.example.com.crt;
    ssl_certificate_key /etc/ssl/private/api.example.com.key;

    # gRPC service routing — protobuf-package-qualified method paths.
    location /quiz.AuthService/         { grpc_pass grpc://auth_grpc; }
    location /quiz.MatchmakingService/  { grpc_pass grpc://matchmaking_grpc; }
    location /quiz.QuizService/         { grpc_pass grpc://quiz_grpc; }
    location /quiz.ScoringService/      { grpc_pass grpc://scoring_grpc; }
    location /quiz.PaymentService/      { grpc_pass grpc://payment_grpc; }

    # Razorpay webhook — HTTP/1.1 to the upstream is fine.
    location /payment/webhook {
        proxy_pass http://payment_http/webhook;
        proxy_pass_request_headers on;
        # Razorpay publishes its outbound IP range; an allowlist here
        # is defense in depth on top of the HMAC body verification
        # services/payment/main.go already enforces.
        # allow 52.66.0.0/16; allow 13.232.0.0/14; deny all;
    }
}
```

## Caddy alternative (one-liner ACME)

Caddy's ACME integration auto-provisions and renews Let's Encrypt
certs without an external certbot:

```caddyfile
api.example.com {
    @auth        path /quiz.AuthService/*
    @matchmaking path /quiz.MatchmakingService/*
    @quiz        path /quiz.QuizService/*
    @scoring     path /quiz.ScoringService/*
    @payment     path /quiz.PaymentService/*

    reverse_proxy @auth        h2c://auth:50054
    reverse_proxy @matchmaking h2c://matchmaking:50051
    reverse_proxy @quiz        h2c://quiz:50052
    reverse_proxy @scoring     h2c://scoring:50053
    reverse_proxy @payment     h2c://payment:50055

    reverse_proxy /payment/webhook http://payment:8080
}
```

## Certificate provisioning

Use Let's Encrypt via the proxy's ACME integration (Caddy is the
shortest path; nginx via certbot is the standard). Auto-renew on the
30-day mark — anything less than a 60-day TTL needs monitoring on
the renewal job.

## Optional: terminate TLS at the gRPC server

If your deployment can't add a proxy, gRPC services can be configured
to terminate TLS directly. Add to each `services/*/main.go` before
`grpc.NewServer(...)`:

```go
creds, err := credentials.NewServerTLSFromFile(certFile, keyFile)
if err != nil { log.Fatal(ctx, "load tls", "err", err) }
grpcServer := grpc.NewServer(grpc.Creds(creds), ...)
```

Drive `certFile` / `keyFile` from env vars and update the
`pkg/config.MustCommon` loader to require them when `TLS_ENABLED=true`.
Plumb the same change into the Dart gRPC client
(`flutter/lib/services/quiz_service.dart` + `auth_service.dart`) by
swapping `ChannelCredentials.insecure()` for a TLS credential.

## Why not just enable TLS in the docker-compose now

The repo doesn't ship with a cert provisioning path, and the existing
docker-compose setup is intentionally insecure-by-default for local
development. Forcing TLS would require every contributor to mint a
local cert just to run the test suite. Document the deployment
expectation; let the deployer choose proxy vs in-process.

## Open questions for production

- **Mutual TLS between services?** Not required today (services run in
  a shared private network — VPC or Kubernetes pod-to-pod), but worth
  considering for a multi-tenant or zero-trust deploy. cert-manager on
  k8s with a shared PKI is the standard path.
- **HSTS / OCSP stapling** — handled by the proxy config, not by Go.
- **Client-cert pinning for the Razorpay webhook source IP** —
  Razorpay publishes an IP range; an allowlist at the proxy adds
  defense in depth on top of the HMAC signature verification
  (`services/payment/main.go:274`, `:514-517`).
- **Refresh-token transport** — `pkg/auth/refresh.go` issues a 32-byte
  hex refresh token over the same gRPC channel as everything else; it
  IS sensitive (30-day session credential), so TLS is the line of
  defence that keeps it confidential in transit. The Flutter side
  persists it in platform secure storage
  (`flutter/lib/services/auth_storage.dart`) — that side of the
  threat model is already covered.
