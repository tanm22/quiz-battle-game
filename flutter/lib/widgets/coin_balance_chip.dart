import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/coins_state.dart';
import '../theme/app_theme.dart';

/// Pill-shaped widget that renders the authenticated user's current coin
/// balance.
///
/// Two render modes:
///
///  * `CoinBalanceChip()` — reads [coinBalanceProvider] and surfaces
///    its loading / data / error state via [AsyncValue.when]. Use this
///    on screens that don't already have the balance in hand (shop,
///    detail, ledger).
///
///  * `CoinBalanceChip(initialBalance: n)` — renders [n] immediately
///    without waiting for the provider's first frame. Use this on
///    screens that already have a cached balance from another payload
///    (the home screen reads it off `GetHomeScreenData.profile.coins`).
///    Avoids a redundant `GetCoinBalance` round-trip on a hot path that
///    already has the number. The provider is still watched, so a later
///    refetch (e.g. via [invalidateCoinState] after a purchase) updates
///    the chip without manual wiring.
///
/// The optional [onTap] makes the chip tappable; PR 7 wires it to push
/// the ledger screen.
class CoinBalanceChip extends ConsumerWidget {
  const CoinBalanceChip({super.key, this.onTap, this.initialBalance});

  final VoidCallback? onTap;

  /// Optional seed value to render before the provider's first frame
  /// arrives (or as a fallback on transient error). When non-null the
  /// chip never shows a spinner on first paint.
  final int? initialBalance;

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
            loading: () => initialBalance != null
                ? _balanceText(initialBalance!)
                : const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: AppColors.primary),
                  ),
            // On transient error, fall back to the seed if we have it —
            // better than an error icon when the user already saw a valid
            // number on the previous frame.
            error: (_, _) => initialBalance != null
                ? _balanceText(initialBalance!)
                : const Icon(Icons.error_outline,
                    size: 14, color: AppColors.danger),
            data: _balanceText,
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

  Widget _balanceText(int n) => Text(
        '$n',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
}
