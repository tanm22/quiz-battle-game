import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// EmptyState — the "nothing here yet" affordance: a tinted-circle hero
/// icon, a short headline, a softer body line, and an optional primary
/// CTA. Animated entrance keeps it from feeling like a dead screen.
///
/// Brief spec (revamp):
///   - 80×80 tinted circle (was 96)
///   - 32px icon (was 44)
///   - Title in `h2` (22 / w700)
///   - Body in `body` muted
///   - CTA as a [FilledButton] inheriting the new theme's primary styling
///
/// Constructor surface is unchanged — every existing call-site keeps
/// working.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.body,
    this.actionLabel,
    this.onActionTap,
    this.padding = const EdgeInsets.all(Spacing.xxxl),
  });

  @override
  Widget build(BuildContext context) {
    final tint = iconColor ?? AppColors.primary;
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: 0.12),
                border: Border.all(
                  color: tint.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, size: 32, color: tint),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.elasticOut,
                  duration: 600.ms,
                ),
            const SizedBox(height: Spacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.h2,
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
            if (body != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.textMuted),
              ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
            ],
            if (actionLabel != null && onActionTap != null) ...[
              const SizedBox(height: Spacing.xl),
              FilledButton(
                onPressed: onActionTap,
                style: FilledButton.styleFrom(
                  backgroundColor: tint,
                  foregroundColor: AppColors.textOnPri,
                ),
                child: Text(actionLabel!),
              ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
            ],
          ],
        ),
      ),
    );
  }
}
