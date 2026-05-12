// App color tokens — full surface for the dark-theme revamp.
//
// Why this file (split out of app_theme.dart):
//   The old theme bundled colors, radii, gradients, and helper widgets into
//   one 218-line file. Splitting colors out makes the token surface easier
//   to scan and lets future revamps replace JUST the palette without
//   touching ThemeData wiring.
//
// Backward-compatibility contract:
//   Every field on the previous AppColors is kept here under the same
//   name. The 30+ screens that already do `AppColors.primary`,
//   `AppColors.surface`, etc. continue to compile. Some VALUES drift to
//   match the revamp tokens (slightly deeper coral, OLED-friendlier
//   neutrals) — that's the point of the revamp.
//
// New fields added for the revamp:
//   surfaceHi / surfaceOv / divider (surface stack)
//   primaryHov / primaryPrs / primaryGlow / primaryTint (state colors)
//   goldGlow / goldSoft (matching state colors for gold)
//   successSoft / dangerSoft / warning / info (semantic states + soft variants)
//   flame / flameGlow / speed / speedGlow (streak + speed-streak UI)
//   textOnPri / textOnGold (foreground colors on tinted backgrounds)
//   tierBronze / tierSilver / tierGold (aliases for medal* — brief naming)
//
// Why `primaryTint` and not `primarySoft`:
//   The brief lists `primarySoft = Color(0x1FE85A3C)` (12% alpha tint),
//   but legacy code uses `primarySoft = Color(0xFFD97757)` as a *solid*
//   lift coral (hover/pressed state). Renaming would silently break the
//   4 existing call-sites. We added `primaryTint` for the new 12%-alpha
//   semantic and left `primarySoft` as its existing solid value.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ────────────────────────────────────────────────────────────────
  // Background stack — deep near-black with cool undertone for OLED.
  // ────────────────────────────────────────────────────────────────
  static const bg = Color(0xFF0B0A0F);
  static const surface = Color(0xFF15131B);
  static const surfaceHi = Color(0xFF1C1923); // lifted card / chip fill
  static const surfaceOv = Color(0xFF221E2B); // overlay (modals, sheets)
  static const bgTop = Color(0xFF1F1F36); // legacy alias — kept for callsites
  static const bgNav = Color(0xFF15131B); // bottom-nav background
  static const cardTint = Color(0xFF20203A); // legacy card sub-fill

  // Legacy aliases — kept for callsites in pre-revamp screens.
  static const bgDeep = bg;
  static const bgMid = bg;

  // ────────────────────────────────────────────────────────────────
  // Borders & dividers
  // ────────────────────────────────────────────────────────────────
  static const divider = Color(0xFF2A2533);
  static const border = Color(0xFF312B3D);
  static const borderBright = Color(0xFF3D3D60); // legacy — focused borders

  // ────────────────────────────────────────────────────────────────
  // Brand — coral (deepened from the previous #C96442 to read on OLED)
  // ────────────────────────────────────────────────────────────────
  static const primary = Color(0xFFE85A3C);
  static const primaryHov = Color(0xFFF26B4D); // hover
  static const primaryPrs = Color(0xFFCC4A2E); // pressed
  static const primaryGlow = Color(0x59E85A3C); // 35% — BoxShadow
  static const primaryTint = Color(0x1FE85A3C); // 12% — tinted bg fills

  // Legacy alias: primarySoft was a solid lift coral; 4 existing
  // callsites depend on it. Keep it as a separate solid color so old
  // code reads the same. New code reaches for `primaryHov` /
  // `primaryTint` per the revamp spec.
  static const primarySoft = Color(0xFFD97757);

  // ────────────────────────────────────────────────────────────────
  // Secondary / accent colors (kept for legacy callsites)
  // ────────────────────────────────────────────────────────────────
  static const secondary = Color(0xFF4FC3F7);
  static const accent = Color(0xFF9B7BD4);
  static const accentLight = Color(0xFFB6A6E0);
  static const accentBg = Color(0xFF2A2647);

  // ────────────────────────────────────────────────────────────────
  // Gold — coins, trophies, PRO badge
  // ────────────────────────────────────────────────────────────────
  static const gold = Color(0xFFF5A524);
  static const goldDeep = Color(0xFFD88E0E);
  static const goldGlow = Color(0x66F5A524); // 40% alpha — shadow
  static const goldSoft = Color(0x1FF5A524); // 12% alpha — tinted bg
  static const goldBg = Color(0xFF2E2818); // legacy solid faint gold

  // ────────────────────────────────────────────────────────────────
  // Semantic — success / danger / warning / info
  // ────────────────────────────────────────────────────────────────
  static const success = Color(0xFF22C55E);
  static const successSoft = Color(0x2422C55E); // ~14% alpha
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0x24EF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);

  // Legacy tinted backgrounds — kept for pre-revamp screens.
  static const emeraldBg = Color(0xFF15291F);
  static const roseBg = Color(0xFF2E1A1B);
  static const orangeBg = Color(0xFF2E1F15);
  static const cyanBg = Color(0xFF16252A);

  // ────────────────────────────────────────────────────────────────
  // Streak (flame) + speed-streak (cyan)
  // ────────────────────────────────────────────────────────────────
  static const flame = Color(0xFFFF6B35);
  static const flameGlow = Color(0x66FF6B35);
  static const speed = Color(0xFF22D3EE);
  static const speedGlow = Color(0x6622D3EE);

  // ────────────────────────────────────────────────────────────────
  // Text — pure white at the top of the hierarchy, graduating down
  // ────────────────────────────────────────────────────────────────
  static const text = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB5B5CC); // legacy
  static const textMuted = Color(0xFFA8A2B5);
  static const textDim = Color(0xFF6B6478);
  static const textOnPri = Color(0xFFFFFFFF); // text on primary fills
  static const textOnGold = Color(0xFF1A1208); // text on gold fills

  // ────────────────────────────────────────────────────────────────
  // Tier / medal — leaderboards, podiums, rank badges
  // ────────────────────────────────────────────────────────────────
  static const tierBronze = Color(0xFFCD7F32);
  static const tierSilver = Color(0xFFC0C0C0);
  static const tierGold = Color(0xFFFFD700);

  // Brief lists `tierBronze/Silver/Gold` and legacy code uses
  // `medalBronze/Silver/Gold`. Aliases keep both names working.
  static const medalBronze = tierBronze;
  static const medalSilver = tierSilver;
  static const medalGold = tierGold;

  static const silverBg = Color(0xFF1F2228); // legacy faint silver
  static const bronzeBg = Color(0xFF2A1F14); // legacy faint bronze
}
