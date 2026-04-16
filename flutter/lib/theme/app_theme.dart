import 'package:flutter/material.dart';

/// Light-theme design tokens inspired by the quiz-battle-ui.jsx reference.
/// Palette: white backgrounds, purple accent, orange CTA, clean borders.

class AppColors {
  AppColors._();

  // -- Brand ----------------------------------------------------------------
  static const primary = Color(0xFFEA580C);       // orange CTA
  static const primarySoft = Color(0xFFF97316);    // lighter orange
  static const secondary = Color(0xFF0891B2);      // cyan
  static const accent = Color(0xFF6D59C4);         // purple accent
  static const accentLight = Color(0xFF8B7BD4);
  static const gold = Color(0xFFE8940A);
  static const goldDeep = Color(0xFFD97706);

  // -- Background stack -----------------------------------------------------
  static const bg = Color(0xFFFFFFFF);             // scaffold base
  static const surface = Color(0xFFFFFFFF);        // surface/card
  static const cardTint = Color(0xFFF8FAFC);       // subtle card fill
  static const bgTop = Color(0xFFF8FAFC);          // elevated (dialogs)
  static const bgNav = Color(0xFFFFFFFF);          // bottom nav
  // Legacy aliases (used by existing code)
  static const bgDeep = bg;
  static const bgMid = bg;

  // -- Borders & dividers ---------------------------------------------------
  static const border = Color(0xFFE8E5F0);
  static const borderBright = Color(0xFFD4CFE6);

  // -- Text -----------------------------------------------------------------
  static const text = Color(0xFF1A1632);
  static const textSecondary = Color(0xFF4A4560);
  static const textMuted = Color(0xFF8A8599);
  static const textDim = Color(0xFFB5B0C4);

  // -- Semantic -------------------------------------------------------------
  static const success = Color(0xFF059669);        // emerald
  static const danger = Color(0xFFE11D48);         // rose

  // -- Tinted backgrounds ---------------------------------------------------
  static const accentBg = Color(0xFFF0EDF9);
  static const goldBg = Color(0xFFFEF7E8);
  static const cyanBg = Color(0xFFECFEFF);
  static const emeraldBg = Color(0xFFECFDF5);
  static const roseBg = Color(0xFFFFF1F2);
  static const orangeBg = Color(0xFFFFF4ED);

  // -- Medals (leaderboard) -------------------------------------------------
  static const medalGold = gold;
  static const medalSilver = Color(0xFF94A3B8);
  static const medalBronze = Color(0xFFCD7F32);
}

class AppRadius {
  AppRadius._();
  static const BorderRadius button = BorderRadius.all(Radius.circular(12));
  static const BorderRadius card = BorderRadius.all(Radius.circular(14));
  static const BorderRadius hero = BorderRadius.all(Radius.circular(16));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(20));
}

class AppDurations {
  AppDurations._();
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

class AppGradients {
  AppGradients._();

  static const LinearGradient scaffold = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
  );

  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
  );

  static const LinearGradient gold = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
  );
}

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

/// Card decoration matching the JSX reference: white, subtle border, soft shadow.
BoxDecoration appCardDecoration({Color? borderColor}) => BoxDecoration(
  color: AppColors.surface,
  borderRadius: AppRadius.card,
  border: Border.all(color: borderColor ?? AppColors.border),
  boxShadow: const [
    BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x14000000), blurRadius: 1),
  ],
);

/// Skeleton loader (shimmer on light base).
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
              colors: const [
                Color(0xFFEEECF3),
                Color(0xFFE0DDE8),
                Color(0xFFEEECF3),
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}
