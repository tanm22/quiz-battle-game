import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quiz_battle/proto/quiz.pb.dart';
import 'package:quiz_battle/providers/game_state.dart';
import 'package:quiz_battle/screens/results_screen.dart';

/// Test-local Notifier that returns a fixed [GameState] from [build].
/// `GameStateNotifier` is a Riverpod v3 `Notifier` whose real `build`
/// returns `const GameState()` — for tests we substitute a subclass that
/// returns the prebuilt state we want to render.
class _FixedGameStateNotifier extends GameStateNotifier {
  _FixedGameStateNotifier(this._initial);
  final GameState _initial;
  @override
  GameState build() => _initial;
}

GameState _winState() {
  // Build a finished match where the local user is rank 1 with +100 coins.
  final me = PlayerResult()
    ..userId = 'me'
    ..username = 'alice'
    ..finalScore = 1000
    ..rank = 1
    ..answersCorrect = 5
    ..plan = 'free'
    ..coinsAwarded = Int64(100);
  final them = PlayerResult()
    ..userId = 'them'
    ..username = 'bob'
    ..rank = 2
    ..coinsAwarded = Int64(0);
  final result = MatchEnd()
    ..winner = 'me'
    ..rounds = 5
    ..players.addAll([me, them]);
  return const GameState().copyWith(userId: 'me', matchResult: result);
}

GameState _lossState() {
  final me = PlayerResult()
    ..userId = 'me'
    ..rank = 2
    ..coinsAwarded = Int64(0);
  final them = PlayerResult()
    ..userId = 'them'
    ..rank = 1
    ..coinsAwarded = Int64(100);
  return const GameState().copyWith(
    userId: 'me',
    matchResult: MatchEnd()
      ..winner = 'them'
      ..rounds = 5
      ..players.addAll([me, them]),
  );
}

Widget _wrap(GameState gs) => ProviderScope(
      overrides: [
        gameStateProvider.overrideWith(() => _FixedGameStateNotifier(gs)),
      ],
      child: const MaterialApp(home: ResultsScreen()),
    );

void main() {
  // The results screen lays out a tall Column (badge + headline + stats
  // card + opponents list + CTAs). The default test surface (800×600) is
  // too short for it and triggers a RenderFlex overflow assertion which
  // Flutter treats as a test failure. Same approach as
  // `profile_analytics_screen_test.dart`: enlarge the surface so every
  // section fits.
  Future<void> giveTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('winner sees +100 coins celebration', (tester) async {
    await giveTallSurface(tester);
    await tester.pumpWidget(_wrap(_winState()));
    await tester.pumpAndSettle();
    expect(find.text('+100 coins'), findsOneWidget);
  });

  testWidgets('non-winner does not see a coin celebration', (tester) async {
    await giveTallSurface(tester);
    await tester.pumpWidget(_wrap(_lossState()));
    await tester.pumpAndSettle();
    expect(find.textContaining('coins'), findsNothing);
  });
}
