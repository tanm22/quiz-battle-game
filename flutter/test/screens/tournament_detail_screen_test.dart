import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import 'package:quiz_battle/proto/quiz.pbgrpc.dart';
import 'package:quiz_battle/providers/tournaments_state.dart';
import 'package:quiz_battle/screens/tournament_detail_screen.dart';
import 'package:quiz_battle/services/tournaments_service.dart';

/// Test double that lets the real `tournamentLeaderboardProvider` factory
/// run (Timer.periodic + in-flight guard) while feeding it a controllable
/// `leaderboard()` implementation. Constructing the super class needs a
/// non-null gRPC client; the channel is never actually connected because
/// the override below replaces every method that would call into it.
class _FakeTournamentsService extends TournamentsService {
  _FakeTournamentsService(this._onLeaderboard)
      : super(
          QuizServiceClient(ClientChannel(
            '127.0.0.1',
            port: 65535,
            options: const ChannelOptions(
              credentials: ChannelCredentials.insecure(),
            ),
          )),
          () => CallOptions(),
        );

  final Future<List<TournamentStandingEntry>> Function() _onLeaderboard;

  @override
  Future<List<TournamentStandingEntry>> leaderboard(String id) =>
      _onLeaderboard();
}

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

    // Tournament name appears in the AppBar title (single render site —
    // findsOneWidget guards against a future regression where the same
    // string accidentally appears in multiple widgets).
    expect(find.text('Weekend Warriors'), findsOneWidget);
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

    // Important #2: verify ROW ORDER too. The previous presence-only
    // assertions would pass even if the list rendered entries reversed.
    // Compare y-coordinates of the rendered names: alice (#1) must
    // appear above bob (#2), bob above carol (#3).
    final aliceY = tester.getTopLeft(find.text('alice')).dy;
    final bobY = tester.getTopLeft(find.text('bob')).dy;
    final carolY = tester.getTopLeft(find.text('carol')).dy;
    expect(aliceY, lessThan(bobY),
        reason: 'rank 1 (alice) must render above rank 2 (bob)');
    expect(bobY, lessThan(carolY),
        reason: 'rank 2 (bob) must render above rank 3 (carol)');
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

  // Important #1: the leaderboard provider must not be subscribed while
  // the Rules tab is active — otherwise the 10s poll runs continuously
  // even after the user has navigated away from Live, doubling backend
  // cost. Tests three boundaries: (a) initial Rules state, (b) Live
  // activation triggers subscription, (c) returning to Rules tears the
  // subscription down so the timer can't fire again. Time-advance via
  // tester.pump(Duration) flows through flutter_test's FakeAsync zone,
  // which intercepts dart:async Timer.periodic — so the assertion
  // catches a leaked timer that would silently keep polling.
  testWidgets('leaderboard provider gated on active tab', (tester) async {
    var subs = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tournamentDetailProvider('t1')
            .overrideWith((_) async => _t(name: 'X')),
        tournamentLeaderboardProvider('t1').overrideWith((_) async {
          subs++;
          return const <TournamentStandingEntry>[];
        }),
      ],
      child: const MaterialApp(
        home: TournamentDetailScreen(tournamentId: 't1'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(subs, 0, reason: 'Rules tab must not subscribe to leaderboard');

    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    expect(subs, 1, reason: 'Live tab must subscribe once');

    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();
    // Advance past one polling cycle. If _LiveTab survived the tab
    // switch, the Timer.periodic would fire and re-invoke the override.
    await tester.pump(const Duration(seconds: 11));
    expect(subs, 1, reason: 'returning to Rules must dispose the polling timer');
  });

  // Important #4: directly exercise the closure-local `inFlight` flag in
  // tournamentLeaderboardProvider. The other widget tests use
  // `overrideWith` on the leaderboard provider, which REPLACES the
  // production factory — bypassing Timer.periodic, the guard, and the
  // onDispose hook. Here we override the SERVICE instead so the real
  // factory body runs against a controllable fake.
  testWidgets('polling timer fires every 10s and skips when RPC pending',
      (tester) async {
    var subs = 0;
    final pending = <Completer<List<TournamentStandingEntry>>>[];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        // Bypass the detail RPC — only the leaderboard polling logic is
        // under test here.
        tournamentDetailProvider('t1')
            .overrideWith((_) async => _t(name: 'X')),
        tournamentsServiceProvider.overrideWithValue(
          _FakeTournamentsService(() {
            subs++;
            final c = Completer<List<TournamentStandingEntry>>();
            pending.add(c);
            return c.future;
          }),
        ),
      ],
      child: const MaterialApp(
        home: TournamentDetailScreen(tournamentId: 't1'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(subs, 0, reason: 'Rules tab does not mount _LiveTab');

    // Mount _LiveTab. Factory invokes service.leaderboard() once, then
    // hangs awaiting our Completer. pumpAndSettle would block forever
    // on the pending Future, so pump one frame and continue.
    await tester.tap(find.text('Live'));
    await tester.pump();
    expect(subs, 1, reason: 'initial subscribe runs once');

    // 11s: Timer.periodic fires its 10s tick. inFlight is still true
    // because the first RPC's Completer hasn't completed — the tick
    // must early-return without invalidating.
    await tester.pump(const Duration(seconds: 11));
    expect(subs, 1, reason: 'tick must skip while prior RPC pending');

    // Complete the first RPC. The factory's `finally` flips inFlight to
    // false. After settling microtasks, the next 10s tick should fire.
    pending.first.complete(const <TournamentStandingEntry>[]);
    await tester.pump();

    await tester.pump(const Duration(seconds: 11));
    expect(subs, 2, reason: 'tick fires once prior RPC resolves');

    // Drain any leftover pending futures so flutter_test doesn't flag
    // a leaked Future at the end of the test.
    for (final c in pending) {
      if (!c.isCompleted) c.complete(const <TournamentStandingEntry>[]);
    }
    await tester.pump();
  });
}
