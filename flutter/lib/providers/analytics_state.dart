import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proto/quiz.pb.dart';
import '../services/analytics_service.dart';
import '../services/quiz_service.dart';

/// Singleton [AnalyticsService] bound to the shared gRPC channel +
/// JWT call-options exposed by [QuizService]. Tests override this
/// with a fake.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService.fromQuizService(QuizService());
});

/// Cached user-analytics payload. Refresh-on-pull is wired from the
/// screen's `RefreshIndicator`. Uses `ref.watch` so test overrides of
/// [analyticsServiceProvider] propagate (the same lesson from the
/// PR #16 review of the coin providers).
final userAnalyticsProvider = FutureProvider<GetUserAnalyticsResponse>((ref) {
  return ref.watch(analyticsServiceProvider).userAnalytics();
});

/// Selected `(year, month)` for the recap card. Defaults to the previous
/// calendar month — the recap is a retrospective, so the current
/// (incomplete) month would be misleading.
class RecapMonth {
  const RecapMonth(this.year, this.month);
  final int year;
  final int month;

  RecapMonth previous() {
    if (month == 1) return RecapMonth(year - 1, 12);
    return RecapMonth(year, month - 1);
  }

  RecapMonth next() {
    if (month == 12) return RecapMonth(year + 1, 1);
    return RecapMonth(year, month + 1);
  }

  /// Future months can't have a recap. Comparison runs in the user's
  /// local zone — server is source-of-truth for "this month" but the
  /// picker should track what the user perceives as "now."
  bool isAfter(RecapMonth other) =>
      year > other.year || (year == other.year && month > other.month);
}

RecapMonth _previousMonthLocal() {
  final now = DateTime.now();
  if (now.month == 1) return RecapMonth(now.year - 1, 12);
  return RecapMonth(now.year, now.month - 1);
}

/// Notifier for the currently-selected recap month. Riverpod 3 dropped
/// the legacy `StateProvider`; the migration path is `Notifier` +
/// `NotifierProvider`. Methods carry the prev/next intent rather than
/// exposing `state =` to call sites.
class SelectedRecapMonth extends Notifier<RecapMonth> {
  @override
  RecapMonth build() => _previousMonthLocal();

  void set(RecapMonth m) => state = m;
  void previous() => state = state.previous();
  void next() => state = state.next();
}

final selectedRecapMonthProvider =
    NotifierProvider<SelectedRecapMonth, RecapMonth>(SelectedRecapMonth.new);

/// Recap data for the currently-selected month. Re-runs whenever
/// [selectedRecapMonthProvider] changes; cached per-month within the
/// session.
final recapDataProvider = FutureProvider<GetMonthlyRecapResponse>((ref) {
  final m = ref.watch(selectedRecapMonthProvider);
  return ref.watch(analyticsServiceProvider).monthlyRecap(year: m.year, month: m.month);
});
