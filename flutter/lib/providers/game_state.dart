import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import '../proto/quiz.pb.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';

// ---------------------------------------------------------------------------
// Step 59: GameState — holds all live match state
// ---------------------------------------------------------------------------

enum GameScreen { login, home, matchmaking, gameplay, leaderboard, results }

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
  final String? token;
  final int rating;
  final bool isReconnecting;
  final int lastSequenceNumber;
  final bool isGuest;
  final String? email;
  final String? errorMessage;
  final int totalRounds;

  const GameState({
    this.currentScreen = GameScreen.login,
    this.roomId,
    this.userId,
    this.token,
    this.rating = 1200,
    this.currentQuestion,
    this.scores = const {},
    this.round = 0,
    this.totalRounds = 0,
    this.deadlineUnix = 0,
    this.selectedIndex,
    this.correctIndex,
    this.matchResult,
    this.leaderboard = const [],
    this.isReconnecting = false,
    this.lastSequenceNumber = 0,
    this.isGuest = false,
    this.email,
    this.errorMessage,
  });

  GameState copyWith({
    GameScreen? currentScreen,
    String? roomId,
    String? userId,
    String? token,
    int? rating,
    QuestionBroadcast? currentQuestion,
    Map<String, double>? scores,
    int? round,
    int? totalRounds,
    int? deadlineUnix,
    int? selectedIndex,
    int? correctIndex,
    MatchEnd? matchResult,
    List<LeaderboardEntry>? leaderboard,
    bool? isReconnecting,
    int? lastSequenceNumber,
    bool? isGuest,
    String? email,
    String? errorMessage,
    bool clearSelectedIndex = false,
    bool clearCorrectIndex = false,
    bool clearError = false,
  }) {
    return GameState(
      currentScreen: currentScreen ?? this.currentScreen,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      rating: rating ?? this.rating,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      scores: scores ?? this.scores,
      round: round ?? this.round,
      totalRounds: totalRounds ?? this.totalRounds,
      deadlineUnix: deadlineUnix ?? this.deadlineUnix,
      selectedIndex: clearSelectedIndex ? null : (selectedIndex ?? this.selectedIndex),
      correctIndex: clearCorrectIndex ? null : (correctIndex ?? this.correctIndex),
      matchResult: matchResult ?? this.matchResult,
      leaderboard: leaderboard ?? this.leaderboard,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      lastSequenceNumber: lastSequenceNumber ?? this.lastSequenceNumber,
      isGuest: isGuest ?? this.isGuest,
      email: email ?? this.email,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
  Map<String, double> _pendingScores = {};
  Timer? _highlightResetTimer;
  bool _disposed = false;

  @override
  GameState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _matchSub?.cancel();
      _gameSub?.cancel();
      _highlightResetTimer?.cancel();
    });
    return const GameState();
  }

  void setUserId(String userId) {
    state = state.copyWith(userId: userId);
  }

  // --- Auth ---

  void setAuth(String userId, String token, int rating, {bool isGuest = false, String? email}) {
    state = state.copyWith(
      userId: userId,
      token: token,
      rating: rating,
      isGuest: isGuest,
      email: email,
      currentScreen: GameScreen.home,
    );
  }

  void linkEmailSuccess(String email) {
    state = state.copyWith(isGuest: false, email: email);
  }

  // --- Matchmaking ---

  Future<void> joinMatchmaking(String userId, int rating) async {
    state = state.copyWith(currentScreen: GameScreen.matchmaking, clearError: true);
    try {
      await _service.joinMatchmaking(userId, rating);
    } on GrpcError catch (e) {
      if (e.code == StatusCode.resourceExhausted) {
        state = state.copyWith(errorMessage: 'Daily quiz limit reached. Upgrade to Premium for unlimited quizzes!');
      } else {
        state = state.copyWith(errorMessage: 'Failed to join matchmaking: ${e.message}');
      }
      return;
    }

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
    _fetchTotalRounds(event.roomId);
    _startGameStream();
  }

  Future<void> _fetchTotalRounds(String roomId) async {
    try {
      final resp = await _service.getRoomQuestions(roomId);
      if (resp.questions.isNotEmpty) {
        state = state.copyWith(totalRounds: resp.questions.length);
      }
    } catch (_) {
      // Non-critical — UI will show "Round X" without total
    }
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
        _pendingScores = {for (final e in entries) e.userId: e.score};
        state = state.copyWith(leaderboard: entries);
      case GameEvent_Event.roundResult:
        // Apply buffered scores at round end, then show correct/wrong
        state = state.copyWith(
          correctIndex: event.roundResult.correctIndex,
          scores: _pendingScores.isNotEmpty ? Map.of(_pendingScores) : null,
        );
        // Auto-reset answer highlight after 1.5s (cancellable on dispose)
        _highlightResetTimer?.cancel();
        _highlightResetTimer = Timer(const Duration(milliseconds: 1500), () {
          if (!_disposed) {
            state = state.copyWith(clearSelectedIndex: true, clearCorrectIndex: true);
          }
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

  int? _submittedRound; // track which round we already submitted for

  void selectAnswer(int optionIndex) {
    if (state.selectedIndex != null) return;
    toggleAnswer(optionIndex);
  }

  void toggleAnswer(int optionIndex) {
    if (state.correctIndex != null) return; // round resolved, no changes

    if (state.selectedIndex == optionIndex) {
      // Deselect
      state = state.copyWith(clearSelectedIndex: true);
      return;
    }

    // Select new option
    state = state.copyWith(selectedIndex: optionIndex);

    // Submit only once per round
    if (_submittedRound != state.round) {
      _submittedRound = state.round;
      try {
        _service.submitAnswer(
          roomId: state.roomId!,
          userId: state.userId!,
          round: state.round,
          optionIndex: optionIndex,
          clientTimestamp: DateTime.now().millisecondsSinceEpoch,
        );
      } on GrpcError catch (e) {
        state = state.copyWith(errorMessage: 'Failed to submit answer: ${e.message}');
      }
    }
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
        currentScreen: GameScreen.home,
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

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // --- Leave match ---

  Future<void> leaveMatch() async {
    _matchSub?.cancel();
    _gameSub?.cancel();
    _pendingScores = {};
    if (state.userId != null) {
      await _service.leaveMatchmaking(state.userId!);
    }
    // Refresh profile to get updated rating/stats from server
    final auth = AuthService();
    await auth.refreshProfile();
    state = GameState(
      currentScreen: GameScreen.home,
      userId: state.userId,
      token: state.token,
      rating: auth.rating,
      email: auth.email,
      isGuest: auth.isGuest,
    );
  }

  // --- Navigation ---

  void navigateToLeaderboard() {
    state = state.copyWith(currentScreen: GameScreen.leaderboard);
  }

  void navigateToMatchmaking() {
    state = state.copyWith(currentScreen: GameScreen.matchmaking);
  }

  void navigateToMatchHistory() {
    // Navigate using Navigator.push from the UI — this is a signal method
    state = state.copyWith(currentScreen: GameScreen.home);
  }

  void navigateToHome() {
    state = state.copyWith(currentScreen: GameScreen.home);
  }

  Future<void> playAgain() async {
    _matchSub?.cancel();
    _gameSub?.cancel();
    if (state.userId != null) {
      await _service.leaveMatchmaking(state.userId!);
    }
    // Refresh profile to get updated rating/stats from server
    final auth = AuthService();
    await auth.refreshProfile();
    state = GameState(
      currentScreen: GameScreen.home,
      userId: state.userId,
      token: state.token,
      rating: auth.rating,
      email: auth.email,
      isGuest: auth.isGuest,
    );
  }

  Future<void> logout() async {
    _matchSub?.cancel();
    _gameSub?.cancel();
    _service.clearAuth();
    state = const GameState();
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final gameStateProvider =
    NotifierProvider<GameStateNotifier, GameState>(GameStateNotifier.new);
