import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proto/quiz.pb.dart';
import '../providers/analytics_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// §4.5 Deeper analytics screen. All numbers come from
/// [userAnalyticsProvider] / [recapDataProvider] which delegate to the
/// scoring service's `GetUserAnalytics` and `GetMonthlyRecap` RPCs.
/// Nothing is computed in this widget tree — the spec mandates server
/// aggregation only and the providers honour that.
class ProfileAnalyticsScreen extends ConsumerWidget {
  const ProfileAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(userAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats & Recap'),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userAnalyticsProvider);
          ref.invalidate(recapDataProvider);
          // Wait for the new fetch to land so the spinner doesn't
          // disappear before the data does.
          await ref.read(userAnalyticsProvider.future);
        },
        color: AppColors.primary,
        child: analytics.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: '$e', onRetry: () => ref.invalidate(userAnalyticsProvider)),
          data: (data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _LifetimeHero(matches: data.lifetimeMatches, wins: data.lifetimeWins)
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 16),
              if (!data.hasData)
                const _EmptyStateCard()
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 400.ms)
              else ...[
                _RatingChartCard(points: data.ratingHistory)
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 300.ms)
                    .slideY(begin: 0.05, end: 0),
                const SizedBox(height: 16),
                _TopicAccuracyCard(rows: data.topicAccuracy)
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 300.ms)
                    .slideY(begin: 0.05, end: 0),
                const SizedBox(height: 16),
                _PercentileCard(rt: data.responseTime)
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 300.ms)
                    .slideY(begin: 0.05, end: 0),
                const SizedBox(height: 16),
              ],
              const _MonthlyRecapCard()
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 300.ms)
                  .slideY(begin: 0.05, end: 0),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero strip — lifetime totals
// ---------------------------------------------------------------------------

class _LifetimeHero extends StatelessWidget {
  const _LifetimeHero({required this.matches, required this.wins});

  final int matches;
  final int wins;

