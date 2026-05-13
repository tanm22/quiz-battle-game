# ADR-0006 — Coin reward amounts (initial calibration)

## Status
Accepted — 2026-04-26. Revisit after the first 2 weeks of telemetry once shop conversion data exists.

## Context

The coin economy has earn sources (daily streak, match wins, referrals, tournament placements) and shop sinks (cosmetics, streak freeze, premium-trial days, reroll topic). The spec didn't pin the numbers — and the numbers directly affect whether the shop feels reachable or grindy.

We have no telemetry yet: no DAU baseline, no win-rate distribution, no shop-conversion data. Calibrating from data is impossible; calibrating from feel is the next-best option.

## Decision

Anchor the economy on **1 match win = 100 coins** and back into everything else.

### Earn amounts

| Source | Amount | Rationale |
|---|---:|---|
| Daily reward — streak day 1 | 10 | Light dopamine for showing up |
| Daily reward — typical day | 20–50 | Existing `rewardForDay` ladder; unchanged |
| Daily reward — milestone (day 7, 14) | 100–200 | Existing ladder; unchanged |
| **Match win (1st place)** | **100** | **Anchor: 1 match = 1 unit of "feel"** |
| Referral — referrer credit | 100 | Must beat the marginal cost of asking a friend |
| Referral — referee credit | 50 | Welcome bonus, half the referrer prize |
| Tournament 1st place | 1000 | 10× a regular match — makes winning a tournament *feel* like a big deal |
| Tournament 2nd place | 500 |  |
| Tournament 3rd place | 250 |  |
| Tournament 4th-10th | 100 | Token; landing here feels recognised, not rewarded |

The daily-reward ladder lives in `services/auth/main.go::rewardForDay` and is unchanged by this calibration. Tournament payouts are configured per tournament in `tournaments.prizePool`; the table above is the default suggested when seeding new tournaments.

### Shop pricing

| Item | Price | Approx. matches to earn |
|---|---:|---:|
| Avatar frame (cosmetic) | 200–500 | 2–5 |
| Name color (cosmetic) | 150–300 | 1.5–3 |
| Streak freeze (1/week cap) | 200 | 2 |
| Premium 3-day trial | 1500 | 15 |
| Reroll question topic (1×) | 50 | 0.5 |

### Why these numbers
- **100 coins per win** keeps the cosmetics ("buy a frame in 2-5 wins") and the trial ("aspirational at 15 wins") on opposite ends of a single intuitive scale.
- **Tournament 1st = 1000** matches the spirit of the existing seed's "Top 3 win 500/300/100" pattern, while making *winning a tournament* feel noticeably bigger than winning ten matches.
- **Streak freeze at 200** = two wins. Cheap enough to grab when you have a 14-day streak going; the once-per-week cap is the actual scarcity lever, not the price.

## Consequences

### Positive
- The numbers are easy to remember and explain. Anchoring on "1 win = 100" gives every other reward a relatable mental ratio.
- Shop UX is testable end-to-end on day 1: a new user can play 2 matches and have enough for a cosmetic, which is the smallest feedback loop the economy can offer.

### Negative
- The numbers are arbitrary. We accept that and plan to revisit once we have a week of `coin_ledger` data. Specifically: median daily earn, p50/p90 days-to-first-purchase, median balance at 7 days.
- Reward amounts are hardcoded in Go (`matchWinCoinReward` in `services/quiz/main.go`, `referralReferrerCoins` / `referralRefereeCoins` in `services/scoring/coins.go`, `rewardForDay` ladder in `services/auth/main.go`). A future PR can lift them into a config collection if A/B testing becomes useful — premature today.
- Tournament prizes stay table-driven via `tournaments.prizePool`, so ops can tune individual tournaments without a deploy.

## Alternatives considered

- **Fully data-driven from launch.** No data to calibrate against; we'd be using arbitrary numbers anyway, just dressed up. Rejected.
- **Per-minute target ("X coins/min of play")**. Match length varies (5-8 minutes typical); per-minute hides the user-facing intuition of "I won → I get coins". Rejected.
- **Flat-payout tournaments (e.g., 200 to top 10).** Kills the competitive draw. Rejected.

## References
- `services/quiz/main.go::matchWinCoinReward`.
- `services/scoring/coins.go::referralReferrerCoins / referralRefereeCoins`.
- `services/auth/main.go::rewardForDay`.
- `seed/main.go` — tournament seeds (PrizePool table) and shop catalog.
- `seed/shop_items.json` — shop SKU prices.
