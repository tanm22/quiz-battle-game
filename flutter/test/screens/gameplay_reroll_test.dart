import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import 'package:quiz_battle/proto/quiz.pbgrpc.dart';
import 'package:quiz_battle/services/coins_service.dart';

import 'reroll_test_harness.dart' as harness;

class _FakeCoinsService extends CoinsService {
  _FakeCoinsService()
      : super(ScoringServiceClient(ClientChannel('localhost', port: 1)),
            CallOptions.new);

  int currentCharges = 0;
  int consumeCalls = 0;
  String? lastRoom;
  String? lastRound;

  /// Force consumeReroll to throw a gRPC error (network-error simulation).
  bool throwOnConsume = false;

  /// Force consumeReroll to return a business-error response with this
  /// errorCode instead of the natural success/NO_CHARGES path. Useful for
  /// testing the humanize/snackbar branch.
  String? forceErrorCode;

  @override
  Future<ConsumeRerollResponse> consumeReroll({String roomId = '', String roundId = ''}) async {
    consumeCalls++;
    lastRoom = roomId;
    lastRound = roundId;
    if (throwOnConsume) {
      throw GrpcError.unavailable('boom');
    }
    if (forceErrorCode != null) {
      return ConsumeRerollResponse()
        ..success = false
        ..errorCode = forceErrorCode!;
    }
    if (currentCharges <= 0) {
      return ConsumeRerollResponse()
        ..success = false
        ..errorCode = 'NO_CHARGES';
    }
    currentCharges -= 1;
    return ConsumeRerollResponse()
      ..success = true
      ..chargesRemaining = currentCharges;
  }

  @override
  Future<GetShopInventoryResponse> inventory() async {
    return GetShopInventoryResponse()
      ..rerollCharges = currentCharges
      ..balance = Int64(500);
  }
}

void main() {
  testWidgets('reroll button is hidden when user has 0 charges', (tester) async {
    final fake = _FakeCoinsService()..currentCharges = 0;
    await tester.pumpWidget(harness.wrap(coinsService: fake));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reroll-button')), findsNothing);
  });

  testWidgets('reroll button shown with N charges; tap calls ConsumeReroll',
      (tester) async {
    final fake = _FakeCoinsService()..currentCharges = 2;
    await tester.pumpWidget(harness.wrap(coinsService: fake));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reroll-button')), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // charge count badge

    await tester.tap(find.byKey(const Key('reroll-button')));
    await tester.pumpAndSettle();

    expect(find.text('Use a reroll?'), findsOneWidget);
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    expect(fake.consumeCalls, 1);
  });

  testWidgets('cancel dismisses without calling ConsumeReroll', (tester) async {
    final fake = _FakeCoinsService()..currentCharges = 1;
    await tester.pumpWidget(harness.wrap(coinsService: fake));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reroll-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fake.consumeCalls, 0);
  });

  testWidgets('NO_CHARGES surfaces the humanized buy-more snackbar',
      (tester) async {
    // Render with charges=1 so the button is visible, then force the
    // server to respond NO_CHARGES anyway (simulates stale-inventory
    // race). The user-facing snackbar should be the friendly humanized
    // version, not the raw error code.
    final fake = _FakeCoinsService()
      ..currentCharges = 1
      ..forceErrorCode = 'NO_CHARGES';
    await tester.pumpWidget(harness.wrap(coinsService: fake));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reroll-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    expect(find.textContaining('reroll charges left'), findsOneWidget);
    expect(find.textContaining('NO_CHARGES'), findsNothing);
  });

  testWidgets('network error surfaces a generic try-again snackbar',
      (tester) async {
    final fake = _FakeCoinsService()
      ..currentCharges = 1
      ..throwOnConsume = true;
    await tester.pumpWidget(harness.wrap(coinsService: fake));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reroll-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Network error'), findsOneWidget);
  });
}
