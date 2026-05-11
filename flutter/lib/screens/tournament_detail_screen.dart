import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tournaments_state.dart';
import '../theme/app_theme.dart';

/// §4.2 PR 1: tournament detail screen with a Rules tab (status, time
/// window, prize breakdown, participant count) and a Live tab (current
/// standings, polled every 10s via [tournamentLeaderboardProvider]).
///
/// Wired from the tournament list screen on card-tap; PR 2 will route
/// completed tournaments to a separate results screen instead.
class TournamentDetailScreen extends ConsumerStatefulWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId});
  final String tournamentId;

  @override
  ConsumerState<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState
    extends ConsumerState<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Rebuild so the body switch below only mounts the active tab's
    // widget. Without this, _LiveTab would persist across Rules<->Live
    // toggles and its 10s leaderboard poll would keep firing while the
    // user is on Rules. See PR 43 review Important #1.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(tournamentDetailProvider(widget.tournamentId));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: detail.when(
          data: (t) => Text(t.name),
          loading: () => const Text('Tournament'),
          error: (_, _) => const Text('Tournament'),
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.text,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.gold,
          tabs: const [
            Tab(text: 'Rules'),
            Tab(text: 'Live'),
          ],
        ),
      ),
      // Render only the active tab. Switching away unmounts the prior
      // tab's widget, which auto-disposes its Riverpod subscriptions —
      // for _LiveTab that means the leaderboard poll's Timer.periodic
      // is cancelled (via the onDispose hook on the provider) the moment
      // the user navigates to Rules.
      body: _tab.index == 1
          ? _LiveTab(tournamentId: widget.tournamentId)
          : _RulesTab(tournamentId: widget.tournamentId),
    );
  }
}

class _RulesTab extends ConsumerWidget {
  const _RulesTab({required this.tournamentId});
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(tournamentDetailProvider(tournamentId)).when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
            child: Text(
              'Could not load: $e',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          data: (t) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _kv('Status', t.status.toUpperCase()),
              if (t.startTime != 0)
                _kv('Starts', _fmtDateTime(t.startTime.toInt())),
              if (t.endTime != 0)
                _kv('Ends', _fmtDateTime(t.endTime.toInt())),
              if (t.entryDeadline != 0)
                _kv('Entry by', _fmtDateTime(t.entryDeadline.toInt())),
              _kv('Required plan', t.requiredPlan),
              _kv('Participants', '${t.participantCount}'),
              const SizedBox(height: 16),
              if (t.prizeDescription.isNotEmpty)
                Text(
                  t.prizeDescription,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (t.prizePool.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (var i = 0; i < t.prizePool.length; i++)
                  ListTile(
                    leading: Text(
                      '#${i + 1}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    title: Text(
                      '${t.prizePool[i].toInt()} coins',
                      style: const TextStyle(color: AppColors.text),
                    ),
                  ),
              ],
            ],
          ),
        );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                k,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _LiveTab extends ConsumerWidget {
  const _LiveTab({required this.tournamentId});
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(tournamentLeaderboardProvider(tournamentId)).when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
            child: Text(
              'Could not load: $e',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return const Center(
                child: Text(
                  'No participants yet — be the first!',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            return ListView.builder(
              key: const Key('tournament-leaderboard-list'),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                return ListTile(
                  leading: Text(
                    '#${e.rank}',
                    style: TextStyle(
                      color: e.rank <= 3
                          ? AppColors.gold
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  title: Text(
                    e.username.isEmpty ? e.userId : e.username,
                    style: const TextStyle(color: AppColors.text),
                  ),
                  trailing: Text(
                    '${e.score.toInt()} pts',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            );
          },
        );
  }
}

/// Formats a unix-millisecond timestamp into a short, locale-neutral
/// "MMM d, yyyy h:mma" string. Inlined rather than pulling `intl` for
/// a single call site — the existing tournament list screen also
/// formats dates without it.
String _fmtDateTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour12 = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  final mm = d.minute.toString().padLeft(2, '0');
  return '${months[d.month - 1]} ${d.day}, ${d.year} $hour12:$mm $ampm';
}
