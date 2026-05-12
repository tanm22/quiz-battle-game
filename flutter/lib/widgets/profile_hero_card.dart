// ProfileHeroCard — the gradient hero block shown at the top of the
// Profile tab. Avatar + username (with optional PRO badge) on the
// left; rating + win-rate chips on the right.
//
// Designed as a self-contained block — drop into any screen with
// `ProfileHeroCard(...)` and it renders the same way everywhere.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_card.dart';
import 'google_style_avatar.dart';
import 'pill_chip.dart';

class ProfileHeroCard extends StatelessWidget {
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final bool isPremium;
  final int rating;
  final int matchesPlayed;
  final int wins;
  final String? tierLabel;
  final Color? tierColor;

  const ProfileHeroCard({
    super.key,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.isPremium = false,
    this.rating = 1200,
    this.matchesPlayed = 0,
    this.wins = 0,
    this.tierLabel,
    this.tierColor,
  });

  @override
  Widget build(BuildContext context) {
    final shownName = (displayName?.isNotEmpty ?? false) ? displayName! : username;
    final winRate = matchesPlayed == 0
        ? 0
        : ((wins / matchesPlayed) * 100).round();

    return AppCard(
      gradientTint: AppColors.primary,
      glowColor: isPremium ? AppColors.gold : null,
      borderColor: isPremium ? AppColors.gold.withValues(alpha: 0.6) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GoogleStyleAvatar(
            name: shownName,
            imageUrl: avatarUrl,
            size: 60,
            borderColor: isPremium ? AppColors.gold : AppColors.primary,
            borderWidth: 2,
            glow: isPremium,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        shownName,
                        style: AppText.h2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPremium) ...[
                      const SizedBox(width: Spacing.sm),
                      const PillChip(
                        label: 'PRO',
                        color: AppColors.gold,
                        variant: PillVariant.solid,
                      ),
                    ],
                  ],
                ),
                if (tierLabel != null) ...[
                  const SizedBox(height: Spacing.xs),
                  PillChip(
                    label: tierLabel!,
                    color: tierColor ?? AppColors.primary,
                    variant: PillVariant.outlined,
                  ),
                ],
                const SizedBox(height: Spacing.sm),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Text(
                      rating.toString(),
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    PillChip(
                      label: '$matchesPlayed played',
                      icon: Icons.sports_esports,
                      color: AppColors.primary,
                      variant: PillVariant.soft,
                    ),
                    const SizedBox(width: Spacing.sm),
                    PillChip(
                      label: '$winRate% wins',
                      icon: Icons.emoji_events,
                      color: AppColors.gold,
                      variant: PillVariant.soft,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
