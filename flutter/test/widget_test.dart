import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quiz_battle/main.dart';

/// Smoke test: app boots and reaches a MaterialApp without throwing.
/// Intentionally minimal — the auth and network layers reach out to a
/// backend at boot, so a deeper widget test would require mocking gRPC
/// and SharedPreferences. This guards against regressions where the
/// app fails to construct at all.
void main() {
  testWidgets('QuizBattleApp boots without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const QuizBattleApp());
    // Settle a single frame; downstream auth futures stay pending. We
    // only care that initial build didn't throw synchronously.
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
