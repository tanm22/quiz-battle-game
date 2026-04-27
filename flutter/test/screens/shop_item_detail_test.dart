import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quiz_battle/proto/quiz.pb.dart';
import 'package:quiz_battle/providers/coins_state.dart';
import 'package:quiz_battle/screens/shop/shop_item_detail.dart';

ShopItem _item(String id, String kind, {String name = 'X'}) => ShopItem()
  ..id = id
  ..kind = kind
  ..name = name
  ..description = 'desc'
  ..priceCoins = Int64(100)
  ..active = true;

GetShopInventoryResponse _inv({
  List<String> owned = const [],
  String equippedCosmetic = '',
  String equippedNameColor = '',
  bool freezeHeld = false,
  int rerollCharges = 0,
}) =>
    GetShopInventoryResponse()
      ..ownedCosmetics.addAll(owned)
      ..equippedCosmeticId = equippedCosmetic
      ..equippedNameColor = equippedNameColor
      ..streakFreezeHeld = freezeHeld
      ..rerollCharges = rerollCharges
      ..balance = Int64(1000);

Widget _wrap(ShopItem item, GetShopInventoryResponse inv) {
  return ProviderScope(
    overrides: [
      coinBalanceProvider.overrideWithValue(const AsyncValue.data(1000)),
      shopInventoryProvider.overrideWithValue(AsyncValue.data(inv)),
    ],
    child: MaterialApp(home: ShopItemDetail(item: item)),
  );
}

ElevatedButton _findBuyButton(WidgetTester tester) {
  return tester
      .widgetList<ElevatedButton>(find.byType(ElevatedButton))
      .firstWhere((b) => b.style?.backgroundColor != null,
          orElse: () => tester.widget(find.byType(ElevatedButton).last));
}

void main() {
  testWidgets('cosmetic: enabled when not owned', (tester) async {
    await tester.pumpWidget(_wrap(
      _item('frame.gold', 'cosmetic.avatar_frame'),
      _inv(),
    ));
    await tester.pump();
    expect(find.text('Buy'), findsOneWidget);
    expect(_findBuyButton(tester).onPressed, isNotNull);
  });

  testWidgets('cosmetic: shows "Already owned" once owned but not equipped',
      (tester) async {
    await tester.pumpWidget(_wrap(
      _item('frame.gold', 'cosmetic.avatar_frame'),
      _inv(owned: ['frame.gold']),
    ));
    await tester.pump();
    expect(find.text('Already owned'), findsOneWidget);
    expect(_findBuyButton(tester).onPressed, isNull);
  });

  testWidgets('cosmetic: shows "Equipped" when active', (tester) async {
    await tester.pumpWidget(_wrap(
      _item('frame.gold', 'cosmetic.avatar_frame'),
      _inv(owned: ['frame.gold'], equippedCosmetic: 'frame.gold'),
    ));
    await tester.pump();
    expect(find.text('Equipped'), findsOneWidget);
    expect(_findBuyButton(tester).onPressed, isNull);
  });

  testWidgets('streak_freeze: disabled when streakFreezeHeld is true',
      (tester) async {
    // Regression for PR #17 review issue #2 — the old guard only
    // checked ownedCosmetics, so a streak-freeze user could re-tap Buy
    // and the server would have to reject with WEEKLY_CAP.
    await tester.pumpWidget(_wrap(
      _item('streak_freeze.weekly', 'streak_freeze'),
      _inv(freezeHeld: true),
    ));
    await tester.pump();
    expect(find.text('Already held'), findsOneWidget);
    expect(_findBuyButton(tester).onPressed, isNull);
  });

  testWidgets('streak_freeze: enabled once held flips to false', (tester) async {
    await tester.pumpWidget(_wrap(
      _item('streak_freeze.weekly', 'streak_freeze'),
      _inv(freezeHeld: false),
    ));
    await tester.pump();
    expect(find.text('Buy'), findsOneWidget);
    expect(_findBuyButton(tester).onPressed, isNotNull);
  });

  testWidgets('reroll_topic: always enabled (charges stack)', (tester) async {
    await tester.pumpWidget(_wrap(
      _item('reroll.topic', 'reroll_topic'),
      _inv(rerollCharges: 5),
    ));
    await tester.pump();
    expect(find.text('Buy'), findsOneWidget);
    expect(_findBuyButton(tester).onPressed, isNotNull);
  });

  testWidgets('premium_trial: always enabled (extends expiry)', (tester) async {
    await tester.pumpWidget(_wrap(
      _item('premium.trial.3d', 'premium_trial'),
      _inv(),
    ));
    await tester.pump();
    expect(find.text('Buy'), findsOneWidget);
    expect(_findBuyButton(tester).onPressed, isNotNull);
  });
}
