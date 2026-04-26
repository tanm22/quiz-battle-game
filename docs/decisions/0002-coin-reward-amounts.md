# ADR 0002: Coin Reward Amounts (initial calibration)

## Status

Accepted — 2026-04-26. Revisit after first 2 weeks of telemetry.

## Context

Phase 3 introduces a coin economy with multiple earning sources (daily streak, match wins, referrals, tournament placements) and several spend sinks (cosmetics, streak freeze, premium trial, re-roll). With no telemetry yet, the team needs reasonable starting numbers — the goal isn't to be optimal, just to avoid breaking the economy in an obvious way (runaway inflation, unobtainable shop items, trivially-cheap cosmetics).

## Decision

| Source | Amount | Reasoning |
|--------|--------|-----------|
| Daily reward (streak day 1) | 10 | Light dopamine for showing up |
| Streak bonus (multiples of 7) | +50 (one-shot) | Reward consistency without runaway inflation |
| Match win | 100 | One match should "feel" like meaningful coin |
| Tournament 1st | 1000 | Big enough to gate via premium and matter |
| Tournament 2nd | 500 | |
| Tournament 3rd | 250 | |
| Referral (referrer) | 100 | Must beat marginal cost of inviting |
| Referral (referee) | 50 | Welcome bonus |
| Avatar frame (cosmetic) | 200–500 | 2–5 wins to earn |
| Name color (cosmetic) | 150–300 | |
| Streak freeze (1/week) | 200 | One per week, equivalent to 2 wins |
| Premium 3-day trial | 1500 | ~15 wins; aspirational |
| Re-roll question topic (single-use) | 50 | Cheap, casual |

## Why

Pick numbers that make 1 match win = "100 coins" the mental anchor and back into the rest from there:

- A motivated player who plays 3 matches/day and wins ~50% earns 150 coins/day from match wins. That's enough to grind a 200-coin streak freeze in ~1.5 days, a 500-coin cosmetic frame in ~3 days, the 1500-coin premium trial in ~10 days. Tournament 1st is the only step-change reward (1000 = 10 wins-worth) and is gated to weekend tournaments + premium-only by design.
- Referral bonuses (100 referrer / 50 referee) need to beat what's "free" elsewhere — at 100 each, a successful referral is equivalent to a match win, which feels like a fair trade for the social action.
- Streak rewards stay light (10/day base, +50 every 7 days) because we don't want streak-grinding to be the dominant earn path. Match wins should always feel better.

## Consequences

- Match wins are the dominant earn path. If we later want match wins to be less rewarding (to push players toward tournaments), drop this number first; everything else can stay calibrated to it.
- Tournament prizes are 2.5×–10× a match win to compensate for tournament difficulty + premium gating. If telemetry shows tournament participation is low even with these prizes, the floor is "make 1st place at least 5× a match win" (i.e. 500+ coins for 1st).
- Cosmetic prices intentionally span a 2.5× range so the shop has a clear price ladder. Frames cost more than colors because they're more visually impactful.
- Premium trial price (1500) is roughly 1 month of match-only earnings for a casual player. Anyone willing to grind that much almost certainly converts to paid premium afterward; that's the funnel intent.

## Alternatives considered

- **Telemetry-first calibration**: pick numbers from real player data. Rejected — we have no data and need to ship something to start collecting.
- **Aggressive economy (50% lower amounts)**: forces players into shop carefully but feels punishing for new users. Re-evaluate after 2 weeks if early-game retention drops.
- **Whale-friendly economy (2× higher amounts)**: every shop item feels achievable in a session, but the premium trial loses its aspirational gravity. Tournaments would also stop feeling distinctive.

## How to revisit

Two weeks after launch, pull these metrics from `coin_ledger`:

- Per-user daily-active coin earn distribution (median, P75, P95)
- Median coins-to-first-purchase
- Tournament 1st-place win rate among premium users
- Median coins balance after 30 days of activity (proxy for inflation)

Adjust whichever amounts are obviously off. Update this ADR with telemetry-backed numbers and supersede this version (do not overwrite).
