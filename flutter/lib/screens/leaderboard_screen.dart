import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';
import '../proto/quiz.pb.dart';

/// Step 66: Full leaderboard screen with AnimatedList, rank badges,
/// gold/silver/bronze backgrounds, and position change arrows.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final _listKey = GlobalKey<AnimatedListState>();
  List<LeaderboardEntry> _currentEntries = [];
  // Track previous ranks: userId -> previous position (1-indexed)
  final Map<String, int> _previousRanks = {};

  static const _medalColors = [
    Color(0xFFFFD700), // Gold
    Color(0xFFC0C0C0), // Silver
    Color(0xFFCD7F32), // Bronze
  ];

  @override
  Widget build(BuildContext context) {
    // Listen for leaderboard changes and animate
    ref.listen(
      gameStateProvider.select((s) => s.leaderboard),
      (prev, next) {
        _updateList(prev ?? [], next);
      },
    );

    final leaderboard = ref.watch(
      gameStateProvider.select((s) => s.leaderboard),
    );

    // Initialize on first build
    if (_currentEntries.isEmpty && leaderboard.isNotEmpty) {
      _currentEntries = List.of(leaderboard);
      for (int i = 0; i < _currentEntries.length; i++) {
        _previousRanks[_currentEntries[i].userId] = i + 1;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Leaderboard'),
      ),
      body: _currentEntries.isEmpty
          ? const Center(
              child: Text('No scores yet', style: TextStyle(color: Colors.white54)),
            )
          : AnimatedList(
              key: _listKey,
              initialItemCount: _currentEntries.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index, animation) {
                if (index >= _currentEntries.length) {
                  return const SizedBox.shrink();
                }
                final entry = _currentEntries[index];
                final position = index + 1;
                final prevRank = _previousRanks[entry.userId];
                int rankDelta = 0;
                if (prevRank != null) {
                  rankDelta = prevRank - position; // positive = moved up
                }

                return SizeTransition(
                  sizeFactor: animation,
                  child: _LeaderboardRow(
                    entry: entry,
                    position: position,
                    rankDelta: rankDelta,
                    medalColors: _medalColors,
                  ),
                );
              },
            ),
    );
  }

  void _updateList(List<LeaderboardEntry> oldList, List<LeaderboardEntry> newList) {
    // Save current ranks as previous before updating
    for (int i = 0; i < _currentEntries.length; i++) {
      _previousRanks[_currentEntries[i].userId] = i + 1;
    }

    // Remove old items from bottom up
    for (int i = _currentEntries.length - 1; i >= 0; i--) {
      _listKey.currentState?.removeItem(
        i,
        (context, animation) => SizeTransition(
          sizeFactor: animation,
          child: _LeaderboardRow(
            entry: _currentEntries[i],
            position: i + 1,
            rankDelta: 0,
            medalColors: _medalColors,
          ),
        ),
        duration: const Duration(milliseconds: 200),
      );
    }

    _currentEntries = List.of(newList);

    // Insert new items with animation
    Future.delayed(const Duration(milliseconds: 250), () {
      for (int i = 0; i < _currentEntries.length; i++) {
        _listKey.currentState?.insertItem(i, duration: const Duration(milliseconds: 300));
      }
    });
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final int position;
  final int rankDelta;
  final List<Color> medalColors;

  const _LeaderboardRow({
    required this.entry,
    required this.position,
    required this.rankDelta,
    required this.medalColors,
  });

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    if (position <= 3) {
      bgColor = medalColors[position - 1].withValues(alpha: 0.15);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: position <= 3
            ? Border.all(color: medalColors[position - 1].withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 36,
            child: Text(
              '#$position',
              style: TextStyle(
                color: position <= 3 ? medalColors[position - 1] : Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Rank delta arrow
          SizedBox(
            width: 24,
            child: rankDelta != 0
                ? Icon(
                    rankDelta > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    color: rankDelta > 0 ? Colors.greenAccent : Colors.redAccent,
                    size: 18,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),

          // Username
          Expanded(
            child: Text(
              entry.username.isEmpty ? entry.userId : entry.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Score
          Text(
            '${entry.score.toInt()}',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
