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

  int consumeCalls = 0;
  int chargesAfter = 0;
  String? lastRoom;
  String? lastRound;

  @override
  Future<ConsumeRerollResponse> consumeReroll({String roomId = '', String roundId = ''}) async {
    consumeCalls++;
    lastRoom = roomId;
    lastRound = roundId;
    return ConsumeRerollResponse()
      ..success = true
      ..chargesRemaining = chargesAfter;
  }

  @override
  Future<GetShopInventoryResponse> inventory() async {
    return GetShopInventoryResponse()
      ..rerollCharges = chargesAfter
      ..balance = Int64(500);
  }
}

void main() {
  testWidgets('reroll button is hidden when user has 0 charges', (tester) async {
    final fake = _FakeCoinsService()..chargesAfter = 0;
    await tester.pumpWidget(harness.wrap(coinsService: fake, charges: 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reroll-button')), findsNothing);
  });

  testWidgets('reroll button shown with N charges; tap calls ConsumeReroll', (tester) async {
    final fake = _FakeCoinsService()..chargesAfter = 1;
    await tester.pumpWidget(harness.wrap(coinsService: fake, charges: 2));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reroll-button')), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // charge count badge

    await tester.tap(find.byKey(const Key('reroll-button')));
    await tester.pumpAndSettle();

    // Confirm dialog appears, user taps "Use".
    expect(find.text('Use a reroll?'), findsOneWidget);
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    expect(fake.consumeCalls, 1);
  });

  testWidgets('cancel dismisses without calling ConsumeReroll', (tester) async {
    final fake = _FakeCoinsService()..chargesAfter = 1;
    await tester.pumpWidget(harness.wrap(coinsService: fake, charges: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reroll-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fake.consumeCalls, 0);
  });
}
