import 'package:fixnum/fixnum.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quiz_battle/proto/quiz.pb.dart';
import 'package:quiz_battle/providers/analytics_state.dart';
import 'package:quiz_battle/screens/profile_analytics_screen.dart';

GetUserAnalyticsResponse _emptyAnalytics() => GetUserAnalyticsResponse()
  ..hasData = false
  ..lifetimeMatches = 0
  ..lifetimeWins = 0
  ..responseTime = (ResponseTimePercentiles()..sampleCount = Int64(0));

GetUserAnalyticsResponse _populatedAnalytics() {
  final r = GetUserAnalyticsResponse()
    ..hasData = true
    ..lifetimeMatches = 12
    ..lifetimeWins = 7
    ..responseTime = (ResponseTimePercentiles()
      ..sampleCount = Int64(50)
      ..p50Ms = 3000
      ..p90Ms = 7000
      ..p95Ms = 9000
      ..p99Ms = 12000);
  r.topicAccuracy.addAll([
    TopicAccuracy()
      ..topic = 'science'
      ..total = 30
      ..correct = 24
      ..accuracyPct = 24 / 30,
    TopicAccuracy()
      ..topic = 'history'
      ..total = 20
      ..correct = 8
      ..accuracyPct = 8 / 20,
  ]);
  // Three days, oldest first.
  r.ratingHistory.addAll([
    RatingPoint()
      ..unixDay = Int64(1714003200) // 2024-04-25
      ..rating = 1200,
    RatingPoint()
      ..unixDay = Int64(1714089600) // 2024-04-26
      ..rating = 1220,
    RatingPoint()
      ..unixDay = Int64(1714176000) // 2024-04-27
      ..rating = 1240,
  ]);
  return r;
}

GetMonthlyRecapResponse _populatedRecap() => GetMonthlyRecapResponse()
  ..year = 2026
  ..month = 4
  ..matchesPlayed = 8
  ..wins = 5
  ..winRate = 5 / 8
  ..favoriteTopic = 'science'
  ..longestStreakLifetime = 12
  ..hasData = true;

GetMonthlyRecapResponse _emptyRecap() => GetMonthlyRecapResponse()
  ..year = 2026
  ..month = 4
  ..hasData = false;

Widget _wrap({
  required AsyncValue<GetUserAnalyticsResponse> analytics,
  required AsyncValue<GetMonthlyRecapResponse> recap,
}) {
  // overrideWithValue lets us pin AsyncValue.{data,error,loading}
  // synchronously — Riverpod 3 settles `.overrideWith((_) async => …)`
  // overrides on the same frame as `pumpWidget`, which makes the
  // loading-state path impossible to test the other way.
  return ProviderScope(
    overrides: [
      userAnalyticsProvider.overrideWithValue(analytics),
      recapDataProvider.overrideWithValue(recap),
    ],
    child: const MaterialApp(home: ProfileAnalyticsScreen()),
  );
}

void main() {
  // The screen is a tall ListView (hero + chart + topics + percentiles
  // + recap card). The default test surface (800×600) only fits the
  // first two; off-screen children never get built, so `find.text` for
  // anything below the chart returns zero matches even though the data
  // is correct. Enlarging the per-view physical size keeps every
  // section in-view for the lifetime of each test.
  Future<void> giveTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('shows empty-state card when has_data=false', (tester) async {
    await giveTallSurface(tester);
    await tester.pumpWidget(_wrap(
      analytics: AsyncValue.data(_emptyAnalytics()),
      recap: AsyncValue.data(_emptyRecap()),
    ));
    await tester.pumpAndSettle();

    // The empty-state card is the only thing between the hero strip and
    // the recap card when has_data is false — no rating chart, no
    // topic list, no percentile tiles.
    expect(find.text('Not enough data yet'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Per-topic accuracy'), findsNothing);
    expect(find.text('Response time'), findsNothing);
  });

  testWidgets('renders all four panels when has_data=true', (tester) async {
    await giveTallSurface(tester);
    await tester.pumpWidget(_wrap(
      analytics: AsyncValue.data(_populatedAnalytics()),
      recap: AsyncValue.data(_populatedRecap()),
    ));
    await tester.pumpAndSettle();

    // Lifetime hero strip.
    expect(find.text('12'), findsOneWidget); // matches
    expect(find.text('7'), findsOneWidget); // wins
    expect(find.text('58%'), findsOneWidget); // 7/12 = 58%

    // Rating chart.
    expect(find.byType(LineChart), findsOneWidget);
    // Latest rating shown next to the section header.
    expect(find.text('1240'), findsOneWidget);

    // Topic list.
    expect(find.text('science'), findsAtLeastNWidgets(1)); // also in recap
    expect(find.text('history'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget); // 24/30
    expect(find.text('40%'), findsOneWidget); // 8/20

    // Percentile tiles, all four labels.
    expect(find.text('p50'), findsOneWidget);
    expect(find.text('p99'), findsOneWidget);
    expect(find.text('3.0s'), findsOneWidget);
    expect(find.text('12.0s'), findsOneWidget);

    // Monthly recap (populated).
    expect(find.text('Monthly recap'), findsOneWidget);
    expect(find.text('Favorite topic'), findsOneWidget);
  });

  testWidgets('percentile card shows hint copy below the 5-sample floor', (tester) async {
    await giveTallSurface(tester);
    final analytics = _populatedAnalytics()
      ..responseTime = (ResponseTimePercentiles()
        ..sampleCount = Int64(3)
        ..p50Ms = 0
        ..p90Ms = 0
        ..p95Ms = 0
        ..p99Ms = 0);

    await tester.pumpWidget(_wrap(
      analytics: AsyncValue.data(analytics),
      recap: AsyncValue.data(_emptyRecap()),
    ));
    await tester.pumpAndSettle();

    // The "keep playing" copy renders, no per-percentile tile.
    expect(find.textContaining('keep playing'), findsOneWidget);
    expect(find.text('p50'), findsNothing);
  });

  testWidgets('topic accuracy renders zero topics with friendly empty hint',
      (tester) async {
    await giveTallSurface(tester);
    final analytics = _populatedAnalytics()..topicAccuracy.clear();
    await tester.pumpWidget(_wrap(
      analytics: AsyncValue.data(analytics),
      recap: AsyncValue.data(_emptyRecap()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No topics tracked yet'), findsOneWidget);
  });

  testWidgets('error state shows retry button', (tester) async {
    await giveTallSurface(tester);
    await tester.pumpWidget(_wrap(
      analytics: AsyncValue.error('boom', StackTrace.empty),
      recap: AsyncValue.data(_emptyRecap()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('recap card "no matches" copy when has_data=false', (tester) async {
    await giveTallSurface(tester);
    await tester.pumpWidget(_wrap(
      analytics: AsyncValue.data(_emptyAnalytics()),
      recap: AsyncValue.data(_emptyRecap()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No matches played this month'), findsOneWidget);
  });
}
