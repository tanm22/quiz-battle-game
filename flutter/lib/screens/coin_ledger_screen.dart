import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proto/quiz.pb.dart';
import '../providers/coins_state.dart';
import '../theme/app_theme.dart';

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
    if (!_scroll.hasClients || _loading || _exhausted) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 200) _loadMore();
  }

  Future<void> _loadMore() async {
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
    if (_rows.isEmpty && _loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coin History')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_rows.isEmpty && _error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coin History')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 32, color: AppColors.danger),
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _loadMore, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coin History')),
        body: const Center(
          child: Text('No coin activity yet — earn some by playing matches.',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coin History'),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
      ),
      body: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        itemCount: _rows.length + (_exhausted ? 0 : 1),
        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, i) {
          if (i >= _rows.length) {
            // Footer spinner / retry while another page is in flight
            // OR after a page-load error.
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _error != null
                    ? TextButton(onPressed: _loadMore, child: const Text('Retry'))
                    : const CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final row = _rows[i];
          final positive = row.delta >= 0;
          return ListTile(
            dense: true,
            leading: Icon(
              positive ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: positive ? AppColors.success : AppColors.danger,
            ),
            title: Text(
              _humanize(row.reason),
              style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _formatDate(row.createdAtUnixMs.toInt()),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${positive ? '+' : ''}${row.delta.toInt()}',
                  style: TextStyle(
                    color: positive ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'bal ${row.balanceAfter.toInt()}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
