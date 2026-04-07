import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../proto/quiz.pb.dart';
import '../services/quiz_service.dart';

// ---------------------------------------------------------------------------
// Step 59: GameState — holds all live match state
// ---------------------------------------------------------------------------

enum GameScreen { matchmaking, gameplay, leaderboard, results }

class GameState {
  final GameScreen currentScreen;
  final String? roomId;
  final String? userId;
  final QuestionBroadcast? currentQuestion;
  final Map<String, double> scores;
  final int round;
  final int deadlineUnix;
  final int? selectedIndex;
  final int? correctIndex;
  final MatchEnd? matchResult;
  final List<LeaderboardEntry> leaderboard;
  final bool isReconnecting;
  final int lastSequenceNumber;

  const GameState({
    this.currentScreen = GameScreen.matchmaking,
    this.roomId,
    this.userId,
    this.currentQuestion,
    this.scores = const {},
    this.round = 0,
    this.deadlineUnix = 0,
    this.selectedIndex,
    this.correctIndex,
    this.matchResult,
    this.leaderboard = const [],
    this.isReconnecting = false,
    this.lastSequenceNumber = 0,
  });

  GameState copyWith({
    GameScreen? currentScreen,
    String? roomId,
    String? userId,
    QuestionBroadcast? currentQuestion,
    Map<String, double>? scores,
    int? round,
    int? deadlineUnix,
    int? selectedIndex,
    int? correctIndex,
    MatchEnd? matchResult,
    List<LeaderboardEntry>? leaderboard,
    bool? isReconnecting,
    int? lastSequenceNumber,
    bool clearSelectedIndex = false,
    bool clearCorrectIndex = false,
  }) {
    return GameState(
      currentScreen: currentScreen ?? this.currentScreen,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      scores: scores ?? this.scores,
      round: round ?? this.round,
      deadlineUnix: deadlineUnix ?? this.deadlineUnix,
      selectedIndex: clearSelectedIndex ? null : (selectedIndex ?? this.selectedIndex),
      correctIndex: clearCorrectIndex ? null : (correctIndex ?? this.correctIndex),
      matchResult: matchResult ?? this.matchResult,
      leaderboard: leaderboard ?? this.leaderboard,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      lastSequenceNumber: lastSequenceNumber ?? this.lastSequenceNumber,
    );
  }
}

// ---------------------------------------------------------------------------
// GameStateNotifier — Riverpod v3 Notifier
// ---------------------------------------------------------------------------

class GameStateNotifier extends Notifier<GameState> {
  final QuizService _service = QuizService();
  StreamSubscription? _matchSub;
  StreamSubscription? _gameSub;
  int _reconnectAttempt = 0;

  @override
  GameState build() {
    ref.onDispose(() {
      _matchSub?.cancel();
      _gameSub?.cancel();
    });
    return const GameState();
  }

  void setUserId(String userId) {
    state = state.copyWith(userId: userId);
  }

  // --- Matchmaking ---

  Future<void> joinMatchmaking(String userId, int rating) async {
    state = state.copyWith(userId: userId, currentScreen: GameScreen.matchmaking);
    await _service.joinMatchmaking(userId, rating);

    _matchSub?.cancel();
    final stream = _service.subscribeToMatch(userId);
    _matchSub = stream.listen(
      (event) => _onMatchFound(event),
      onError: (e) => _onStreamError(e),
    );
  }

  void _onMatchFound(MatchEvent event) {
    _matchSub?.cancel();
    state = state.copyWith(
      roomId: event.roomId,
      currentScreen: GameScreen.gameplay,
      lastSequenceNumber: event.sequenceNumber.toInt(),
    );
    _startGameStream();
  }

  // --- Game event stream ---

  void _startGameStream() {
    _gameSub?.cancel();
    final stream = _service.streamGameEvents(
      state.roomId!,
      state.userId!,
      sequenceNumber: state.lastSequenceNumber,
    );
    _gameSub = stream.listen(
      (event) => _processGameEvent(event),
      onError: (e) => _onStreamError(e),
    );
  }

  void _processGameEvent(GameEvent event) {
    _reconnectAttempt = 0; // reset on successful event
    state = state.copyWith(
      lastSequenceNumber: event.sequenceNumber.toInt(),
      isReconnecting: false,
    );

    switch (event.whichEvent()) {
      case GameEvent_Event.question:
        final q = event.question;
        state = state.copyWith(
          currentQuestion: q,
          round: q.round,
          deadlineUnix: q.deadlineUnix.toInt(),
          currentScreen: GameScreen.gameplay,
          clearSelectedIndex: true,
          clearCorrectIndex: true,
        );
      case GameEvent_Event.leaderboard:
        final entries = event.leaderboard.entries;
        final newScores = <String, double>{};
        for (final e in entries) {
          newScores[e.userId] = e.score;
        }
        state = state.copyWith(scores: newScores, leaderboard: entries);
      case GameEvent_Event.roundResult:
        state = state.copyWith(correctIndex: event.roundResult.correctIndex);
        // Auto-reset answer highlight after 1.5s (step 64)
        Future.delayed(const Duration(milliseconds: 1500), () {
          state = state.copyWith(clearSelectedIndex: true, clearCorrectIndex: true);
        });
      case GameEvent_Event.matchEnd:
        state = state.copyWith(
          matchResult: event.matchEnd,
          currentScreen: GameScreen.results,
        );
      case GameEvent_Event.playerJoined:
        break; // handled by UI toast
      case GameEvent_Event.timerSync:
        state = state.copyWith(deadlineUnix: event.timerSync.deadlineUnix.toInt());
      case GameEvent_Event.notSet:
        break;
    }
  }

  // --- Answer submission ---

  void selectAnswer(int optionIndex) {
    if (state.selectedIndex != null) return;
    state = state.copyWith(selectedIndex: optionIndex);

    _service.submitAnswer(
      roomId: state.roomId!,
      userId: state.userId!,
      round: state.round,
      optionIndex: optionIndex,
      clientTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // --- Reconnection (section 6.3) ---

  void _onStreamError(dynamic error) {
    state = state.copyWith(isReconnecting: true);
    _reconnectAttempt++;
    _reconnectWithBackoff();
  }

  void _reconnectWithBackoff() {
    const delays = [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ];

    if (_reconnectAttempt > delays.length) {
      // After 3 failed retries, show match abandoned and return to lobby
      _reconnectAttempt = 0;
      state = state.copyWith(
        currentScreen: GameScreen.matchmaking,
        isReconnecting: false,
      );
      return;
    }

    Future.delayed(delays[_reconnectAttempt - 1], () {
      if (!state.isReconnecting) return;
      _gameSub?.cancel();
      _startGameStream();
    });
  }

  // --- Navigation ---

  void navigateToLeaderboard() {
    state = state.copyWith(currentScreen: GameScreen.leaderboard);
  }

  Future<void> playAgain() async {
    _matchSub?.cancel();
    _gameSub?.cancel();
    if (state.userId != null) {
      await _service.leaveMatchmaking(state.userId!);
    }
    state = const GameState();
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final gameStateProvider =
    NotifierProvider<GameStateNotifier, GameState>(GameStateNotifier.new);
