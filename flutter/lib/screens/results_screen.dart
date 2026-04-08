import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final match = gameState.matchResult;

    if (match == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))));
    }

    final myResult = match.players.where((p) => p.userId == gameState.userId).firstOrNull;
    final isWinner = match.winner == gameState.userId;
    final opponentLeft = match.rounds == -1;

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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Winner badge
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: opponentLeft
                          ? [const Color(0xFFFF6B35), const Color(0xFFFF8F5E)]
                          : isWinner
                              ? [const Color(0xFFFFD700), const Color(0xFFFFA000)]
                              : [Colors.white.withAlpha(20), Colors.white.withAlpha(10)],
                    ),
                    boxShadow: isWinner
                        ? [BoxShadow(color: const Color(0xFFFFD700).withAlpha(80), blurRadius: 40)]
                        : null,
                  ),
                  child: Icon(
                    opponentLeft ? Icons.person_off : isWinner ? Icons.emoji_events : Icons.sports_score,
                    size: 56,
                    color: isWinner || opponentLeft ? Colors.white : Colors.white54,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  opponentLeft ? 'Opponent Left' : isWinner ? 'VICTORY!' : 'DEFEAT',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: opponentLeft ? const Color(0xFFFF6B35) : isWinner ? const Color(0xFFFFD700) : Colors.white70,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  opponentLeft ? 'You win by default!' : 'Winner: ${match.winner}',
                  style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 15),
                ),

                const SizedBox(height: 32),

                // Stats card
                if (myResult != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withAlpha(15)),
                    ),
                    child: Column(
                      children: [
                        _StatRow('Final Score', '${myResult.finalScore.toInt()}', const Color(0xFFFFD700)),
                        _StatRow('Rank', '#${myResult.rank}', const Color(0xFF00E5FF)),
                        _StatRow('Correct', '${myResult.answersCorrect}', const Color(0xFF4CAF50)),
                        _StatRow('Avg Speed', '${myResult.avgResponseTimeMs.toInt()} ms', const Color(0xFFFF6B35)),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // All players
                Expanded(
                  child: ListView.builder(
                    itemCount: match.players.length,
                    itemBuilder: (context, index) {
                      final p = match.players[index];
                      final isSelf = p.userId == gameState.userId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelf ? const Color(0xFFFF6B35).withAlpha(15) : Colors.white.withAlpha(5),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelf ? Border.all(color: const Color(0xFFFF6B35).withAlpha(60)) : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == 0 ? const Color(0xFFFFD700).withAlpha(30) : Colors.white.withAlpha(10),
                              ),
                              child: Center(child: Text(
                                '#${p.rank}',
                                style: TextStyle(
                                  color: index == 0 ? const Color(0xFFFFD700) : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p.username.isEmpty ? p.userId : p.username,
                                style: TextStyle(color: isSelf ? Colors.white : Colors.white70, fontSize: 15, fontWeight: isSelf ? FontWeight.bold : FontWeight.normal),
                              ),
                            ),
                            Text(
                              '${p.finalScore.toInt()}',
                              style: TextStyle(
                                color: index == 0 ? const Color(0xFFFFD700) : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Play Again
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8F5E)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withAlpha(100), blurRadius: 20, offset: const Offset(0, 6))],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => ref.read(gameStateProvider.notifier).playAgain(),
                      icon: const Icon(Icons.replay),
                      label: const Text('PLAY AGAIN', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatRow(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 15)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
