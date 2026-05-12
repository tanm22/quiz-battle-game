// ProgressBar — animated horizontal bar.
//
// Track `surfaceHi`, fill colored (`primary` by default), animates from
// 0 to [value] in 800ms ease-out via TweenAnimationBuilder. Stateful
// only inside the tween; the outer widget rebuilds when [value]
// changes and animates from the previous tween target to the new one.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  /// 0.0 - 1.0. Clamped on render.
  final double value;
  final double height;
  final Color? color;
  final Color? trackColor;
  final BorderRadius? borderRadius;
  final Duration duration;

  const ProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
    this.trackColor,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = color ?? AppColors.primary;
    final radius = borderRadius ?? BorderRadius.circular(Radii.pill);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        color: trackColor ?? AppColors.surfaceHi,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            return Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: t,
                child: Container(
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: radius,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
