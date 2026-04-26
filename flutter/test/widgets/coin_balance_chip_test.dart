import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quiz_battle/providers/coins_state.dart';
import 'package:quiz_battle/widgets/coin_balance_chip.dart';

/// Builds a [ProviderScope]-wrapped chip whose backing
/// [coinBalanceProvider] is forced to [value]. Using `overrideWithValue`
/// with an explicit [AsyncValue] avoids racing the test pump against an
/// async future's microtask completion (which Riverpod 3 settles in the
/// same frame as `pumpWidget`).
Widget _wrap(AsyncValue<int> value, {VoidCallback? onTap}) {
  return ProviderScope(
    overrides: [
      coinBalanceProvider.overrideWithValue(value),
    ],
    child: MaterialApp(
      home: Scaffold(body: Center(child: CoinBalanceChip(onTap: onTap))),
    ),
  );
}

void main() {
  testWidgets('renders the balance number when the provider has data',
      (tester) async {
    await tester.pumpWidget(_wrap(const AsyncValue.data(250)));
    await tester.pump();

    expect(find.text('250'), findsOneWidget);
    expect(find.byIcon(Icons.monetization_on), findsOneWidget);
  });

  testWidgets('shows a spinner while the provider is loading', (tester) async {
    await tester.pumpWidget(_wrap(const AsyncValue.loading()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an error icon when the provider has an error',
      (tester) async {
    await tester.pumpWidget(_wrap(AsyncValue.error('boom', StackTrace.empty)));
    await tester.pump();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('fires onTap when provided', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(const AsyncValue.data(42), onTap: () => taps++));
    await tester.pump();

    await tester.tap(find.byType(CoinBalanceChip));
    expect(taps, 1);
  });
}
