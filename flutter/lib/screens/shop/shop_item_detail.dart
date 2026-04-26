import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../proto/quiz.pb.dart';
import '../../providers/coins_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coin_balance_chip.dart';
import '../../widgets/purchase_confirm_modal.dart';
import '../coin_ledger_screen.dart';

/// Detail view for a single shop item — full description, price, current
/// ownership state, and the Buy button.
///
/// The Buy button opens [PurchaseConfirmModal]. The button's enabled
/// state is per-kind:
///
///  * Cosmetics (`cosmetic.avatar_frame` / `cosmetic.name_color`) — shows
///    "Equipped" / "Already owned" once the user owns it; further taps
///    are blocked. This is the legacy `ownedCosmetics` array on the user
///    document.
///  * Streak freeze (`streak_freeze.weekly`) — shows "Already held" while
///    `streakFreezeHeld` is true; the server caps purchases at one per
///    ISO week so a second tap would just return `WEEKLY_CAP`.
///  * Reroll topic (`reroll_topic`) — always buyable; charges stack on
///    purchase.
///  * Premium trial (`premium_trial`) — always buyable; the consumer
///    extends `planExpiresAt` from the existing expiry (ADR-0003), so
///    overlapping purchases stack days rather than overwriting time.
class ShopItemDetail extends ConsumerWidget {
  const ShopItemDetail({super.key, required this.item});

  final ShopItem item;

  /// Per-kind "already obtained" state. Returns `null` if the item is
  /// always buyable (reroll, premium trial), `'Equipped'` for the
  /// currently-equipped cosmetic, or another short status string when
  /// further purchases should be blocked.
  String? _statusFor(GetShopInventoryResponse inv) {
    switch (item.kind) {
      case 'cosmetic.avatar_frame':
      case 'cosmetic.name_color':
        if (inv.equippedCosmeticId == item.id ||
            inv.equippedNameColor == item.id) {
          return 'Equipped';
        }
        if (inv.ownedCosmetics.contains(item.id)) return 'Already owned';
        return null;
      case 'streak_freeze':
        return inv.streakFreezeHeld ? 'Already held' : null;
      // reroll_topic and premium_trial intentionally fall through —
      // both stack rather than block on prior ownership.
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(shopInventoryProvider).value;
    final status = inventory == null ? null : _statusFor(inventory);
    final blocked = status != null;
    final equipped = status == 'Equipped';

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: CoinBalanceChip(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CoinLedgerScreen()),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              item.description,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.monetization_on, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${item.priceCoins.toInt()} coins',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                ),
                onPressed: blocked
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => PurchaseConfirmModal(item: item),
                        );
                        if (ok == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Purchased!')),
                          );
                        }
                      },
                icon: Icon(equipped
                    ? Icons.check_circle
                    : (blocked ? Icons.inventory : Icons.shopping_cart)),
                label: Text(status ?? 'Buy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
