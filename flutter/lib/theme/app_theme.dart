import 'package:flutter/material.dart';

/// Dark-theme design tokens ported from the reference UI
/// (MANAS-exe/QUIZ_BATTLE_SYSTEM/flutter-app/lib/theme/colors.dart).
///
/// Palette: near-black scaffold (#0D0D1A), dark-navy surfaces (#1A1A2E),
/// coral primary (#C96442), gold accent (#FFB830), green success
/// (#2ECC71), red danger (#E74C3C). Off-white text (#F4F4FC) and
/// graduated muted/dim secondaries for hierarchy on dark surfaces.
///
/// The class names (AppColors, AppRadius, AppGradients, AppDurations)
/// and every public field are unchanged from the previous light-theme
/// version — only the values flip. Every existing screen compiles
/// against the same identifiers and inherits the new look without code
/// edits.

class AppColors {
  AppColors._();

  // -- Brand ----------------------------------------------------------------
  /// Coral primary CTA. Matches reference's `appCoral` (#C96442).
  static const primary = Color(0xFFC96442);
  static const primarySoft = Color(0xFFD97757); // hover / pressed lift
  /// Cyan-blue secondary; brighter than the light-theme cyan so it
  /// reads on a near-black bg.
  static const secondary = Color(0xFF4FC3F7);
  /// Purple accent. Lifted from #6D59C4 → #9B7BD4 for dark-bg contrast.
  static const accent = Color(0xFF9B7BD4);
  static const accentLight = Color(0xFFB6A6E0);
  static const gold = Color(0xFFFFB830);     // reference's appGold
  static const goldDeep = Color(0xFFE59617);

  // -- Background stack -----------------------------------------------------
  static const bg = Color(0xFF0D0D1A);       // scaffold base — appBg
  static const surface = Color(0xFF1A1A2E);  // cards / sheets — appSurface
  static const cardTint = Color(0xFF20203A); // tinted card sub-fill
  static const bgTop = Color(0xFF1F1F36);    // dialogs, modals (lifted)
  static const bgNav = Color(0xFF16162A);    // bottom-nav surface
  // Legacy aliases — older code referenced bgDeep / bgMid before the
  // light-theme rewrite. Keep them resolving to bg so nothing breaks.
  static const bgDeep = bg;
  static const bgMid = bg;

  // -- Borders & dividers ---------------------------------------------------
  static const border = Color(0xFF2A2A45);
  static const borderBright = Color(0xFF3D3D60); // focused / active border

  // -- Text -----------------------------------------------------------------
  /// Primary on-surface text. Off-white (not pure white) reduces glare
  /// on AMOLED panels and matches the reference's body copy.
  static const text = Color(0xFFF4F4FC);
  static const textSecondary = Color(0xFFB5B5CC);
  static const textMuted = Color(0xFF76768F);
  static const textDim = Color(0xFF4A4A66);

  // -- Semantic -------------------------------------------------------------
  static const success = Color(0xFF2ECC71); // reference's appGreen
  static const danger = Color(0xFFE74C3C);  // reference's appRed

  // -- Tinted backgrounds (faint chip / pill fills on dark) -----------------
  /// Each tinted bg is a 10–14% alpha-on-bg approximation of the hue —
  /// strong enough to read as colored on near-black, dim enough not to
  /// fight the foreground icon/text.
  static const accentBg = Color(0xFF2A2647);  // faint purple
  static const goldBg = Color(0xFF2E2818);    // faint gold
  static const silverBg = Color(0xFF1F2228);  // faint silver — dark-tone
  static const bronzeBg = Color(0xFF2A1F14);  // faint bronze — dark-tone
  static const cyanBg = Color(0xFF16252A);    // faint cyan
  static const emeraldBg = Color(0xFF15291F); // faint green
  static const roseBg = Color(0xFF2E1A1B);    // faint red
  static const orangeBg = Color(0xFF2E1F15);  // faint coral

  // -- Medals (leaderboard) -------------------------------------------------
  static const medalGold = gold;
  static const medalSilver = Color(0xFFB0BEC5); // reference's appSilver
  static const medalBronze = Color(0xFFCD7F32); // reference's appBronze
}

class AppRadius {
  AppRadius._();
  // Bumped to align with the reference's 14/16 radii. button +2, card +2.
  static const BorderRadius button = BorderRadius.all(Radius.circular(14));
  static const BorderRadius card = BorderRadius.all(Radius.circular(16));
  static const BorderRadius hero = BorderRadius.all(Radius.circular(20));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

class AppDurations {
  AppDurations._();
  // Stays as-is — these are timing tokens used across micro-interactions
  // and don't depend on light/dark.
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

class AppGradients {
  AppGradients._();

  /// Subtle near-black → dark-navy vertical gradient for the scaffold.
  /// Provides depth without distracting from foreground content.
  static const LinearGradient scaffold = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D0D1A), Color(0xFF15152A)],
  );

  /// Coral CTA gradient. Lighter coral → primary coral, top-left to
  /// bottom-right, for ElevatedButton fills and hero pill buttons.
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD97757), Color(0xFFC96442)],
  );

  /// Hot gold→coral gradient used for premium / tournament emphasis.
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB830), Color(0xFFC96442)],
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

/// Card decoration matching the reference: dark-navy surface, subtle
/// border one shade up, soft shadow tuned for dark backgrounds (alpha
/// ~25–30% black, blur 8 — anything brighter creates a halo on AMOLED).
BoxDecoration appCardDecoration({Color? borderColor}) => BoxDecoration(
  color: AppColors.surface,
  borderRadius: AppRadius.card,
  border: Border.all(color: borderColor ?? AppColors.border),
  boxShadow: const [
    BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x1A000000), blurRadius: 1),
  ],
);

/// Skeleton loader (shimmer) tuned for the dark palette — three
/// stops between two dark-greys so the sweep is visible on near-black
/// without flashing white.
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
                Color(0xFF1F1F36),
                Color(0xFF2A2A45),
                Color(0xFF1F1F36),
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}
