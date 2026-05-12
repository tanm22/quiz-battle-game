// AppCard — base card surface used across the revamp.
//
// Container with:
//   - `surface` bg (overridable)
//   - radLg corners
//   - 1px `border`
//   - padding `lg`
//
// Optional [glowColor] paints a soft BoxShadow around the card. Used
// on hero cards (Coins, Streak banner) for visual lift.
//
// Optional [gradientTint] overlays a top-left radial tint behind the
// child — gives the card a subtle "lit corner" without making the
// whole card colorful. Useful for the gold premium banner, the coral
// streak card, etc.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final Color? glowColor;
  final Color? gradientTint;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.color,
    this.borderColor,
    this.glowColor,
    this.gradientTint,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(Radii.lg);

    Widget content = Stack(
      children: [
        // Top-left radial tint behind the child.
        if (gradientTint != null)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.1,
                  colors: [
                    gradientTint!.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.6],
                ),
              ),
            ),
          ),
        Padding(padding: padding, child: child),
      ],
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: content,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: glowColor == null
            ? null
            : [
                BoxShadow(
                  color: glowColor!.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(borderRadius: radius, child: content),
    );
  }
}
