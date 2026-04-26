import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proto/quiz.pb.dart';
import '../services/coins_service.dart';
import '../services/quiz_service.dart';

/// Singleton [CoinsService] bound to the shared gRPC channel + JWT call
/// options exposed by [QuizService]. Tests override this with a fake.
final coinsServiceProvider = Provider<CoinsService>((ref) {
  return CoinsService.fromQuizService(QuizService());
});

/// Cached coin balance. Invalidate via [invalidateCoinState] after every
/// action that mutates it (purchase, claim daily reward) so the
/// [CoinBalanceChip] refetches.
///
/// Uses `ref.watch` (not `ref.read`) so overriding [coinsServiceProvider]
/// in tests with a fake actually propagates here — `ref.read` inside a
/// FutureProvider body skips the subscription and returns the original
/// service.
final coinBalanceProvider = FutureProvider<int>((ref) async {
  return ref.watch(coinsServiceProvider).balance();
});

/// Whole shop catalog, fetched once and cached. Refetches on
/// `ref.invalidate(shopCatalogProvider)` (e.g. the Retry button on the
/// error state).
///
/// The service already filters inactive items so every UI consumer sees
/// the same active-only list — no need for callers to repeat the
/// `where((it) => it.active)` filter.
final shopCatalogProvider = FutureProvider<List<ShopItem>>((ref) async {
  return ref.watch(coinsServiceProvider).catalog();
});

/// User inventory — owned cosmetics, equipped IDs, reroll charges,
/// streak-freeze flag, balance. Invalidate after purchase / equip so the
/// shop grid re-renders the right "Owned" / "Equipped" indicators.
final shopInventoryProvider = FutureProvider<GetShopInventoryResponse>((ref) async {
  return ref.watch(coinsServiceProvider).inventory();
});

/// Invalidates every coin-related provider in one call. Use after any
/// action that mutates server-side coin / inventory state (purchase,
/// equip, daily reward claim) so the chip and shop grid both refetch.
/// Centralised so callers can't forget one of the providers.
void invalidateCoinState(WidgetRef ref) {
  ref.invalidate(coinBalanceProvider);
  ref.invalidate(shopInventoryProvider);
}
