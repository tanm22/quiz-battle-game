import 'package:grpc/grpc.dart';

import '../proto/quiz.pbgrpc.dart';
import 'quiz_service.dart';

/// Thin typed wrapper around `ScoringServiceClient` for the §4.5
/// analytics RPCs. Reuses the shared [QuizService] singleton's gRPC
/// channel + JWT call-options — no new connection.
class AnalyticsService {
  AnalyticsService(this._client, this._optsBuilder);

  factory AnalyticsService.fromQuizService(QuizService qs) =>
      AnalyticsService(qs.scoring, () => qs.authCallOptions);

  final ScoringServiceClient _client;
  final CallOptions Function() _optsBuilder;

  /// Lifetime per-topic accuracy + response-time percentiles + a
  /// 30-day daily-bucketed rating history. One round trip, all
  /// panels populated together so the screen renders without
  /// staggered loading states.
  Future<GetUserAnalyticsResponse> userAnalytics() {
    return _client.getUserAnalytics(
      GetUserAnalyticsRequest(),
      options: _optsBuilder(),
    );
  }

  /// `Your <Month>` recap card. Server-side aggregation; the [year]
  /// + [month] window is inclusive on the start and exclusive on the
  /// end, in UTC.
  Future<GetMonthlyRecapResponse> monthlyRecap({required int year, required int month}) {
    return _client.getMonthlyRecap(
      GetMonthlyRecapRequest()
        ..year = year
        ..month = month,
      options: _optsBuilder(),
    );
  }
}
