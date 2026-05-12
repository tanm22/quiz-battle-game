// App typography — system font, tabular figures on numbers, tight
// letter-spacing on the bold scale.
//
// Why an explicit `AppText` class on top of ThemeData.textTheme:
//   ThemeData.textTheme covers the standard Material slots (displayLarge,
//   headlineMedium, bodyLarge, etc.) and is used by built-in widgets.
//   `AppText` is the *brand* scale used by our own custom widgets
//   (statBig for big numbers, codeBig for the referral letter-spaced
//   monospace look, micro for pill chip text). Keeping them separate
//   means a Material widget gets the Material slot and our custom
//   widgets get our scale — no surprise font sizes on Snackbars,
//   Dialogs, etc.

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppText {
  AppText._();

  // ────────────────────────────────────────────────────────────────
  // Common style fragments
  // ────────────────────────────────────────────────────────────────
  // Bold-scale styles tighten letter-spacing for the brand-typo feel.
  static const double _tightLs = -0.3;

  // Tabular figures keep number columns aligned in the leaderboard,
  // stats grid, and coin balance. Applied on every numeric style.
  static const _tabular = FontFeature.tabularFigures();

  // ────────────────────────────────────────────────────────────────
  // Display & headlines
  // ────────────────────────────────────────────────────────────────

  /// Splash, login title.
  static const display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.18,
    letterSpacing: _tightLs,
    color: AppColors.text,
  );

  /// Screen titles, username greeting on home.
  static const h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.21,
    letterSpacing: _tightLs,
    color: AppColors.text,
  );

  /// Section headers, modal titles.
  static const h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.27,
    letterSpacing: _tightLs,
    color: AppColors.text,
  );

  /// Card titles.
  static const h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.33,
    letterSpacing: _tightLs,
    color: AppColors.text,
  );

  // ────────────────────────────────────────────────────────────────
  // Body
  // ────────────────────────────────────────────────────────────────

  /// Primary body — list-row primary text, descriptions.
  static const bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.37,
    color: AppColors.text,
  );

  /// Standard body — secondary descriptions, dialog content.
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.42,
    color: AppColors.text,
  );

  /// Labels under stats / under buttons / hints.
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.33,
    color: AppColors.textMuted,
  );

  /// Pill chip text — small, tight, w600.
  static const micro = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.4,
    color: AppColors.text,
  );

  // ────────────────────────────────────────────────────────────────
  // Numeric — tabularFigures for column alignment
  // ────────────────────────────────────────────────────────────────

  /// Big stat numbers (StatCell value, balance figures).
  static const statBig = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: _tightLs,
    fontFeatures: [_tabular],
    color: AppColors.text,
  );

  /// Referral code — 6-character monospace look without changing font.
  /// Apply via copyWith to keep the color flexible per surface.
  static const codeBig = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.13,
    letterSpacing: 8,
    fontFeatures: [_tabular],
    color: AppColors.text,
  );
}
