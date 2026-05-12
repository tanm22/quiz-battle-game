import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// SectionHeader — section title + optional trailing action.
///
/// Brief spec:
///   - Top gap `xxl`, bottom `sm`
///   - Optional leading icon (primary by default)
///   - Title rendered in `h3` (18 / w600)
///   - Optional trailing widget OR the legacy `actionLabel`/`onActionTap`
///     "See all" link
///
/// Compatibility note:
///   The previous constructor took `actionLabel` + `onActionTap` for a
///   "See all >" link. Both still work. A new `trailing` slot accepts an
///   arbitrary widget when callers want richer affordances (a badge, a
///   filter chip, an icon button). When both `trailing` and
///   `actionLabel` are supplied, `trailing` wins.
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.actionLabel,
    this.onActionTap,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final pad = padding ??
        const EdgeInsets.only(top: Spacing.xxl, bottom: Spacing.sm);

    Widget? trailingChild = trailing;
    if (trailingChild == null && actionLabel != null && onActionTap != null) {
      trailingChild = TextButton(
        onPressed: onActionTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xs,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              actionLabel!,
              style: AppText.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.primary),
          ],
        ),
      );
    }

    return Padding(
      padding: pad,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
            const SizedBox(width: Spacing.sm),
          ],
          Expanded(
            child: Text(title, style: AppText.h3),
          ),
          ?trailingChild,
        ],
      ),
    );
  }
}
