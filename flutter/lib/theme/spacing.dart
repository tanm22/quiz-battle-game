// Spacing + radii tokens.
//
// `Spacing` is the brief's named scale: xs/sm/md/lg/xl/xxl/xxxl plus a
// `Radii` companion for corner radius constants. Use these in NEW
// widgets to keep the scale consistent.
//
// `AppRadius` is the legacy class (button/card/hero/pill) — kept here
// to consolidate spacing-adjacent constants. Re-exported by
// app_theme.dart so the 77+ existing callsites continue to compile.
//
// `AppDurations` and `AppGradients` live here too because they're
// presentation tokens, not theme infrastructure.

import 'package:flutter/material.dart';

/// Named spacing scale — usage:
/// `Padding(padding: EdgeInsets.all(Spacing.lg))`
class Spacing {
  Spacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

/// Radii tokens — usage:
/// `borderRadius: BorderRadius.circular(Radii.md)`
class Radii {
  Radii._();

  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pill = 999.0;
}

/// Legacy class — kept verbatim so the 77 existing callsites compile.
/// New widgets use [Radii] for plain `double` corner-radius values.
class AppRadius {
  AppRadius._();
  static const BorderRadius button = BorderRadius.all(Radius.circular(14));
  static const BorderRadius card = BorderRadius.all(Radius.circular(16));
  static const BorderRadius hero = BorderRadius.all(Radius.circular(20));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

class AppDurations {
  AppDurations._();
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

class AppGradients {
  AppGradients._();

  /// Subtle near-black → dark-navy vertical gradient for the scaffold.
  static const LinearGradient scaffold = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B0A0F), Color(0xFF15131B)],
  );

  /// Coral CTA gradient.
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF26B4D), Color(0xFFE85A3C)],
  );

  /// Gold→coral for premium / tournament emphasis.
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5A524), Color(0xFFE85A3C)],
  );
}
