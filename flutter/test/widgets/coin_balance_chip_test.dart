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
Widget _wrap(AsyncValue<int> value, {VoidCallback? onTap, int? initialBalance}) {
  return ProviderScope(
    overrides: [
      coinBalanceProvider.overrideWithValue(value),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: CoinBalanceChip(onTap: onTap, initialBalance: initialBalance),
        ),
      ),
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

  testWidgets('initialBalance renders instead of a spinner while loading',
      (tester) async {
    // Home screen passes `profile.coins` as a seed so users on the hot
    // path never see a spinner — the cached number renders immediately.
    await tester.pumpWidget(_wrap(
      const AsyncValue.loading(),
      initialBalance: 314,
    ));
    await tester.pump();

    expect(find.text('314'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('initialBalance is overridden once the provider produces data',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const AsyncValue.data(500),
      initialBalance: 100,
    ));
    await tester.pump();

    // Provider's value wins over the seed when both are available — that's
    // how a freshly-invalidated balance refresh propagates to the chip.
    expect(find.text('500'), findsOneWidget);
    expect(find.text('100'), findsNothing);
  });

  testWidgets('initialBalance is shown instead of an error icon on failure',
      (tester) async {
    // If GetCoinBalance blips, fall back to the seed rather than show
    // a scary error icon for a value the user already saw a moment ago.
    await tester.pumpWidget(_wrap(
      AsyncValue.error('boom', StackTrace.empty),
      initialBalance: 250,
    ));
    await tester.pump();

    expect(find.text('250'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });
}
