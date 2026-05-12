// app_theme.dart — central theme hub.
//
// Tokens were split out (app_colors.dart, typography.dart, spacing.dart)
// during the revamp, but every existing screen still imports this file
// as `import '../theme/app_theme.dart';`. The export directives below
// keep `AppColors`, `AppRadius`, `AppDurations`, `AppGradients`, and the
// helper widgets (`ScaffoldGradientBackground`, `appCardDecoration`,
// `SkeletonBlock`) reachable through a single import.
//
// The Material 3 `ThemeData` builder lives here too. `MaterialApp` in
// main.dart consumes it via `theme: buildAppTheme()`.

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'spacing.dart';
import 'typography.dart';

// Re-export tokens so `import 'theme/app_theme.dart'` is sufficient
// for every existing call-site.
export 'app_colors.dart';
export 'spacing.dart';
export 'typography.dart';

// ─────────────────────────────────────────────────────────────────────
// ThemeData builder — Material 3, dark brightness, brand tokens
// ─────────────────────────────────────────────────────────────────────
//
// Every override here exists to make built-in Material widgets render
// in the revamp palette WITHOUT per-widget edits in screens. Anything
// not overridden falls back to Material's default, which is fine for
// dark theme because the colorScheme above seeds reasonable defaults.

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: AppColors.textOnPri,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.surfaceHi,
    error: AppColors.danger,
    onError: AppColors.text,
    outline: AppColors.border,
    outlineVariant: AppColors.divider,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    dividerColor: AppColors.divider,
    splashColor: AppColors.primaryTint,
    highlightColor: AppColors.primaryTint,

    // System font stack — no Google Fonts dependency per the brief's
    // constraint set. Letter-spacing + tabular figures land on the
    // AppText scale, not the global font family.
    fontFamily: null,

    textTheme: const TextTheme(
      displayLarge: AppText.display,
      displayMedium: AppText.h1,
      displaySmall: AppText.h2,
      headlineLarge: AppText.h1,
      headlineMedium: AppText.h2,
      headlineSmall: AppText.h3,
      titleLarge: AppText.h2,
      titleMedium: AppText.h3,
      titleSmall: AppText.bodyLg,
      bodyLarge: AppText.bodyLg,
      bodyMedium: AppText.body,
      bodySmall: AppText.caption,
      labelLarge: AppText.body,
      labelMedium: AppText.caption,
      labelSmall: AppText.micro,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.h2,
      iconTheme: IconThemeData(color: AppColors.text, size: 24),
    ),

    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.lg)),
        side: BorderSide(color: AppColors.border),
      ),
    ),

    // Material 3 NavigationBar (the new 6-tab bottom nav uses this).
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primaryTint,
      height: 72,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textDim,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppText.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textDim,
        ),
      ),
    ),

    // Kept for any screen still using the old BottomNavigationBar.
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textDim,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showUnselectedLabels: true,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHi,
      selectedColor: AppColors.primaryTint,
      disabledColor: AppColors.surfaceHi,
      labelStyle: AppText.caption.copyWith(color: AppColors.text),
      secondaryLabelStyle: AppText.caption.copyWith(color: AppColors.primary),
      side: const BorderSide(color: AppColors.border),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.pill)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHi,
      hintStyle: AppText.body.copyWith(color: AppColors.textDim),
      labelStyle: AppText.body.copyWith(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPri,
        disabledBackgroundColor: AppColors.surfaceHi,
        disabledForegroundColor: AppColors.textDim,
        textStyle: AppText.h3,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.md),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.lg)),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppText.body.copyWith(fontWeight: FontWeight.w700),
        side: const BorderSide(color: AppColors.primary, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.pill)),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppText.body.copyWith(fontWeight: FontWeight.w700),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPri,
        elevation: 0,
        shadowColor: AppColors.primaryGlow,
        textStyle: AppText.h3,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.md),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.lg)),
        ),
      ),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textMuted,
      labelStyle: AppText.body.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
      unselectedLabelStyle: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceOv,
      contentTextStyle: AppText.body,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceOv,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppText.h2,
      contentTextStyle: AppText.body,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surfaceHi,
      circularTrackColor: AppColors.surfaceHi,
    ),

    iconTheme: const IconThemeData(color: AppColors.text, size: 24),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Helper widgets — kept verbatim from the previous app_theme.dart so
// the screens that already render `ScaffoldGradientBackground`,
// `appCardDecoration`, `SkeletonBlock` keep working unchanged.
// ─────────────────────────────────────────────────────────────────────

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

/// Card decoration matching the revamp surface stack.
BoxDecoration appCardDecoration({Color? borderColor}) => BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.card,
      border: Border.all(color: borderColor ?? AppColors.border),
      boxShadow: const [
        BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2)),
        BoxShadow(color: Color(0x1A000000), blurRadius: 1),
      ],
    );

/// Skeleton loader — three-stop sweep tuned for dark backgrounds.
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
                AppColors.surfaceHi,
                AppColors.surfaceOv,
                AppColors.surfaceHi,
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}
