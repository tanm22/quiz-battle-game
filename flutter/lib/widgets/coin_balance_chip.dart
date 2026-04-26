import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/coins_state.dart';
import '../theme/app_theme.dart';

/// Pill-shaped widget that renders the authenticated user's current coin
/// balance. Reads [coinBalanceProvider] and renders one of three states
/// via [AsyncValue.when]:
///
///  * Loading — small inline spinner.
///  * Data    — coin icon + balance number.
///  * Error   — red error icon (the chip stays visible so the layout
///              doesn't reflow when an RPC blip resolves).
///
/// The optional [onTap] makes the chip tappable; the ledger screen wires
/// this in PR 7. When [onTap] is null, the chip is a non-interactive
/// label.
class CoinBalanceChip extends ConsumerWidget {
  const CoinBalanceChip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(coinBalanceProvider);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.orangeBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          balance.when(
            loading: () => const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
            ),
            error: (_, _) => const Icon(Icons.error_outline, size: 14, color: AppColors.danger),
            data: (n) => Text(
              '$n',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: pill,
    );
  }
}
