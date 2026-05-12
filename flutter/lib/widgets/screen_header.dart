// ScreenHeader — the top-of-screen identity strip used on Home,
// Friends, Shop, and any tab that wants the greeting + status cluster
// rather than a plain AppBar.
//
// Layout:
//   left  — greeting `caption` + username `h1`
//   right — coins pill + streak pill + bell icon (any of these
//           controlled by the constructor's bool flags / values)
//
// The pills are PillChip-styled; the bell is a circular surfaceHi
// button with an optional red unread dot.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pill_chip.dart';

class ScreenHeader extends StatelessWidget {
  final String greeting;
  final String username;
  final int? coins;
  final int? streakDays;
  final bool hasUnreadNotifications;
  final VoidCallback? onCoinsTap;
  final VoidCallback? onStreakTap;
  final VoidCallback? onBellTap;
  final VoidCallback? onAddCoinsTap;

  /// When true, the coins pill renders a trailing "+" affordance that
  /// fires [onAddCoinsTap]. Used on the Shop screen header.
  final bool showAddCoins;

  const ScreenHeader({
    super.key,
    required this.greeting,
    required this.username,
    this.coins,
    this.streakDays,
    this.hasUnreadNotifications = false,
    this.onCoinsTap,
    this.onStreakTap,
    this.onBellTap,
    this.onAddCoinsTap,
    this.showAddCoins = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.md,
          Spacing.lg,
          Spacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: AppText.caption),
                  const SizedBox(height: 2),
                  Text(
                    username,
                    style: AppText.h1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (coins != null) _CoinsPill(
              coins: coins!,
              showAdd: showAddCoins,
              onTap: onCoinsTap,
              onAddTap: onAddCoinsTap,
            ),
            if (streakDays != null && streakDays! > 0) ...[
              const SizedBox(width: Spacing.sm),
              GestureDetector(
                onTap: onStreakTap,
                child: PillChip(
                  label: streakDays.toString(),
                  icon: Icons.local_fire_department,
                  color: AppColors.flame,
                  variant: PillVariant.outlined,
                ),
              ),
            ],
            const SizedBox(width: Spacing.sm),
            _BellButton(
              onTap: onBellTap,
              hasUnread: hasUnreadNotifications,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinsPill extends StatelessWidget {
  final int coins;
  final bool showAdd;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  const _CoinsPill({
    required this.coins,
    required this.showAdd,
    this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceHi,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, size: 16, color: AppColors.gold),
              const SizedBox(width: 4),
              Text(
                coins.toString(),
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (showAdd) ...[
                const SizedBox(width: Spacing.xs),
                GestureDetector(
                  onTap: onAddTap,
                  child: const Icon(
                    Icons.add_circle,
                    size: 18,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool hasUnread;

  const _BellButton({required this.onTap, required this.hasUnread});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.surfaceHi,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.notifications_outlined, size: 20),
            ),
          ),
        ),
        if (hasUnread)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.bg, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
