import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';
import '../proto/quiz.pb.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  static const _medalColors = [
    Color(0xFFFFD700), // Gold
    Color(0xFFC0C0C0), // Silver
    Color(0xFFCD7F32), // Bronze
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(gameStateProvider.select((s) => s.leaderboard));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1145), Color(0xFF0F0E2E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.leaderboard, color: Color(0xFFFFD700), size: 28),
                    const SizedBox(width: 10),
                    const Text('Leaderboard', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: leaderboard.isEmpty
                    ? Center(child: Text('No scores yet', style: TextStyle(color: Colors.white.withAlpha(100))))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: leaderboard.length,
                        itemBuilder: (context, index) {
                          final entry = leaderboard[index];
                          return _LeaderboardRow(
                            key: ValueKey(entry.userId),
                            entry: entry,
                            position: index + 1,
                            medalColors: _medalColors,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final int position;
  final List<Color> medalColors;
  const _LeaderboardRow({super.key, required this.entry, required this.position, required this.medalColors});

  @override
  Widget build(BuildContext context) {
    final isMedal = position <= 3;
    final medalColor = isMedal ? medalColors[position - 1] : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isMedal ? medalColor!.withAlpha(20) : Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(14),
        border: isMedal ? Border.all(color: medalColor!.withAlpha(60)) : null,
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMedal ? medalColor!.withAlpha(40) : Colors.white.withAlpha(10),
            ),
            child: Center(
              child: isMedal && position == 1
                  ? Icon(Icons.emoji_events, color: medalColor, size: 20)
                  : Text('#$position', style: TextStyle(color: medalColor ?? Colors.white54, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),

          // Username
          Expanded(
            child: Text(
              entry.username.isEmpty ? entry.userId : entry.username,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),

          // Animated score
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Text(
              '${entry.score.toInt()}',
              key: ValueKey(entry.score.toInt()),
              style: TextStyle(color: isMedal ? medalColor : Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
