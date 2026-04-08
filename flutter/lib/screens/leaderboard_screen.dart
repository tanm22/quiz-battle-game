import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';
import '../proto/quiz.pb.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final _listKey = GlobalKey<AnimatedListState>();
  List<LeaderboardEntry> _currentEntries = [];
  final Map<String, int> _previousRanks = {};

  static const _medalColors = [
    Color(0xFFFFD700), // Gold
    Color(0xFFC0C0C0), // Silver
    Color(0xFFCD7F32), // Bronze
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen(
      gameStateProvider.select((s) => s.leaderboard),
      (prev, next) => _updateList(prev ?? [], next),
    );

    final leaderboard = ref.watch(gameStateProvider.select((s) => s.leaderboard));
    if (_currentEntries.isEmpty && leaderboard.isNotEmpty) {
      _currentEntries = List.of(leaderboard);
      for (int i = 0; i < _currentEntries.length; i++) {
        _previousRanks[_currentEntries[i].userId] = i + 1;
      }
    }

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
                child: _currentEntries.isEmpty
                    ? Center(child: Text('No scores yet', style: TextStyle(color: Colors.white.withAlpha(100))))
                    : AnimatedList(
                        key: _listKey,
                        initialItemCount: _currentEntries.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index, animation) {
                          if (index >= _currentEntries.length) return const SizedBox.shrink();
                          final entry = _currentEntries[index];
                          final position = index + 1;
                          final prevRank = _previousRanks[entry.userId];
                          final rankDelta = prevRank != null ? prevRank - position : 0;

                          return SizeTransition(
                            sizeFactor: animation,
                            child: _LeaderboardRow(
                              entry: entry, position: position, rankDelta: rankDelta, medalColors: _medalColors,
                            ),
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

  void _updateList(List<LeaderboardEntry> oldList, List<LeaderboardEntry> newList) {
    for (int i = 0; i < _currentEntries.length; i++) {
      _previousRanks[_currentEntries[i].userId] = i + 1;
    }
    for (int i = _currentEntries.length - 1; i >= 0; i--) {
      _listKey.currentState?.removeItem(
        i,
        (context, animation) => SizeTransition(
          sizeFactor: animation,
          child: _LeaderboardRow(entry: _currentEntries[i], position: i + 1, rankDelta: 0, medalColors: _medalColors),
        ),
        duration: const Duration(milliseconds: 200),
      );
    }
    _currentEntries = List.of(newList);
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
  const _LeaderboardRow({required this.entry, required this.position, required this.rankDelta, required this.medalColors});

  @override
  Widget build(BuildContext context) {
    final isMedal = position <= 3;
    final medalColor = isMedal ? medalColors[position - 1] : null;

    return Container(
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

          // Rank delta
          SizedBox(
            width: 28,
            child: rankDelta != 0
                ? Icon(rankDelta > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    color: rankDelta > 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF4444), size: 18)
                : const SizedBox.shrink(),
          ),

          // Username
          Expanded(
            child: Text(
              entry.username.isEmpty ? entry.userId : entry.username,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),

          // Score
          Text(
            '${entry.score.toInt()}',
            style: TextStyle(color: isMedal ? medalColor : Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
