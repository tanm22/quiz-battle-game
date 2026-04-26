import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proto/quiz.pb.dart';
import '../services/coins_service.dart';
import '../services/quiz_service.dart';

/// Singleton [CoinsService] bound to the shared gRPC channel + JWT call
/// options exposed by [QuizService]. Tests override this with a fake.
final coinsServiceProvider = Provider<CoinsService>((ref) {
  return CoinsService.fromQuizService(QuizService());
});

/// Cached coin balance. Invalidate after every action that mutates it
/// (purchase, claim daily reward) so the [CoinBalanceChip] refetches.
final coinBalanceProvider = FutureProvider<int>((ref) async {
  return ref.read(coinsServiceProvider).balance();
});

/// Whole shop catalog, fetched once and cached. Refetches on
/// `ref.invalidate(shopCatalogProvider)` (e.g. the Retry button on the
/// error state).
final shopCatalogProvider = FutureProvider<List<ShopItem>>((ref) async {
  return ref.read(coinsServiceProvider).catalog();
});

/// User inventory — owned cosmetics, equipped IDs, reroll charges,
/// streak-freeze flag, balance. Invalidate after purchase / equip so the
/// shop grid re-renders the right "Owned" / "Equipped" indicators.
final shopInventoryProvider = FutureProvider<GetShopInventoryResponse>((ref) async {
  return ref.read(coinsServiceProvider).inventory();
});
