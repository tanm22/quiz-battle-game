# ADR-0004 — gRPC server streaming for real-time game and matchmaking events

## Status
Accepted — 2026-04-15.

## Context

A multiplayer quiz needs two real-time channels from server to client:

1. **Matchmaking notification.** Client joins the pool, then must learn "you've been paired, the room is `roomId`, the other player is `opponentName`" without polling.
2. **Game events.** Once a match starts, the client receives a stream of `QuestionBroadcast`, `LeaderboardUpdate`, `RoundResult`, `MatchEnd`, etc.

Three plausible transports:

| Option | Pros | Cons |
|---|---|---|
| HTTP long-polling | Works through every proxy | Latency = poll interval; expensive |
| WebSocket | Native to browsers | Separate auth path from our gRPC; bespoke framing |
| gRPC server streaming | Same client SDK as unary RPCs, type-safe, HTTP/2 multiplexing | Some load balancers don't preserve streams well |

We already chose gRPC for unary RPCs (auth, matchmaking-join, etc.) because of type safety and the auto-generated Dart client. Adding two streaming RPCs to the same surface keeps the client coherent.

## Decision

Use **gRPC server streaming** for both real-time channels:

- `MatchmakingService.SubscribeToMatch` — single-event stream; emits one `MatchEvent` when a match is found, then closes. Client re-subscribes on next match.
- `QuizService.StreamGameEvents` — multi-event stream for the duration of a match; emits a `GameEvent` (oneof) per game event.

Both RPCs accept a `sequence_number` request field. The server emits monotonically increasing sequence numbers, and on reconnect the client passes the last seen sequence so the server can resume cleanly.

Connection management on the quiz side:

- The server holds a `sync.Map` keyed by `"roomId:userId"`, each entry a Go channel of pending `*GameEvent`s.
- A goroutine per stream pumps events from the channel to the gRPC `Send()`.
- On `Send` error or client disconnect, the entry is removed and the channel closed.
- A defer-driven cleanup checks `connectedPlayersInRoom`; the last player to drop triggers `finishMatch` (guarded by `room:{id}:match_finalized` SETNX so two parallel drops don't double-finalize).

## Consequences

### Positive
- Same client SDK end-to-end. The Dart `grpc` package handles streaming with the same call site shape as unary RPCs.
- HTTP/2 multiplexing means many streams share one TCP connection. Good for mobile where opening connections is expensive.
- Sequence numbers + reconnect logic give us "at-least-once event delivery from the client's perspective" with minimal complexity.
- Server-authoritative timer. The client never decides round end — `deadline_unix` arrives with `QuestionBroadcast`. The client just renders a countdown.

### Negative
- Load balancing across multiple quiz instances would require sticky routing or a Redis-pubsub fan-out (both players' streams must hit the same instance that owns the room state). Today we run a single instance.
- Plain HTTP/2 streaming doesn't go through every proxy. Production deployments need a gRPC-aware reverse proxy (Envoy, NGINX with gRPC enabled).
- Goroutine-per-stream model puts a memory floor of ~8 KB per active stream. At thousands of concurrent matches this becomes noticeable; we accept it for v1.

### Alternatives considered

**A. WebSocket gateway.** Common in games. Better browser compatibility, but we'd be re-implementing the gRPC-style request/response contracts for game events. Rejected for now; a WebSocket gateway *alongside* the gRPC streams is a reasonable future addition for browser clients.

**B. Long-polling.** Latency-bounded by poll interval (≥1 s). Unacceptable for a real-time quiz where a leaderboard update happens after every answer.

**C. Server-sent events (SSE).** Browser-friendly, simpler than WebSocket. Doesn't help Flutter on mobile and forces a separate client stack.

## References
- `services/quiz/main.go::StreamGameEvents` — server implementation.
- `services/matchmaking/main.go::SubscribeToMatch` — single-event server stream.
- `flutter/lib/providers/game_state.dart` — client consumption.
- `proto/quiz.proto` — `GameEvent oneof { ... }`.
