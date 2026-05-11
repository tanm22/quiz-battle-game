import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proto/quiz.pb.dart';
import '../services/quiz_service.dart';
import '../services/tournaments_service.dart';

/// Singleton [TournamentsService] bound to the shared gRPC channel +
/// JWT call options exposed by [QuizService]. Tests override this with
/// a fake — same pattern as [coinsServiceProvider].
final tournamentsServiceProvider = Provider<TournamentsService>((ref) {
  return TournamentsService.fromQuizService(QuizService());
});

/// Detail for one tournament — name, time window, prize pool,
/// participant count. Backs the Rules tab on the detail screen.
///
/// Uses `ref.watch` (not `ref.read`) so overriding
/// [tournamentsServiceProvider] in tests with a fake actually
/// propagates here — same convention as [coinBalanceProvider].
final tournamentDetailProvider =
    FutureProvider.family<Tournament, String>((ref, id) async {
  return ref.watch(tournamentsServiceProvider).get(id);
});

/// Live leaderboard for a tournament. Auto-invalidates every 10
/// seconds while watched, so the Live tab polls fresh standings
/// without a manual pull-to-refresh. The timer is cancelled on
/// dispose, which fires the moment no widget watches this provider
/// anymore — leaving the detail screen tears it down with no leak.
final tournamentLeaderboardProvider =
    FutureProvider.family<List<TournamentStandingEntry>, String>((ref, id) async {
  // Skip the tick if the previous RPC hasn't completed yet — otherwise
  // a slow window (network blip, backend stall > 10 s) cascades redundant
  // in-flight RPCs that never serve a result. Riverpod auto-disposes the
  // provider on screen pop, which fires onDispose → cancels the timer
  // before this closure is ever stale.
  var inFlight = true;
  final timer = Timer.periodic(const Duration(seconds: 10), (_) {
    if (inFlight) return;
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  try {
    return await ref.watch(tournamentsServiceProvider).leaderboard(id);
  } finally {
    inFlight = false;
  }
});
