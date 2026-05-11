import 'package:grpc/grpc.dart';

import '../proto/quiz.pbgrpc.dart';
import 'quiz_service.dart';

/// Thin typed wrapper around the auto-generated [QuizServiceClient]
/// for §4.2 tournament RPCs. Same pattern as [CoinsService] /
/// [FriendsService] — reuses the shared [QuizService] singleton's
/// gRPC channel + JWT call-options instead of opening a duplicate
/// connection.
class TournamentsService {
  TournamentsService(this._client, this._optsBuilder);

  /// Convenience constructor that binds to the shared [QuizService]
  /// singleton. Prefer this in production; tests inject their own
  /// [_client] via the primary constructor.
  factory TournamentsService.fromQuizService(QuizService qs) =>
      TournamentsService(qs.quiz, () => qs.authCallOptions);

  final QuizServiceClient _client;
  final CallOptions Function() _optsBuilder;

  /// All tournaments currently surfaced to the user (upcoming + active).
  /// Backs the tournament list screen.
  Future<List<TournamentInfo>> list() async {
    final r = await _client.getTournamentList(
      GetTournamentListRequest(),
      options: _optsBuilder(),
    );
    return r.tournaments;
  }

  /// Full tournament document — name, time window, prize pool,
  /// participant count. Backs the Rules tab on the detail screen.
  Future<Tournament> get(String id) async {
    final r = await _client.getTournament(
      GetTournamentRequest()..tournamentId = id,
      options: _optsBuilder(),
    );
    return r.tournament;
  }

  /// Live standings sorted by score desc with 1-based rank assigned
  /// server-side. Capped at 100 entries; the Flutter screen polls this
  /// every 10s while foregrounded. Backs the Live tab.
  Future<List<TournamentStandingEntry>> leaderboard(String id) async {
    final r = await _client.getTournamentLeaderboard(
      GetTournamentLeaderboardRequest()..tournamentId = id,
      options: _optsBuilder(),
    );
    return r.entries;
  }

  /// Add the caller to the tournament's participants list. Server-side
  /// guards: premium gating + entry-deadline check.
  Future<JoinTournamentResponse> join(String id) {
    return _client.joinTournament(
      JoinTournamentRequest()..tournamentId = id,
      options: _optsBuilder(),
    );
  }
}
