import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proto/quiz.pb.dart';
import '../providers/coins_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// Lifetime coin-ledger history. The screen owns its own pagination
/// state — first page loads in [initState], subsequent pages load when
/// the user scrolls within 200 px of the bottom. An empty
/// `next_page_token` from the server means we have the final page and
/// stop firing further requests.
class CoinLedgerScreen extends ConsumerStatefulWidget {
  const CoinLedgerScreen({super.key});

  @override
  ConsumerState<CoinLedgerScreen> createState() => _CoinLedgerScreenState();
}

class _CoinLedgerScreenState extends ConsumerState<CoinLedgerScreen> {
  static const _pageSize = 25;

  final List<CoinLedgerEntry> _rows = [];
  final ScrollController _scroll = ScrollController();

  String _nextToken = '';
  bool _loading = false;
  bool _exhausted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    // Gate on _error too: after a mid-list pagination failure the footer
    // shows a Retry button, and recovery should be user-initiated.
    // Without this, every scroll within 200 px of the bottom would
    // silently retry the failed RPC in a tight loop.
    if (!_scroll.hasClients || _loading || _exhausted || _error != null) {
      return;
    }
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 200) _loadMore();
  }

  Future<void> _loadMore() async {
    // _error is intentionally NOT in this entry guard — the footer
    // Retry button calls _loadMore directly and must be able to clear
    // the error and try again. The scroll listener above is what
    // enforces "no auto-retry on error."
    if (_loading || _exhausted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(coinsServiceProvider)
          .ledger(pageSize: _pageSize, pageToken: _nextToken);
      if (!mounted) return;
      setState(() {
        _rows.addAll(r.entries);
        _nextToken = r.nextPageToken;
        _exhausted = r.nextPageToken.isEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// Map server reasons (`match.win`, `streak.daily_reward`, …) to
  /// short user-facing strings. Unknown reasons render as the raw token
  /// so support can still spot them in the field.
  String _humanize(String reason) {
    switch (reason) {
      case 'match.win':
        return 'Match win';
      case 'streak.daily_reward':
        return 'Daily streak';
      case 'streak.bonus':
        return 'Streak bonus';
      case 'tournament.placement':
        return 'Tournament prize';
      case 'referral.referrer':
        return 'Referral reward';
      case 'referral.referee':
        return 'Welcome bonus';
      case 'shop.purchase':
        return 'Shop purchase';
      case 'shop.refund':
        return 'Refund';
      case 'admin.adjustment':
        return 'Adjustment';
      default:
        return reason;
    }
  }

  String _formatDate(int unixMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(unixMs).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Coin History'),
        centerTitle: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_rows.isEmpty && _loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_rows.isEmpty && _error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        iconColor: AppColors.danger,
        title: "Couldn't load history",
        body: _error,
        actionLabel: 'Retry',
        onActionTap: _loadMore,
      );
    }
    if (_rows.isEmpty) {
      return const EmptyState(
        icon: Icons.savings_rounded,
        iconColor: AppColors.gold,
        title: 'No coin activity yet',
        body: 'Play your first match to start earning coins. Daily streaks and tournament wins boost your balance fast.',
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _rows.length + (_exhausted ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i >= _rows.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _loadMore,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
            ),
          );
        }
        final row = _rows[i];
        return _LedgerRow(
          reason: _humanize(row.reason),
          delta: row.delta.toInt(),
          balanceAfter: row.balanceAfter.toInt(),
          when: _formatDate(row.createdAtUnixMs.toInt()),
        )
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: 30 * (i % 8)),
              duration: 250.ms,
            )
            .slideY(
              begin: 0.05,
              end: 0,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }
}

/// One ledger row — a card with a tinted-circle icon (green for
/// positive delta / red for negative), humanized reason headline,
/// timestamp, signed delta, and post-balance footnote.
class _LedgerRow extends StatelessWidget {
  final String reason;
  final int delta;
  final int balanceAfter;
  final String when;

  const _LedgerRow({
    required this.reason,
    required this.delta,
    required this.balanceAfter,
    required this.when,
  });

  @override
  Widget build(BuildContext context) {
    final positive = delta >= 0;
    final tint = positive ? AppColors.success : AppColors.danger;
    final icon = positive
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: appCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: tint.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  when,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : ''}$delta',
                style: TextStyle(
                  color: tint,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'bal $balanceAfter',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
