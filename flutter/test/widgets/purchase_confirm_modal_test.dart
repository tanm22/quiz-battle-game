import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import 'package:quiz_battle/proto/quiz.pbgrpc.dart';
import 'package:quiz_battle/providers/coins_state.dart';
import 'package:quiz_battle/services/coins_service.dart';
import 'package:quiz_battle/widgets/purchase_confirm_modal.dart';

/// CoinsService with a hot-pluggable purchase result. Constructor takes
/// any client + opts builder because the only call we exercise is
/// [purchase], which we override here.
class _FakeCoinsService extends CoinsService {
  _FakeCoinsService(this._next)
      : super(ScoringServiceClient(ClientChannel('localhost', port: 1)),
            CallOptions.new);

  PurchaseShopItemResponse _next;

  set next(PurchaseShopItemResponse r) => _next = r;

  Throwable? throwOnPurchase;

  @override
  Future<PurchaseShopItemResponse> purchase(String itemId, String idem) async {
    if (throwOnPurchase != null) throw throwOnPurchase!;
    return _next;
  }
}

typedef Throwable = Object;

ShopItem _frame() => ShopItem()
  ..id = 'frame.gold'
  ..kind = 'cosmetic.avatar_frame'
  ..name = 'Gold'
  ..description = 'Premium gold frame'
  ..priceCoins = Int64(500)
  ..active = true;

Widget _wrap({required _FakeCoinsService fake}) {
  return ProviderScope(
    overrides: [coinsServiceProvider.overrideWithValue(fake)],
    child: MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<bool>(
                context: ctx,
                builder: (_) => PurchaseConfirmModal(item: _frame()),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

PurchaseShopItemResponse _failure(String code) => PurchaseShopItemResponse()
  ..success = false
  ..errorCode = code;

PurchaseShopItemResponse _success() => PurchaseShopItemResponse()
  ..success = true
  ..newBalance = Int64(500);

void main() {
  Future<void> openModal(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('INSUFFICIENT renders the not-enough-coins message',
      (tester) async {
    final fake = _FakeCoinsService(_failure('INSUFFICIENT'));
    await tester.pumpWidget(_wrap(fake: fake));
    await openModal(tester);
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not enough coins'), findsOneWidget);
  });

  testWidgets('INACTIVE renders the unavailable message', (tester) async {
    final fake = _FakeCoinsService(_failure('INACTIVE'));
    await tester.pumpWidget(_wrap(fake: fake));
    await openModal(tester);
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(find.textContaining("isn't available"), findsOneWidget);
  });

  testWidgets('WEEKLY_CAP renders the streak-freeze message', (tester) async {
    final fake = _FakeCoinsService(_failure('WEEKLY_CAP'));
    await tester.pumpWidget(_wrap(fake: fake));
    await openModal(tester);
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('streak freeze this week'), findsOneWidget);
  });

  testWidgets('UNKNOWN renders the not-found message', (tester) async {
    final fake = _FakeCoinsService(_failure('UNKNOWN'));
    await tester.pumpWidget(_wrap(fake: fake));
    await openModal(tester);
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(find.textContaining("couldn't find that item"), findsOneWidget);
  });

  testWidgets('success closes the dialog with true', (tester) async {
    final fake = _FakeCoinsService(_success());
    await tester.pumpWidget(_wrap(fake: fake));
    await openModal(tester);
    expect(find.byType(PurchaseConfirmModal), findsOneWidget);
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    // Dialog gone after a successful purchase.
    expect(find.byType(PurchaseConfirmModal), findsNothing);
  });

  testWidgets('gRPC exceptions surface as a generic error', (tester) async {
    final fake = _FakeCoinsService(_success())
      ..throwOnPurchase = GrpcError.unavailable('boom');
    await tester.pumpWidget(_wrap(fake: fake));
    await openModal(tester);
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't complete the purchase"), findsOneWidget);
  });
}
