import 'package:async/async.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import 'package:quiz_battle/proto/quiz.pbgrpc.dart';
import 'package:quiz_battle/services/coins_service.dart';

/// Stand-in for `ResponseFuture<R>` that resolves immediately with a
/// pre-baked value. Avoids constructing a real `ClientCall` (and the
/// channel infrastructure that comes with it) — the tests only await
/// the value, never inspect headers / trailers.
class _ImmediateResponseFuture<R> extends DelegatingFuture<R>
    implements ResponseFuture<R> {
  _ImmediateResponseFuture(R value) : super(Future.value(value));

  @override
  Future<void> cancel() async {}

  @override
  Future<Map<String, String>> get headers => Future.value(const {});

  @override
  Future<Map<String, String>> get trailers => Future.value(const {});
}

/// `ScoringServiceClient` subclass that captures the request arg of
/// every method we test. The base ctor needs a real `ClientChannel`,
/// but since every method is overridden no actual gRPC call is made.
class _RecordingScoringClient extends ScoringServiceClient {
  _RecordingScoringClient()
      : super(ClientChannel('localhost', port: 1,
            options: const ChannelOptions(
                credentials: ChannelCredentials.insecure())));

  PurchaseShopItemRequest? capturedPurchase;
  GetShopCatalogResponse? nextCatalog;

  @override
  ResponseFuture<PurchaseShopItemResponse> purchaseShopItem(
    PurchaseShopItemRequest request, {
    CallOptions? options,
  }) {
    capturedPurchase = request;
    return _ImmediateResponseFuture(
      PurchaseShopItemResponse()
        ..success = true
        ..newBalance = Int64(0),
    );
  }

  @override
  ResponseFuture<GetShopCatalogResponse> getShopCatalog(
    GetShopCatalogRequest request, {
    CallOptions? options,
  }) {
    return _ImmediateResponseFuture(nextCatalog ?? GetShopCatalogResponse());
  }
}

CoinsService _service(_RecordingScoringClient client) =>
    CoinsService(client, () => CallOptions());

void main() {
  test('purchase forwards itemId and idempotencyKey verbatim', () async {
    final client = _RecordingScoringClient();
    await _service(client)
        .purchase('frame.gold', '11111111-2222-3333-4444-555555555555');

    expect(client.capturedPurchase, isNotNull);
    expect(client.capturedPurchase!.itemId, 'frame.gold');
    expect(client.capturedPurchase!.idempotencyKey,
        '11111111-2222-3333-4444-555555555555');
  });

  test('purchase replays the same idempotencyKey across retries', () async {
    final client = _RecordingScoringClient();
    final svc = _service(client);
    const idem = 'fixed-key-for-retry';

    await svc.purchase('reroll.topic', idem);
    final first = client.capturedPurchase!.idempotencyKey;

    // A retry with the same key must hit the server with the same key
    // — that's how the replay fast-path works. If the modal regenerates
    // the UUID on rebuild, this property breaks at the call-site, not
    // here; this test guards the service against silently mutating it.
    await svc.purchase('reroll.topic', idem);
    expect(client.capturedPurchase!.idempotencyKey, first);
    expect(client.capturedPurchase!.idempotencyKey, idem);
  });

  test('catalog filters inactive items at the service boundary', () async {
    final client = _RecordingScoringClient();
    final active = ShopItem()
      ..id = 'frame.gold'
      ..name = 'Gold'
      ..kind = 'cosmetic.avatar_frame'
      ..active = true
      ..priceCoins = Int64(500);
    final inactive = ShopItem()
      ..id = 'frame.retired'
      ..name = 'Retired'
      ..kind = 'cosmetic.avatar_frame'
      ..active = false
      ..priceCoins = Int64(99999);
    client.nextCatalog = GetShopCatalogResponse()
      ..items.addAll([active, inactive]);

    final items = await _service(client).catalog();
    expect(items.map((i) => i.id), ['frame.gold']);
  });

  test('catalog(includeInactive: true) returns the full set', () async {
    final client = _RecordingScoringClient();
    final active = ShopItem()
      ..id = 'a'
      ..active = true;
    final inactive = ShopItem()
      ..id = 'b'
      ..active = false;
    client.nextCatalog = GetShopCatalogResponse()
      ..items.addAll([active, inactive]);

    final items = await _service(client).catalog(includeInactive: true);
    expect(items.map((i) => i.id), ['a', 'b']);
  });
}
