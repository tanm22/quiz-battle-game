import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../proto/quiz.pb.dart';
import '../../providers/coins_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coin_balance_chip.dart';
import '../coin_ledger_screen.dart';
import 'shop_item_detail.dart';

/// Hard-coded category → kind mapping. Mirrors the kinds defined in
/// `pkg/coins/shop/catalog.go` (KindAvatarFrame / KindNameColor /
/// KindStreakFreeze / KindRerollTopic / KindPremiumTrial). New SKU kinds
/// land here when they ship.
const Map<String, List<String>> _categories = {
  'Cosmetics': ['cosmetic.avatar_frame', 'cosmetic.name_color'],
  'Boosts': ['streak_freeze', 'reroll_topic'],
  'Premium': ['premium_trial'],
};

/// Browsable shop catalog with three category tabs (Cosmetics, Boosts,
/// Premium). Each tab grids out the catalog items whose `kind` is in
/// the tab's list. Tapping a card pushes [ShopItemDetail].
///
/// The Buy button on [ShopItemDetail] opens [PurchaseConfirmModal]
/// directly — there is no placeholder path.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(shopCatalogProvider);
    final inventory = ref.watch(shopInventoryProvider);

    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Coin Shop'),
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
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [for (final name in _categories.keys) Tab(text: name)],
          ),
        ),
        body: catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            message: '$e',
            onRetry: () => ref.invalidate(shopCatalogProvider),
          ),
          data: (items) => Column(
            children: [
              // If inventory failed, the grid would otherwise silently
              // render every cosmetic without an Owned/Equipped chip —
              // indistinguishable from "the user owns nothing." Surface
              // a non-blocking banner with a Retry so the user knows
              // the indicators are stale and can recover.
              if (inventory.hasError)
                _InventoryErrorBanner(
                  onRetry: () => ref.invalidate(shopInventoryProvider),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final entry in _categories.entries)
                      _CategoryGrid(
                        items: items
                            .where((it) => entry.value.contains(it.kind))
                            .toList(),
                        inventory: inventory.value,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.items, required this.inventory});

  final List<ShopItem> items;
  final GetShopInventoryResponse? inventory;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Nothing here yet — check back soon.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 180,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _ShopCard(item: items[i], inventory: inventory),
    );
  }
}

/// Non-blocking banner shown when [shopInventoryProvider] is in the
/// error state. The grid still renders so the user can browse, but the
/// banner makes it clear that Owned / Equipped indicators may be wrong
/// or missing — and gives them a one-tap retry.
class _InventoryErrorBanner extends StatelessWidget {
  const _InventoryErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.danger.withAlpha(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Couldn't load your inventory — Owned / Equipped indicators may be missing.",
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.item, required this.inventory});

  final ShopItem item;
  final GetShopInventoryResponse? inventory;

  /// Status indicator state: which chip (if any) we render in the
  /// top-right corner of the card.
  ///
  ///  * `equipped` — currently active (avatar frame or name color
  ///    matches the user's equipped slot).
  ///  * `owned`    — in the inventory but not equipped.
  ///  * `null`     — buyable; show the cart icon.
  String? _status() {
    final inv = inventory;
    if (inv == null) return null;
    if (inv.equippedCosmeticId == item.id || inv.equippedNameColor == item.id) {
      return 'Equipped';
    }
    if (inv.ownedCosmetics.contains(item.id)) return 'Owned';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status();
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.card,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ShopItemDetail(item: item)),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (status != null)
                    _StatusChip(label: status, equipped: status == 'Equipped')
                  else
                    const Icon(Icons.shopping_cart_outlined,
                        size: 16, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.monetization_on, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${item.priceCoins.toInt()}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.equipped});

  final String label;
  final bool equipped;

  @override
  Widget build(BuildContext context) {
    final color = equipped ? AppColors.success : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: AppColors.danger),
            const SizedBox(height: 8),
            const Text('Could not load the shop',
                style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