  @override
  Widget build(BuildContext context) {
    final winRate = matches > 0 ? (wins * 100) ~/ matches : 0;
    return _Card(
      child: Row(
        children: [
          Expanded(child: _stat(matches.toString(), 'Matches')),
          Container(width: 1, height: 32, color: AppColors.border),
          Expanded(child: _stat(wins.toString(), 'Wins')),
          Container(width: 1, height: 32, color: AppColors.border),
          Expanded(child: _stat('$winRate%', 'Win rate')),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      );
}

// ---------------------------------------------------------------------------
// Rating chart — last 30 days, line plot
// ---------------------------------------------------------------------------

class _RatingChartCard extends StatelessWidget {
  const _RatingChartCard({required this.points});

  final List<RatingPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Rating — last 30 days',
                style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            _MutedRow('Not enough match history yet — play a match to start your rating curve.'),
          ],
        ),
      );
    }

    // Plot uses days-since-first-point on X (so the chart is independent of
    // absolute Unix epochs and stays readable at any zoom). Y is rating.
    final firstUnix = points.first.unixDay.toInt();
    final spots = points.map((p) {
      final daysSinceStart = ((p.unixDay.toInt() - firstUnix) / 86400).round();
      return FlSpot(daysSinceStart.toDouble(), p.rating.toDouble());
    }).toList();

    final ratings = points.map((p) => p.rating.toInt()).toList();
    final minRating = ratings.reduce((a, b) => a < b ? a : b);
    final maxRating = ratings.reduce((a, b) => a > b ? a : b);
    // Pad the Y axis so a flat line doesn't clip to the edge of the chart.
    final padding = ((maxRating - minRating) * 0.15).ceil().clamp(20, 100);
    final yMin = (minRating - padding).toDouble();
    final yMax = (maxRating + padding).toDouble();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Rating — last 30 days',
                  style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${ratings.last}',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.8,
            child: LineChart(
              LineChartData(
                minY: yMin,
                maxY: yMax,
                minX: 0,
                maxX: spots.last.x.clamp(1, double.infinity),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((yMax - yMin) / 4).clamp(20, 200),
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.primary,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withAlpha(28),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Topic accuracy — list of progress bars
// ---------------------------------------------------------------------------

class _TopicAccuracyCard extends StatelessWidget {
  const _TopicAccuracyCard({required this.rows});

  final List<TopicAccuracy> rows;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Per-topic accuracy',
              style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const _MutedRow('No topics tracked yet — answer a few questions to get started.')
          else
            for (final r in rows) _TopicRow(row: r),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.row});

  final TopicAccuracy row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(row.topic,
                  style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${row.correct}/${row.total}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(width: 8),
              Text('${(row.accuracyRatio * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: row.accuracyRatio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Response-time card — single average tile (percentiles still in
// proto for advanced UI / debug surfaces, but the profile screen
// surfaces just the headline mean).
// ---------------------------------------------------------------------------

class _PercentileCard extends StatelessWidget {
  const _PercentileCard({required this.rt});

  final ResponseTimePercentiles rt;

  @override
  Widget build(BuildContext context) {
    final hasData = rt.sampleCount > 0;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Response time',
                  style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${rt.sampleCount} answers',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasData)
            const _MutedRow(
                'No answers logged yet — play a match and your average will show up here.')
          else
            Row(
              children: [
                Expanded(child: _avgTile('Average', rt.avgMs)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _avgTile(String label, double ms) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardTint,
        borderRadius: AppRadius.button,
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 6),
          Text('${(ms / 1000).toStringAsFixed(1)}s',
              style: const TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 22)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly recap — picker + card
// ---------------------------------------------------------------------------

class _MonthlyRecapCard extends ConsumerWidget {
  const _MonthlyRecapCard();

  static const _monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  RecapMonth _previousMonthLocal() {
    final now = DateTime.now();
    if (now.month == 1) return RecapMonth(now.year - 1, 12);
    return RecapMonth(now.year, now.month - 1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRecapMonthProvider);
    final recap = ref.watch(recapDataProvider);
    final lastAvailable = _previousMonthLocal();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with month picker. Future months can't have a recap
          // yet, so the right arrow is disabled at lastAvailable.
          Row(
            children: [
              const Text('Monthly recap',
                  style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                onPressed: () => ref.read(selectedRecapMonthProvider.notifier).previous(),
                icon: const Icon(Icons.chevron_left),
                splashRadius: 18,
              ),
              Text(
                '${_monthNames[selected.month]} ${selected.year}',
                style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: selected.isAfter(lastAvailable) || _equal(selected, lastAvailable)
                    ? null
                    : () => ref.read(selectedRecapMonthProvider.notifier).next(),
                icon: const Icon(Icons.chevron_right),
                splashRadius: 18,
              ),
            ],
          ),
          const SizedBox(height: 12),
          recap.when(
            loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (e, _) => _MutedRow('Could not load recap: $e'),
            data: (r) => _recapBody(r),
          ),
        ],
      ),
    );
  }

  Widget _recapBody(GetMonthlyRecapResponse r) {
    if (!r.hasData) {
      return const _MutedRow('No matches played this month.');
    }
    final winRatePct = (r.winRate * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _miniStat(r.matchesPlayed.toString(), 'Matches'),
            const SizedBox(width: 12),
            _miniStat('${r.wins}', 'Wins'),
            const SizedBox(width: 12),
            _miniStat('$winRatePct%', 'Win rate'),
          ],
        ),
        const SizedBox(height: 16),
        if (r.favoriteTopic.isNotEmpty)
          _kv('Favorite topic', r.favoriteTopic),
        _kv('Longest streak (lifetime)', '${r.longestStreakLifetime} days'),
      ],
    );
  }

  static bool _equal(RecapMonth a, RecapMonth b) => a.year == b.year && a.month == b.month;

  Widget _miniStat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: AppColors.cardTint, borderRadius: AppRadius.button),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Text(k, style: const TextStyle(color: AppColors.textMuted)),
            const Spacer(),
            Text(v, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _MutedRow extends StatelessWidget {
  const _MutedRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 13));
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          // Tinted-circle hero badge — same affordance as the
          // EmptyState shared widget but inline so it stays inside
          // the analytics panel's _Card frame for visual consistency
          // with the other panels above and below it.
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.15),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(
              Icons.insights_rounded,
              size: 32,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Not enough data yet',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Play a few matches and your per-topic accuracy, response time, and rating curve will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      iconColor: AppColors.danger,
      title: "Couldn't load analytics",
      body: message,
      actionLabel: 'Retry',
      onActionTap: onRetry,
    );
  }
}
