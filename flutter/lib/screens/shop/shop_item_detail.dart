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
/// In PR 6 the Buy button opens a placeholder dialog. PR 7 swaps that for
/// [PurchaseConfirmModal]; the rest of this screen is unchanged.
class ShopItemDetail extends ConsumerWidget {
  const ShopItemDetail({super.key, required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(shopInventoryProvider).value;
    final owned = inventory?.ownedCosmetics.contains(item.id) ?? false;
    final equipped = inventory != null &&
        (inventory.equippedCosmeticId == item.id ||
            inventory.equippedNameColor == item.id);

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
                onPressed: equipped || owned
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
                    : (owned ? Icons.inventory : Icons.shopping_cart)),
                label: Text(equipped
                    ? 'Equipped'
                    : (owned ? 'Already owned' : 'Buy')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
