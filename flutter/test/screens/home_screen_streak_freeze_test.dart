import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quiz_battle/proto/quiz.pb.dart';
import 'package:quiz_battle/providers/coins_state.dart';
import 'package:quiz_battle/widgets/streak_freeze_chip.dart';

GetShopInventoryResponse _inv({required bool held}) =>
    GetShopInventoryResponse()
      ..streakFreezeHeld = held
      ..balance = Int64(0);

Widget _wrap({required bool held}) => ProviderScope(
      overrides: [
        shopInventoryProvider.overrideWith((ref) async => _inv(held: held)),
      ],
      child: const MaterialApp(home: Scaffold(body: StreakFreezeChip())),
    );

void main() {
  testWidgets('chip is hidden when no freeze is held', (tester) async {
    await tester.pumpWidget(_wrap(held: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('streak-freeze-chip')), findsNothing);
  });

  testWidgets('chip is visible when a freeze is held', (tester) async {
    await tester.pumpWidget(_wrap(held: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('streak-freeze-chip')), findsOneWidget);
    expect(find.textContaining('Freeze'), findsOneWidget);
  });
}
