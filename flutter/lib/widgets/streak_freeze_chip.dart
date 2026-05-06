import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/coins_state.dart';
import '../theme/app_theme.dart';

/// Compact chip rendered next to the streak counter that signals "you
/// have a freeze ready, you're protected from one missed day this week."
/// Hidden when [GetShopInventoryResponse.streakFreezeHeld] is false so
/// the home surface stays uncluttered for users without one.
class StreakFreezeChip extends ConsumerWidget {
  const StreakFreezeChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(shopInventoryProvider);
    final held = inv.value?.streakFreezeHeld ?? false;
    if (!held) return const SizedBox.shrink();
    return Tooltip(
      message: 'Streak freeze active — one missed day this week is protected.',
      child: Container(
        key: const Key('streak-freeze-chip'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.accentBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.accent.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.ac_unit, size: 12, color: AppColors.accent),
            SizedBox(width: 4),
            Text('Freeze',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                )),
          ],
        ),
      ),
    );
  }
}
