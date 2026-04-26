# ADR 0002 — Coin Reward Amounts (initial calibration)

## Status
Accepted — 2026-04-26. Revisit after the first 2 weeks of telemetry once
PR 6/7 ships and we have actual earn/spend data.

## Context
Section 4.3 lists the coin economy sources (daily streak, wins, referrals,
tournament placements) and the shop sinks (cosmetic frames, name colors,
streak freeze, premium trial days, re-roll topic). The spec doesn't pin
the numbers — that's our job, and it directly affects whether the shop
feels reachable or grindy.

We also have no telemetry yet: no DAU baseline, no shop-conversion data,
no win-rate distribution. Calibrating from data is impossible; calibrating
from feel is the next-best option.

## Decision
Anchor the economy on **1 match win = 100 coins**, then back into
everything else.

| Source                                | Amount | Rationale |
|---------------------------------------|-------:|-----------|
| Daily reward — streak day 1           | 10     | Light dopamine for showing up |
| Daily reward — typical day            | 20–50  | Existing `rewardForDay` ladder; unchanged |
| Daily reward — milestone (day 7, 14)  | 100–200 | Existing ladder; unchanged |
| **Match win (1st place)**             | **100**| **Anchor: 1 match = 1 unit of "feel"** |
| Referral — referrer credit            | 100    | Must beat the marginal cost of the invite ask |
| Referral — referee credit             | 50     | Welcome bonus, half the referrer prize |
| Tournament 1st place                  | 1000   | 10× a regular match — gives premium tournaments meaning |
| Tournament 2nd place                  | 500    |   |
| Tournament 3rd place                  | 250    |   |
| Tournament 4th–10th                   | 100    | Token; landing here feels recognised, not rewarded |

(Exact daily-reward ladder lives in `services/auth/main.go::rewardForDay`
and is unchanged by this PR. Tournament payouts are configured per
tournament in `tournaments.prizePool` — the table above is the default
suggested when seeding new tournaments.)

### Shop pricing (lands in PR 4; documented here for symmetry)

| Item                          | Price | Approx. matches to earn |
|-------------------------------|------:|------------------------:|
| Avatar frame (cosmetic)       | 200–500 | 2–5 |
| Name color (cosmetic)         | 150–300 | 1.5–3 |
| Streak freeze (1/week cap)    | 200   | 2 |
| Premium 3-day trial           | 1500  | 15 |
| Re-roll question topic (1×)   | 50    | 0.5 |

### Why these numbers
- **100 coins per win** keeps the cosmetics ("buy a frame in 2–5 wins")
  and the trial ("aspirational at 15 wins") on opposite ends of a single
  intuitive scale.
- **Tournament 1st = 1000** matches the existing `seed/main.go` "Top 3
  win 500/300/100" pattern in spirit while making *winning a tournament*
  noticeably bigger than winning ten matches — otherwise tournaments are
  just longer matches.
- **Streak freeze at 200** = two wins. Cheap enough to grab when you've
  got a 14-day streak going; the once-per-week cap is the actual scarcity
  lever, not the price.

## Consequences
- The numbers are arbitrary. We accept that and plan to revisit once we
  have a week of `coin_ledger` data we can aggregate. Specifically: median
  daily earn, p50 / p90 days-to-first-purchase, median balance at 7 days.
- Hardcoded in code (`matchWinCoinReward` in `services/quiz/main.go`,
  `referralReferrerCoins` / `referralRefereeCoins` in
  `services/scoring/coins.go`, `rewardForDay` ladder in
  `services/auth/main.go`). A future PR can lift these into a config
  collection if A/B testing becomes useful — premature today.
- Tournament prizes stay table-driven via `tournaments.prizePool`, so
  ops can tune individual tournaments without a deploy.

## Alternatives considered
- **Fully data-driven from launch**: nothing to calibrate against; would
  end up using arbitrary numbers anyway. Rejected.
- **Tie everything to a "coins / minute" target**: nice in theory but the
  match length varies (5–8 min typical) so a per-minute target obscures
  the user-facing intuition ("I won → I get coins"). Rejected.
- **Equal-payout tournaments (e.g. flat 200 to top 10)**: kills the
  competitive draw. Rejected.

## References
- `services/quiz/main.go::matchWinCoinReward`
- `services/scoring/coins.go::referralReferrerCoins / referralRefereeCoins`
- `services/auth/main.go::rewardForDay`
- `seed/main.go` tournament seeds (PrizePool table)
