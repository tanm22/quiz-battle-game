// PillChip — small status pill, three variants.
//
//   solid    — filled with `color`, white text
//   soft     — 12% alpha bg + full-color text + 1px alpha border
//   outlined — transparent bg, 1px `color` border, color text
//
// Used everywhere a single fact wants emphasis: rating, tier, streak,
// "ONLINE", "PRO", "NEW", difficulty, count badges.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum PillVariant { solid, soft, outlined }

class PillChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final PillVariant variant;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const PillChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.variant = PillVariant.soft,
    this.iconSize = 14,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Spacing.md,
      vertical: 5,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color borderColor;
    switch (variant) {
      case PillVariant.solid:
        bg = color;
        fg = _onColor(color);
        borderColor = Colors.transparent;
      case PillVariant.soft:
        bg = color.withValues(alpha: 0.14);
        fg = color;
        borderColor = color.withValues(alpha: 0.30);
      case PillVariant.outlined:
        bg = Colors.transparent;
        fg = color;
        borderColor = color;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppText.micro.copyWith(color: fg),
          ),
        ],
      ),
    );
  }

  /// Foreground color for solid variant — black text on light yellows,
  /// white otherwise. Picks based on relative luminance.
  static Color _onColor(Color c) {
    return c.computeLuminance() > 0.6 ? AppColors.textOnGold : AppColors.text;
  }
}
