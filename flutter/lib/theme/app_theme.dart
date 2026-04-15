import 'package:flutter/material.dart';

/// App-wide design tokens. Everything here is a const or near-const so the
/// values can be used inside const expressions. Colors that need `.withAlpha`
/// variants are exposed as factory helpers.
///
/// Guidelines:
///  - Screen backgrounds: wrap content in [ScaffoldGradientBackground].
///  - Card surfaces: `decoration: BoxDecoration(borderRadius: AppRadius.card, ...)`.
///  - Implicit animations: prefer [AppDurations.medium] (300ms) unless a
///    specific UX reason calls for quick/slow.

class AppColors {
  AppColors._();

  // -- Brand ----------------------------------------------------------------
  /// Primary CTA, active states, streak flame.
  static const primary = Color(0xFFFF6B35);
  /// Lighter shade for primary gradients.
  static const primarySoft = Color(0xFFFF8F5E);
  /// Secondary (cyan) for neutral highlights, info callouts, quota card.
  static const secondary = Color(0xFF00E5FF);
  /// Premium accent.
  static const gold = Color(0xFFFFD700);
  static const goldDeep = Color(0xFFFFA000);

  // -- Background stack -----------------------------------------------------
  /// Deepest layer — scaffold bottom of gradient.
  static const bgDeep = Color(0xFF0F0E2E);
  /// Mid layer — scaffold top of gradient, AppBar background.
  static const bgMid = Color(0xFF1A1145);
  /// Elevated surfaces (modal sheets, dialogs).
  static const bgTop = Color(0xFF2A1F5E);
  /// Bottom nav background.
  static const bgNav = Color(0xFF150F35);

  // -- Semantic -------------------------------------------------------------
  static const success = Color(0xFF4CAF50);
  static const danger = Color(0xFFFF4444);

  // -- Medals (leaderboard) -------------------------------------------------
  static const medalGold = gold;
  static const medalSilver = Color(0xFFC0C0C0);
  static const medalBronze = Color(0xFFCD7F32);
}

/// Standard border radii. Use these instead of raw `BorderRadius.circular(14)`.
class AppRadius {
  AppRadius._();
  /// Rounded buttons, input fields, small cards.
  static const BorderRadius button = BorderRadius.all(Radius.circular(12));
  /// Default card container.
  static const BorderRadius card = BorderRadius.all(Radius.circular(14));
  /// Hero cards / plan selector / empty-state illustrations.
  static const BorderRadius hero = BorderRadius.all(Radius.circular(16));
  /// Pill-shaped (filter chips).
  static const BorderRadius pill = BorderRadius.all(Radius.circular(20));
}

/// Standard animation durations. Keeps motion consistent.
class AppDurations {
  AppDurations._();
  /// Quick feedback (hover, small tap pulses).
  static const Duration quick = Duration(milliseconds: 150);
  /// Default for AnimatedContainer, AnimatedSwitcher, page transitions.
  static const Duration medium = Duration(milliseconds: 300);
  /// Big motion — reward pop, confetti, leaderboard row reorder.
  static const Duration slow = Duration(milliseconds: 500);
}

/// Reusable gradients.
class AppGradients {
  AppGradients._();

  /// Scaffold background — used by every screen.
  static const LinearGradient scaffold = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.bgMid, AppColors.bgDeep],
  );

  /// Primary CTA button gradient.
  static const LinearGradient primary = LinearGradient(
    colors: [AppColors.primary, AppColors.primarySoft],
  );

  /// Gold / premium gradient.
  static const LinearGradient gold = LinearGradient(
    colors: [AppColors.gold, AppColors.goldDeep],
  );
}

/// Wraps a screen in the standard gradient background. Prefer this over
/// re-declaring `Container(decoration: BoxDecoration(gradient: ...))`.
class ScaffoldGradientBackground extends StatelessWidget {
  final Widget child;
  const ScaffoldGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.scaffold),
      child: child,
    );
  }
}

/// A shimmering placeholder block — used in skeleton loaders on screens that
/// fetch data asynchronously. Wraps a rounded rectangle with an animated
/// gradient that pulses left-to-right.
///
/// Example:
///
///   const SkeletonBlock(height: 20, width: 120)
///
/// The shimmer is non-indicative (i.e. doesn't convey progress percentage)
/// which matches the loading contract we want: "something is coming, hold on".
class SkeletonBlock extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry margin;

  const SkeletonBlock({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.button,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Slide a soft highlight left→right across the dark base.
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + t * 2, 0),
              end: Alignment(1.0 + t * 2, 0),
              colors: [
                Colors.white.withAlpha(8),
                Colors.white.withAlpha(26),
                Colors.white.withAlpha(8),
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}
