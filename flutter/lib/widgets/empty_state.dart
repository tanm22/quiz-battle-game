import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// EmptyState — the SpeakX-style "nothing here yet" affordance:
/// a tinted-circle hero icon, a short headline (h3-weight), a softer
/// body line, and an optional primary CTA. Animated entrance keeps
/// it from feeling like a dead screen.
///
/// Used by every list / data screen (match history, coin ledger,
/// referrals, leaderboard, analytics) so the empty surface reads as
/// part of the same design language and the user always knows what
/// to do next.
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
    this.padding = const EdgeInsets.all(32),
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
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: 0.12),
                border: Border.all(
                  color: tint.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(icon, size: 44, color: tint),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.elasticOut,
                  duration: 600.ms,
                ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
            ],
            if (actionLabel != null && onActionTap != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onActionTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tint,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 12),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.button),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
            ],
          ],
        ),
      ),
    );
  }
}
