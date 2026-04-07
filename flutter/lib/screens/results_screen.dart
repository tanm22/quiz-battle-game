import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';

/// Step 67: Results screen — winner display, personal stats, Play Again button.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final match = gameState.matchResult;

    if (match == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Find current player's result
    final myResult = match.players
        .where((p) => p.userId == gameState.userId)
        .firstOrNull;

    final isWinner = match.winner == gameState.userId;
    final opponentLeft = match.rounds == -1;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Winner announcement
              Icon(
                opponentLeft
                    ? Icons.person_off
                    : isWinner
                        ? Icons.emoji_events
                        : Icons.sports_score,
                size: 72,
                color: opponentLeft
                    ? Colors.orange
                    : isWinner
                        ? Colors.amber
                        : Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                opponentLeft
                    ? 'Opponent Left'
                    : isWinner
                        ? 'You Won!'
                        : 'Match Over',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: opponentLeft
                      ? Colors.orange
                      : isWinner
                          ? Colors.amber
                          : Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                opponentLeft
                    ? 'You win by default!'
                    : 'Winner: ${match.winner}',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),

              const SizedBox(height: 40),

              // Personal stats
              if (myResult != null) ...[
                _StatCard(
                  children: [
                    _StatRow('Final Score', '${myResult.finalScore.toInt()}'),
                    _StatRow('Rank', '#${myResult.rank}'),
                    _StatRow('Correct Answers', '${myResult.answersCorrect}'),
                    _StatRow(
                      'Avg Response',
                      '${myResult.avgResponseTimeMs.toInt()} ms',
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // All players summary
              Expanded(
                child: ListView.builder(
                  itemCount: match.players.length,
                  itemBuilder: (context, index) {
                    final p = match.players[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: index == 0
                            ? Colors.amber
                            : Colors.white24,
                        child: Text(
                          '#${p.rank}',
                          style: TextStyle(
                            color: index == 0 ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        p.username.isEmpty ? p.userId : p.username,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Text(
                        '${p.finalScore.toInt()}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Play Again button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(gameStateProvider.notifier).playAgain();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Play Again',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final List<Widget> children;
  const _StatCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: children),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 16)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
