import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quiz_battle/providers/game_state.dart';

/// Test double for [GameStateNotifier] that
///   1. seeds [GameState] with the room/user/round needed by the
///      production submission path so we never NPE on `state.roomId!`, and
///   2. overrides [submitAnswerToServer] to count invocations without
///      reaching the real gRPC channel — the underlying [QuizService]
///      is a singleton that opens TCP sockets and can't be swapped from
///      outside the library.
///
/// This is the pattern used elsewhere in the project's tests (see
/// `screens/results_screen_test.dart`).
class _CountingGameStateNotifier extends GameStateNotifier {
  int submitCalls = 0;
  final List<int> submittedOptions = [];

  @override
  GameState build() {
    return const GameState().copyWith(
      roomId: 'room-1',
      userId: 'user-1',
      round: 1,
    );
  }

  @override
  void submitAnswerToServer(int optionIndex) {
    submitCalls++;
    submittedOptions.add(optionIndex);
  }
}

void main() {
  late ProviderContainer container;
  late _CountingGameStateNotifier notifier;

  setUp(() {
    notifier = _CountingGameStateNotifier();
    container = ProviderContainer(
      overrides: [
        gameStateProvider.overrideWith(() => notifier),
      ],
    );
    // Trigger build() so `state` is initialized.
    container.read(gameStateProvider);
  });

  tearDown(() => container.dispose());

  group('selectAnswer locks after first tap', () {
    test('first tap sets selectedIndex and submits to server', () {
      notifier.selectAnswer(2);

      expect(container.read(gameStateProvider).selectedIndex, 2);
      expect(notifier.submitCalls, 1);
      expect(notifier.submittedOptions, [2]);
    });

    test('second tap on a DIFFERENT option does not change selectedIndex',
        () {
      notifier.selectAnswer(0); // first tap — locks to A
      notifier.selectAnswer(1); // re-tap on B — must be a no-op

      // This is the core property under test. The pre-fix bug let
      // selectedIndex drift to 1 while the server still held 0, which
      // surfaced as a false "Correct" / "Wrong" badge on the round result.
      expect(container.read(gameStateProvider).selectedIndex, 0,
          reason: 'second tap must not override the locked-in answer');
    });

    test('second tap on the SAME option does not clear selectedIndex', () {
      notifier.selectAnswer(0);
      notifier.selectAnswer(0); // re-tap on A — must not deselect

      // The legacy `toggleAnswer` path treated this as a deselect; the
      // gameplay screen now goes through `selectAnswer`, which is
      // strictly idempotent for the locked option.
      expect(container.read(gameStateProvider).selectedIndex, 0,
          reason: 're-tapping the locked option must not deselect it');
    });

    test('submitAnswerToServer is called exactly once across many taps',
        () {
      notifier.selectAnswer(0); // first tap — submits
      notifier.selectAnswer(1); // ignored
      notifier.selectAnswer(2); // ignored
      notifier.selectAnswer(0); // ignored (same option, post-lock)
      notifier.selectAnswer(3); // ignored

      // The server is the source of truth for what the user answered;
      // we MUST NOT re-submit after the first tap or we'd race the
      // existing `_submittedRound` gate from a different code path.
      expect(notifier.submitCalls, 1,
          reason: 'only the first tap in a round should hit the server');
      expect(notifier.submittedOptions, [0],
          reason: 'the option sent to the server is the very first tap');
    });

    test(
        'after correctIndex is broadcast, taps are no-ops even if highlight has not reset yet',
        () {
      notifier.selectAnswer(1);
      // Simulate the server's RoundResult event arriving (this is what
      // _processGameEvent does in production).
      notifier.state = notifier.state.copyWith(correctIndex: 2);

      notifier.selectAnswer(3); // post-resolve tap

      expect(container.read(gameStateProvider).selectedIndex, 1);
      expect(notifier.submitCalls, 1);
    });
  });
}
