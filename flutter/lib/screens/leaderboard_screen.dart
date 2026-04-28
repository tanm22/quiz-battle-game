import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';
import '../proto/quiz.pb.dart';
import '../theme/app_theme.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  // Row slot (padding + AnimatedContainer height) — must match _rowHeight below
  // so AnimatedPositioned maths lines up.
  static const double _rowStride = 62; // 54 row + 8 gap

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(gameStateProvider.select((s) => s.leaderboard));

    return Scaffold(
      body: ScaffoldGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.leaderboard, color: AppColors.gold, size: 28),
                    const SizedBox(width: 10),
                    const Text('Leaderboard',
                        style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: leaderboard.isEmpty
                    ? const _EmptyLeaderboard()
                    : _AnimatedLeaderboardList(
                        entries: leaderboard,
                        rowStride: _rowStride,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders leaderboard rows in a Stack + AnimatedPositioned so that when rank
/// order changes (score updates flip positions) each row slides smoothly to its
/// new slot instead of snapping. Keyed by userId so widget identity survives
/// reorder, which is what makes the implicit animation tween from old to new
/// top offset.
class _AnimatedLeaderboardList extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final double rowStride;
  const _AnimatedLeaderboardList({required this.entries, required this.rowStride});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: entries.length * rowStride,
        child: Stack(
          children: [
            for (int i = 0; i < entries.length; i++)
              AnimatedPositioned(
                key: ValueKey(entries[i].userId),
                duration: AppDurations.slow,
                curve: Curves.easeOutCubic,
                top: i * rowStride,
                left: 0,
                right: 0,
                child: _LeaderboardRow(
                  entry: entries[i],
                  position: i + 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldBg,
                border: Border.all(color: AppColors.gold.withAlpha(80), width: 2),
              ),
              child: const Icon(Icons.emoji_events, color: AppColors.gold, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'No scores yet',
              style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'First correct answer puts you on the board.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  // Podium background tints for top 3 — dark-tone tokens so the
  // near-white username text + medal-colored score render with proper
  // contrast on each row. The pre-redesign version used #F1F5F9
  // (near-white) for 2nd and #FFF7ED (cream) for 3rd, which made
  // the foreground text effectively invisible against them.
  static const _podiumBg = [
    AppColors.goldBg,    // 1st – faint gold
    AppColors.silverBg,  // 2nd – faint silver
    AppColors.bronzeBg,  // 3rd – faint bronze
  ];

  static const _medalColors = [
    AppColors.medalGold,
    AppColors.medalSilver,
    AppColors.medalBronze,
  ];

  final LeaderboardEntry entry;
  final int position;
  const _LeaderboardRow({required this.entry, required this.position});

  @override
  Widget build(BuildContext context) {
    final isMedal = position <= 3;
    final medalColor = isMedal ? _medalColors[position - 1] : null;
    final bgColor = isMedal ? _podiumBg[position - 1] : AppColors.surface;

    return AnimatedContainer(
      duration: AppDurations.medium,
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.card,
        border: Border.all(color: isMedal ? medalColor!.withAlpha(80) : AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMedal ? medalColor!.withAlpha(40) : AppColors.cardTint,
            ),
            child: Center(
              child: isMedal && position == 1
                  ? Icon(Icons.emoji_events, color: medalColor, size: 20)
                  : Text('#$position',
                      style: TextStyle(
                          color: medalColor ?? AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),

          // Username
          Expanded(
            child: Text(
              entry.username.isEmpty ? entry.userId : entry.username,
              style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),

          // Animated score
          AnimatedSwitcher(
            duration: AppDurations.medium,
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Text(
              '${entry.score.toInt()}',
              key: ValueKey(entry.score.toInt()),
              style: TextStyle(
                color: isMedal ? medalColor : AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
