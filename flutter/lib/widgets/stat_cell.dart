// StatCell — square-ish stat card.
//
// Vertical stack: icon → big tabular number → muted label.
// Used in 3-up and 5-up rows on Home, Match Results, Profile.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatCell extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String value;
  final String label;
  final Color? valueColor;
  final EdgeInsetsGeometry padding;

  const StatCell({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.valueColor,
    this.padding = const EdgeInsets.all(Spacing.md),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceHi,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
          const SizedBox(height: Spacing.sm),
          Text(
            value,
            style: AppText.statBig.copyWith(color: valueColor ?? AppColors.text),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppText.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
