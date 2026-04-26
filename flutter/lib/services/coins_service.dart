import 'package:grpc/grpc.dart';

import '../proto/quiz.pbgrpc.dart';
import 'quiz_service.dart';

/// Thin typed wrapper around the auto-generated [ScoringServiceClient] for
/// every coins-and-shop RPC the Flutter app needs. The shared
/// [QuizService] singleton already owns the channel + JWT call-options, so
/// this layer only adapts request/response shapes — it does not open its
/// own gRPC connection.
class CoinsService {
  CoinsService(this._client, this._optsBuilder);

  /// Convenience constructor that binds to the shared [QuizService]
  /// singleton. Prefer this in production; tests inject their own
  /// [_client] via the primary constructor.
  factory CoinsService.fromQuizService(QuizService qs) =>
      CoinsService(qs.scoring, () => qs.authCallOptions);

  final ScoringServiceClient _client;
  final CallOptions Function() _optsBuilder;

  /// Current coin balance for the authenticated user.
  Future<int> balance() async {
    final r =
        await _client.getCoinBalance(GetCoinBalanceRequest(), options: _optsBuilder());
    return r.balance.toInt();
  }

  /// Catalog of every shop item the user can browse. Active and inactive
  /// items are returned; the UI hides inactive ones.
  Future<List<ShopItem>> catalog() async {
    final r =
        await _client.getShopCatalog(GetShopCatalogRequest(), options: _optsBuilder());
    return r.items;
  }

  /// Inventory snapshot — owned cosmetics, equipped IDs, reroll charges,
  /// streak-freeze flag, balance — used by the shop grid and the equip
  /// screen.
  Future<GetShopInventoryResponse> inventory() async {
    return _client.getShopInventory(GetShopInventoryRequest(), options: _optsBuilder());
  }

  /// Lifetime ledger entries newest-first, paged by an opaque cursor.
  /// Pass an empty [pageToken] for the first page.
  Future<GetCoinLedgerResponse> ledger({int pageSize = 25, String pageToken = ''}) {
    return _client.getCoinLedger(
      GetCoinLedgerRequest()
        ..pageSize = pageSize
        ..pageToken = pageToken,
      options: _optsBuilder(),
    );
  }

  /// Buy a shop item. [idempotencyKey] should be a fresh UUID generated
  /// once per user-initiated purchase action — passing the same key on a
  /// retry hits the server's replay fast-path and returns the original
  /// result without double-debiting.
  Future<PurchaseShopItemResponse> purchase(String itemId, String idempotencyKey) {
    return _client.purchaseShopItem(
      PurchaseShopItemRequest()
        ..itemId = itemId
        ..idempotencyKey = idempotencyKey,
      options: _optsBuilder(),
    );
  }

  /// Activate an owned cosmetic (avatar frame or name color).
  Future<EquipCosmeticResponse> equip(String itemId) {
    return _client.equipCosmetic(
      EquipCosmeticRequest()..itemId = itemId,
      options: _optsBuilder(),
    );
  }

  /// Spend a reroll charge during a match. Returns the post-decrement
  /// charge count (or `NO_CHARGES`).
  Future<ConsumeRerollResponse> consumeReroll(String roomId, String roundId) {
    return _client.consumeReroll(
      ConsumeRerollRequest()
        ..roomId = roomId
        ..roundId = roundId,
      options: _optsBuilder(),
    );
  }
}
