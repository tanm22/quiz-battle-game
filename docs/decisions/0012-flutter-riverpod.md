# ADR-0012 — Flutter client with Riverpod 3 for state management

## Status
Accepted — 2026-04-10.

## Context

The client needs to run on Android (primary), iOS (likely), and ideally desktop / web for debug. The backend speaks gRPC + Protobuf. We had three real options:

- **Flutter** — single Dart codebase for all targets; mature gRPC support; great hot reload.
- **Native Android (Kotlin) + native iOS (Swift) + a web client.** Three codebases. Best per-platform fidelity, but 3× engineering for a 2-person team. Out.
- **React Native.** Reasonable; but gRPC support in JS is awkward and we'd be re-implementing the type-safe contract story in TS.

Flutter won on platform coverage, type-safety story, and the team's existing Dart experience.

Within Flutter, **state management** is the second design choice. Options:

- `setState` / `InheritedWidget` — too primitive for an app with several screens that share auth, game, and shop state.
- `Provider` — solid, simple, but no compile-time safety on dependencies.
- `BLoC` — explicit; heavy boilerplate; the streams model duplicates what gRPC already gives us.
- **Riverpod 3** — Provider's spiritual successor: compile-safe DI, auto-disposal, built-in async state (`AsyncValue`), code-generated providers for type safety.

## Decision

Use **Flutter (Dart 3+)** for the client, **Riverpod 3** for state management.

Conventions in the Flutter codebase:

- **Typed service wrappers** in `flutter/lib/services/`. Every gRPC stub is wrapped in a Dart class (`AuthService`, `ScoringService`, `CoinsService`, etc.) that the rest of the app talks to. Tests substitute fakes by overriding the service provider.
- **Providers** in `flutter/lib/providers/`. One file per feature (`auth_state.dart`, `game_state.dart`, `coins_state.dart`, `shop_state.dart`, etc.). Providers expose `AsyncValue<T>` for anything that involves IO.
- **Invalidate on mutation.** After a successful `PurchaseShopItem`, the purchase modal invalidates `coinBalanceProvider` and `shopInventoryProvider`, which forces a re-fetch on next read. No manual cache wrangling.
- **Riverpod 3 codegen.** Generated providers eliminate Dart-runtime errors for typos in provider names.
- **Theme is one place.** `flutter/lib/theme/` holds colors, typography, and the `ThemeData` for light/dark.

### gRPC channel setup

`flutter/lib/main.dart` constructs a single `ClientChannel` per host (auth, matchmaking, quiz, scoring, payment) at app startup. The host comes from `--dart-define=BACKEND_HOST=...` (default `10.0.2.2` for Android emulator). Each service-stub is a thin wrapper around its channel.

### Server-streaming consumption

Riverpod's `StreamProvider` plus gRPC's `ResponseStream` compose naturally. The game state provider opens `StreamGameEvents`, listens for `GameEvent`s, and reduces them into a `GameState` model that the UI rebuilds against.

## Consequences

### Positive
- One codebase across Android, iOS, web, desktop. We use this routinely — many of the screens are easier to design on desktop and the same code ships to mobile.
- Compile-safe DI eliminates a class of bugs ("provider not found at runtime") that are routine with Provider.
- `AsyncValue<T>` makes loading/error/data states explicit in the UI without try/catch boilerplate per screen.
- Hot reload pairs naturally with the gRPC service-wrapper pattern: edit the UI, the providers reconnect on rebuild.

### Negative
- Riverpod 3 is the third major version; migration from 1.x or 2.x is non-trivial. We started on 3 so this is not a problem for us, but future contributors should not assume 2.x patterns work.
- Codegen step (`build_runner watch`) is an extra moving piece for new contributors. Listed in CONTRIBUTING.
- Flutter web is functional but not zero-config — we mostly use it for debugging the UI, not production.

## Alternatives considered

- **React Native** — already discussed; lose type safety on the gRPC boundary.
- **Native split** — too expensive for the team size.
- **Provider** — works, but no compile-time DI safety. We outgrew it once provider count crossed ~20.
- **BLoC** — explicit but verbose. The Streams duplicate what gRPC + Riverpod already give us.
- **GetX** — controversial in the community for its anti-patterns; we didn't want to relitigate that internally.

## References
- `flutter/lib/main.dart` — channel setup, theme, app entry.
- `flutter/lib/providers/` — Riverpod state per feature.
- `flutter/lib/services/` — typed gRPC wrappers.
- Riverpod 3 docs: https://riverpod.dev/
- Flutter gRPC quickstart: https://grpc.io/docs/languages/dart/quickstart/
