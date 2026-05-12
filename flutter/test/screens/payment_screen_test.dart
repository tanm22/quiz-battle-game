import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quiz_battle/screens/payment_screen.dart';

/// §4.9 Flutter widget coverage for the premium screen. The screen's
/// in-state gRPC calls (`getPlanStatus`, `getPaymentHistory`) reach the
/// singleton `QuizService` directly rather than a Riverpod provider, so
/// they're not mockable through `ProviderScope.overrides`. They are,
/// however, wrapped in `try/catch (_) {}` — when the test runner has no
/// backend the calls fail silently and the screen renders its default
/// "free user — upgrade tier" state. That is exactly the rendering
/// path we want to assert on.
///
/// The Razorpay native plugin's MethodChannel is stubbed out with a
/// no-op handler below so `Razorpay()` construction in initState
/// succeeds in the test binding.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Stub the razorpay MethodChannel — every method returns null.
    // Without this, Razorpay() in initState throws
    // MissingPluginException and the widget never mounts.
    const channel = MethodChannel('razorpay_flutter');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });

  tearDown(() {
    const channel = MethodChannel('razorpay_flutter');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // The payment screen has a tall body (upgrade hero + 4 feature rows +
  // plan-selection row + CTA + history section). The default 800×600
  // test surface is too short and triggers a RenderFlex overflow that
  // the framework treats as a test failure. Same trick as
  // results_screen_test.dart.
  Future<void> giveTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // The screen's initState fires two unauthenticated gRPC calls
  // (`getPlanStatus`, `getPaymentHistory`). With no backend the calls
  // sit on their internal 10s deadline timers; if the test ends before
  // those fire, the binding throws "A Timer is still pending". Pump
  // past the deadline so the timers tick, the catch-all swallows the
  // resulting GrpcError, and the widget settles into its default
  // (no-data) render path.
  Future<void> pumpStable(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
  }

  testWidgets('free-tier user sees the Upgrade-to-Premium tier', (tester) async {
    await giveTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: PaymentScreen()));
    await pumpStable(tester);

    // Headline + subhead.
    expect(find.text('Upgrade to Premium'), findsOneWidget);
    expect(
      find.textContaining('Unlock unlimited play'),
      findsOneWidget,
    );

    // App bar reads "Premium".
    expect(find.text('Premium'), findsAtLeastNWidgets(1));
  });

  testWidgets('feature-comparison rows are present', (tester) async {
    await giveTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: PaymentScreen()));
    await pumpStable(tester);

    // Each premium-vs-free pair sits in a feature row; assert both
    // halves of the contract land on screen so a copy-rotting refactor
    // (e.g. silently dropping "Unlimited quizzes") fails this test.
    expect(find.text('Unlimited quizzes'), findsOneWidget);
    expect(find.text('Join tournaments'), findsOneWidget);
    expect(find.text('Full match history'), findsOneWidget);
    expect(find.text('Full leaderboard'), findsOneWidget);
  });

  testWidgets('monthly + yearly plan cards render with their prices',
      (tester) async {
    await giveTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: PaymentScreen()));
    await pumpStable(tester);

    // Both plan cards are visible; prices are exactly the strings the
    // screen hard-codes (the source of truth for the user-facing
    // price). A backend price change must propagate here so this
    // assertion fails when stale.
    expect(find.text('299/mo'), findsOneWidget);
    expect(find.text('2,999/yr'), findsOneWidget);
  });

  testWidgets('tapping the yearly plan card flips selection state',
      (tester) async {
    await giveTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: PaymentScreen()));
    await pumpStable(tester);

    // Default is monthly — tap the yearly card and verify the screen
    // is still rendering both cards (we don't have a stable test hook
    // for "selected"-state visuals, but we DO want a positive signal
    // that the InkWell handler runs without throwing).
    await tester.tap(find.text('2,999/yr'));
    await pumpStable(tester);
    expect(find.text('299/mo'), findsOneWidget);
    expect(find.text('2,999/yr'), findsOneWidget);
  });
}
