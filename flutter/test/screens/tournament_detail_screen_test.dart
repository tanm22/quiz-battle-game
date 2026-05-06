import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quiz_battle/proto/quiz.pb.dart';
import 'package:quiz_battle/providers/tournaments_state.dart';
import 'package:quiz_battle/screens/tournament_detail_screen.dart';

Tournament _t({required String name, String status = 'active'}) => Tournament()
  ..id = 't1'
  ..name = name
  ..status = status
  ..requiredPlan = 'free'
  ..prizeDescription = 'Top 3 win 500/300/100'
  ..prizePool.addAll([Int64(500), Int64(300), Int64(100)])
  ..participantCount = 5;

TournamentStandingEntry _e(int rank, String name, int score) =>
    TournamentStandingEntry()
      ..userId = 'u$rank'
      ..username = name
      ..rank = rank
      ..score = Int64(score);

Widget _wrap({
  required Tournament tournament,
  required List<TournamentStandingEntry> entries,
}) {
  return ProviderScope(
    overrides: [
      tournamentDetailProvider('t1').overrideWith((_) async => tournament),
      tournamentLeaderboardProvider('t1').overrideWith((_) async => entries),
    ],
    child: const MaterialApp(
      home: TournamentDetailScreen(tournamentId: 't1'),
    ),
  );
}

void main() {
  testWidgets('rules tab renders name + prize breakdown', (tester) async {
    await tester.pumpWidget(_wrap(
      tournament: _t(name: 'Weekend Warriors'),
      entries: const [],
    ));
    await tester.pumpAndSettle();

    // Tournament name appears in the AppBar title.
    expect(find.text('Weekend Warriors'), findsWidgets);
    // Prize description is rendered on the Rules tab.
    expect(find.textContaining('500/300/100'), findsOneWidget);
  });

  testWidgets('live tab renders entries sorted by rank', (tester) async {
    await tester.pumpWidget(_wrap(
      tournament: _t(name: 'Weekend Warriors'),
      entries: [_e(1, 'alice', 900), _e(2, 'bob', 700), _e(3, 'carol', 500)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();

    expect(find.text('alice'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('carol'), findsOneWidget);
    expect(find.text('900 pts'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
  });

  testWidgets('live tab shows empty state when no entries', (tester) async {
    await tester.pumpWidget(_wrap(
      tournament: _t(name: 'Weekend Warriors'),
      entries: const [],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No participants yet'), findsOneWidget);
  });
}
