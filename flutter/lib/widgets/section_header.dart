import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// SectionHeader — the consistent "Title of next block + optional
/// trailing action" affordance used throughout the app, modeled on
/// the patterns SpeakX uses to anchor each scrollable section
/// (e.g. "Continue learning · See all", "Top players · Leaderboard").
///
/// - [title] is the bold left-aligned section name.
/// - [icon] (optional) renders a small badge before the title; useful
///   for dense screens where the section's nature isn't obvious from
///   the title alone (a leaderboard icon next to "Top Players").
/// - [actionLabel] + [onActionTap] (optional) render a coral
///   right-aligned link button — typically "See all" / "View all".
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.actionLabel,
    this.onActionTap,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: iconColor ?? AppColors.gold),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (actionLabel != null && onActionTap != null)
            GestureDetector(
              onTap: onActionTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
