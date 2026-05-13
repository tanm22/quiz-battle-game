# Contributing

Even on a three-person team, conventions matter. They're not bureaucracy — they're the thing that turns the codebase from "we know how it works" into "anyone can find their way around." Treat this file as the floor, not the ceiling.

## Contents

1. [Code of conduct](#code-of-conduct)
2. [Getting set up](#getting-set-up)
3. [Branching](#branching)
4. [Commit messages](#commit-messages)
5. [Pull requests](#pull-requests)
6. [Code style](#code-style)
7. [Testing](#testing)
8. [Documentation](#documentation)
9. [Reviewing](#reviewing)
10. [Releasing](#releasing)
11. [Security policy](#security-policy)

---

## Code of conduct

Be kind. Critique the code, not the person. Assume good faith — most disagreements are vocabulary mismatches that resolve in five minutes of conversation. If you're frustrated, walk away for ten minutes; the diff will still be there.

---

## Getting set up

1. **Clone the repo** and `cd quiz-battle-game`.
2. **Boot the stack** — `docker compose up --build` (see [README.md](./README.md) for env-var setup).
3. **Install Go 1.25+** if you plan to run services locally outside Docker. `brew install go` on macOS, or follow https://go.dev/dl/.
4. **Install Flutter 3.7+** if you plan to touch the client. `brew install --cask flutter` on macOS.
5. **Install protoc** if you plan to regenerate proto stubs. `brew install protobuf`. For Dart: `dart pub global activate protoc_plugin` and put `~/.pub-cache/bin` on `PATH`.
6. **Sanity check** — `make test` (Go tests) and `cd flutter && flutter test` (Dart tests) should both pass on a clean checkout.

A `pre-commit` hook isn't shipped today; we rely on `make lint` + CI. If you want one locally, the `gofmt` + `go vet` + `flutter analyze` trio is a fine starting point.

---

## Branching

We use a simple long-lived-main / short-lived-feature model.

- **`main`** is the single source of truth. CI runs against every PR targeting `main`; merges to `main` are deployable.
- **Feature branches** are short-lived (hours to days, not weeks). Branch off `main`, push, open a PR.
- **No long-running release branches.** If something needs to ship in stages, use feature flags or compose-level toggles, not parallel branches.

### Branch naming

Use a prefix that hints at the kind of work. Slash-separated, lowercase, hyphenated:

```
feat/coin-shop-ui
fix/payment-webhook-double-process
refactor/extract-keys-package
docs/runbook-payments
chore/upgrade-go-1.25
hotfix/jwt-signing-secret-leak
test/scoring-recency-bonus
```

The prefix categories match the commit-message types (see below). The slug after the slash should be 3-6 words.

---

## Commit messages

Follow **Conventional Commits**. Format:

```
<type>(<scope>): <subject>

<body — optional, wrap at 72 cols>

<footer — optional, e.g., "Refs #123", "Closes #45">
```

### Types

| Type | When to use |
|---|---|
| `feat` | A user-visible new feature |
| `fix` | A bug fix |
| `refactor` | Internal restructure without behavior change |
| `perf` | Performance improvement |
| `test` | Tests only — no production code |
| `docs` | Documentation only |
| `chore` | Dependency bump, build-system change, tooling |
| `style` | Formatting or naming (rare; lint usually catches these) |
| `hotfix` | A `fix` that's urgent enough to need an out-of-band release |

### Scope

Use a short noun for the affected area. Common scopes: `auth`, `quiz`, `scoring`, `payment`, `notification`, `matchmaking`, `coins`, `shop`, `tournament`, `friends`, `flutter`, `proto`, `infra`, `docs`, `seed`.

### Subject

- Imperative mood ("add", "fix", "remove" — not "added", "fixes", "removed").
- No trailing period.
- Lowercase first letter unless it's a proper noun.
- Under 70 characters.

### Body

- Explain *why*, not *what*. The diff already shows what. The commit message is the only place that captures the motivation.
- Reference the original incident, bug ticket, or design doc by URL or ID.
- If the change has a non-obvious risk, call it out: "This adds a Mongo transaction in the hot path; benchmarks show +6 ms p99 on writes."

### Examples

```
feat(coins): atomic ledger with Mongo transactions

The previous bare `$inc` left users.coins and coin_ledger consistent
only on the happy path. A crash between the two writes would create
either a phantom credit or a phantom debit. Wrap both writes in a
single Mongo session with WithTransaction; add a unique compound
index (userId, refId, reason) as the producer-side idempotency key.

Closes #312
```

```
fix(payment): claim outbox row inside txn to stop multi-replica double-grant

A second payment replica was running the premium-trial consumer for
debugging. Both replicas would dequeue the same row and apply the
effect twice. Move the dequeue+mark-claimed into a single Mongo
transaction so only one replica wins the row. Single-replica deployments
are unaffected.

Refs ticket OPS-118
```

```
docs(runbook): add Razorpay webhook replay procedure

Asked twice in two months. Document it once.
```

### Co-authoring

When pairing or accepting a substantial suggestion, credit the other contributor with a `Co-Authored-By:` trailer:

```
Co-Authored-By: Alice <alice@example.com>
```

---

## Pull requests

### Size

Aim for **under 400 lines changed** per PR. Bigger PRs are harder to review well and harder to revert. If a feature is bigger, split it:

1. PR 1: proto changes + types + tests (mergeable in isolation).
2. PR 2: backend implementation against the new proto.
3. PR 3: Flutter wiring.
4. PR 4: cron jobs, observability, polish.

This is the convention the existing coin/shop work followed (PRs 1-5 in the repo history). Future contributors should follow the same.

### PR title

Match the commit-message convention. Single-commit PR? The title and the commit message are the same. Multi-commit PR? The title is a summary of the squash-merge commit, which will follow the commit-message rules.

### PR description

Use this template:

```markdown
## Summary
- One bullet per significant change. Three to five bullets max.

## Why
Brief paragraph: what motivated this. Link tickets / incident reports.

## Notes for the reviewer
- Anything non-obvious. Trade-offs you considered. A particular file
  worth a closer look.

## Test plan
- [ ] Unit tests added/updated.
- [ ] Manual: <step-by-step what you exercised>.
- [ ] Edge cases considered: <list>.

## Risk
Low / Medium / High. One sentence on the blast radius if this is wrong.

## Rollout
- Anything that needs to happen at merge or after (DB migration, env
  var, feature flag flip). If nothing — say "Standard merge."
```

### Required for merge

- [ ] All CI checks pass (`make lint`, `make test`, Flutter tests).
- [ ] At least one approving review.
- [ ] No unresolved review comments.
- [ ] Squash-merge (we prefer one commit per PR on `main`).

### Hotfix path

If something is on fire in production:

1. Branch from `main` as `hotfix/<thing>`.
2. Open the PR with `hotfix:` type and "Risk: High" in the description.
3. Get an immediate reviewer (Slack-page the on-call).
4. Merge and deploy.
5. Follow-up PR with tests + post-mortem within 24 hours.

The bypass exists for incidents only — don't use it for "I want to skip review on this feature."

---

## Code style

### Go

- `gofmt` is non-negotiable. `make lint` will fail on unformatted files.
- `go vet` clean. `make lint` checks.
- Lints we follow informally: no unused identifiers; no exported types without doc comments; no panics outside `main()` / test setup.
- **Error wrapping**: `fmt.Errorf("operation X: %w", err)`. Always wrap; never silently swallow.
- **Logging**: use `pkg/log` (slog-backed). Include `ctx` so trace IDs propagate. Don't `fmt.Println`; don't `log.Print`.
- **Context propagation**: every function that does IO takes `ctx context.Context` as its first argument.
- **`var ()` block** at the top of a file for constants; one logical group per `var`.
- **Tests** live next to the code (`foo.go` ↔ `foo_test.go`). Use the same package — internal tests are normal in this codebase.
- **Mocks**: prefer hand-written fakes over generated mocks. Faster to read, easier to debug.

### Dart / Flutter

- `dart format` is non-negotiable. `flutter analyze` should be clean.
- Use Riverpod codegen for new providers. No legacy `Provider` calls in new code.
- Avoid `GlobalKey` and `setState` outside `StatefulWidget` lifecycle hooks.
- Strings shown to users live in the per-screen widget files; we don't have an i18n layer yet, and a premature one isn't on the roadmap.

### Proto

- One `.proto` file: `proto/quiz.proto`. Resist the urge to split — services share many message types.
- Fields are `snake_case`. Service and message names are `PascalCase`.
- Append fields, don't reorder. Field numbers are forever.
- Document every RPC and every non-obvious field with a comment line above it. The proto is read by humans more often than the docs are.

### File naming

- Go: `snake_case.go`.
- Dart: `snake_case.dart`.
- Tests: `*_test.go` and `*_test.dart`.
- Generated files: never edit by hand; regenerate via `make proto`.

---

## Testing

### Levels

| Level | Where | What you test |
|---|---|---|
| Unit | `pkg/`, per-file `*_test.go` | Pure functions: scoring formula, daily quota, streak math, HMAC signature, referral logic |
| Service | `services/*/[name]_test.go` | RPC handlers against test doubles for Mongo / Redis / AMQP |
| Integration | `services/*` with real infra | Per-service, with real Mongo + Redis + (sometimes) RabbitMQ via `testcontainers` |
| Flutter unit | `flutter/test/` | Provider behavior with a fake gRPC service |
| Flutter widget | `flutter/test/widgets/` | Pure widget rendering, no provider state |

We don't run a true end-to-end test in CI today (it would need Docker-in-Docker or a real test cluster). The `make status` and the demo script fill that gap manually.

### Coverage gate

`make coverage` runs the per-function coverage gate on the five pure-logic pieces the spec calls out: scoring formula, daily quota, streak, webhook signature, referral. Any of them dropping below **70%** fails the build.

When you touch one of these, add tests proportional to the change.

### Writing good tests

- Test the *behavior*, not the implementation. If two implementations satisfy the same test, that's a feature.
- One test per scenario. Don't pile assertions into a monolithic `TestAll`.
- Use table-driven tests where applicable. The Go convention is well-established.
- Tests must be deterministic. Use a clock interface (`Clock`) and pass a fake clock in tests; don't read `time.Now()` directly in production code.
- A flake is a bug. Fix or quarantine within 24 hours.

---

## Documentation

- **Comments on the *why*, not the *what*.** Good comments explain a constraint, a workaround, or a non-obvious invariant. Bad comments restate the function signature.
- **Public API changes** require an update to `proto/quiz.proto` (with doc comments) and `api.md`.
- **Architectural changes** require an ADR. Copy `docs/decisions/0001-microservices-split.md` as a template; the format is Status / Context / Decision / Consequences / Alternatives / References.
- **Operational changes** (a new env var, a new cron, a new way to debug) require an update to `runbook.md`.
- **README** gets touched for setup changes, dependency changes, and quick-start changes — not for feature-level docs (those go to the relevant doc).

---

## Reviewing

### As an author

- Self-review the diff before you mark the PR ready. You'll catch half the comments yourself.
- Respond to every comment. "Done" is fine; "I disagree, here's why" is fine; silence is not.
- Don't squash-rewrite your branch mid-review. The reviewer needs the diff to stay stable until they ack.
- After approval, you may rebase + push to clean up history before the squash-merge.

### As a reviewer

- Aim for a turnaround of **under 1 business day**. Faster is better — review latency is the silent killer of velocity.
- Read the description first. If the description is unclear, ask for one before reading code.
- Look at tests. If a change has no tests and isn't a refactor or pure docs change, ask why.
- "Nit:" prefix for non-blocking comments. "Blocking:" or no prefix for things that must change before merge.
- Approve when you're happy. Don't gate forever on style; raise it once and move on.

---

## Releasing

We don't tag versioned releases — `main` is what's deployed. To deploy:

1. Confirm CI is green on the merged commit.
2. SSH to the production host (or trigger the deploy pipeline).
3. `git pull && docker compose up --build -d`.
4. Watch `docker compose logs --tail=100 -f` for 2 minutes.
5. Smoke-test from the Flutter side (log in, run a match).

When the team grows past three people, this should mature into:

- Tagged releases (`v1.2.3`).
- A changelog generated from commit messages.
- Blue/green deploy or canary instead of all-at-once.

Until then, the lightweight model is honest about the team size.

---

## Security policy

- **Don't commit secrets.** `.env` is gitignored. CI uses test keys via repo secrets. If you accidentally push a key, **rotate it immediately** (it's already public from the moment of the push) and then remove from history.
- **Report vulnerabilities privately**, not via public issues. Email the maintainer; we'll coordinate disclosure.
- **Dependency updates**: keep them current but boring. Dependabot-style PRs are fine; review them for behavior changes the same way as feature PRs.
- **Authentication**: when in doubt, refuse access. The interceptor's behavior on a missing or invalid token is `codes.Unauthenticated`, not "let it through and check later".
- **HMAC verification**: read the full body before verifying. Don't trust streamed bodies. See [adr-0009](docs/decisions/0009-razorpay-dual-path.md) for the rationale.

---

Thanks for reading this far. Open the PR.
