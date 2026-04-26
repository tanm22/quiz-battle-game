import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quiz_battle/proto/quiz.pb.dart';
import 'package:quiz_battle/providers/coins_state.dart';
import 'package:quiz_battle/screens/shop/shop_screen.dart';

ShopItem _item(String id, String kind, String name, int price) {
  return ShopItem()
    ..id = id
    ..kind = kind
    ..name = name
    ..description = 'Test description for $name'
    ..priceCoins = Int64(price)
    ..active = true;
}

GetShopInventoryResponse _emptyInventory() => GetShopInventoryResponse()
  ..balance = Int64(1000)
  ..rerollCharges = 0;

Widget _wrap({required List<ShopItem> catalog}) {
  return ProviderScope(
    overrides: [
      coinBalanceProvider.overrideWith((_) async => 1000),
      shopCatalogProvider.overrideWith((_) async => catalog),
      shopInventoryProvider.overrideWith((_) async => _emptyInventory()),
    ],
    child: const MaterialApp(home: ShopScreen()),
  );
}

void main() {
  testWidgets('renders the Cosmetics tab and switches to Boosts on tap',
      (tester) async {
    await tester.pumpWidget(_wrap(catalog: [
      _item('frame.gold', 'cosmetic.avatar_frame', 'Gold', 500),
      _item('reroll.topic', 'reroll_topic', 'Reroll', 50),
    ]));
    // Two pumps: one for the providers' initial frame, one for the data.
    await tester.pumpAndSettle();

    // Default (Cosmetics) tab shows Gold but not Reroll.
    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('Reroll'), findsNothing);

    await tester.tap(find.text('Boosts'));
    await tester.pumpAndSettle();

    // After tapping Boosts: Reroll visible, Gold no longer.
    expect(find.text('Reroll'), findsOneWidget);
    expect(find.text('Gold'), findsNothing);
  });

  testWidgets('shows the empty-state placeholder when a tab has no items',
      (tester) async {
    await tester.pumpWidget(_wrap(catalog: [
      _item('frame.gold', 'cosmetic.avatar_frame', 'Gold', 500),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Premium'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });
}
