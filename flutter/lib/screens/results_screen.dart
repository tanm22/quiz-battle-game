import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';
import '../theme/app_theme.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebrationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _celebrationController, curve: Curves.easeOut));
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.easeIn),
    );
    _celebrationController.forward();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final match = gameState.matchResult;

    if (match == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final myResult = match.players.where((p) => p.userId == gameState.userId).firstOrNull;
    final isWinner = match.winner == gameState.userId;
    final opponentLeft = match.rounds == -1;

    // Find winner's username for display
    final winnerPlayer = match.players.where((p) => p.userId == match.winner).firstOrNull;
    final winnerName = winnerPlayer != null && winnerPlayer.username.isNotEmpty
        ? winnerPlayer.username
        : match.winner;

    return Scaffold(
      body: ScaffoldGradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Animated winner badge
                AnimatedBuilder(
                  animation: _celebrationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: opponentLeft
                                ? [AppColors.primarySoft, AppColors.primary]
                                : isWinner
                                    ? [const Color(0xFFF59E0B), AppColors.gold]
                                    : [AppColors.border, AppColors.border],
                          ),
                          boxShadow: isWinner || opponentLeft
                              ? [BoxShadow(
                                  color: (isWinner ? AppColors.gold : AppColors.primary)
                                      .withAlpha((60 * _glowAnimation.value).toInt()),
                                  blurRadius: 40 + 20 * _glowAnimation.value,
                                  spreadRadius: 5 * _glowAnimation.value,
                                )]
                              : null,
                        ),
                        child: Icon(
                          opponentLeft ? Icons.person_off : isWinner ? Icons.emoji_events : Icons.sports_score,
                          size: 56,
                          color: isWinner || opponentLeft ? Colors.white : AppColors.textMuted,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  opponentLeft ? 'Opponent Left' : isWinner ? 'VICTORY!' : 'DEFEAT',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: opponentLeft ? AppColors.primary : isWinner ? AppColors.gold : AppColors.textMuted,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  opponentLeft ? 'You win by default!' : 'Winner: $winnerName',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),

                const SizedBox(height: 32),

                // Stats card
                if (myResult != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: appCardDecoration(),
                    child: Column(
                      children: [
                        _StatRow('Final Score', '${myResult.finalScore.toInt()}', AppColors.gold),
                        _StatRow('Rank', '#${myResult.rank}', AppColors.secondary),
                        _StatRow('Correct', '${myResult.answersCorrect}', AppColors.success),
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
                          color: isSelf ? AppColors.accentBg : AppColors.surface,
                          borderRadius: AppRadius.card,
                          border: Border.all(
                            color: isSelf ? AppColors.accent.withAlpha(60) : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == 0 ? AppColors.goldBg : AppColors.cardTint,
                              ),
                              child: Center(child: Text(
                                '#${p.rank}',
                                style: TextStyle(
                                  color: index == 0 ? AppColors.gold : AppColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(child: Text(
                                    p.username.isEmpty ? p.userId : p.username,
                                    style: TextStyle(
                                      color: isSelf ? AppColors.text : AppColors.textSecondary,
                                      fontSize: 15,
                                      fontWeight: isSelf ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  )),
                                  if (p.plan == 'premium') ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'PRO',
                                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              '${p.finalScore.toInt()}',
                              style: TextStyle(
                                color: index == 0 ? AppColors.gold : AppColors.text,
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
                      gradient: AppGradients.primary,
                      borderRadius: AppRadius.hero,
                      boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 20, offset: const Offset(0, 6))],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => ref.read(gameStateProvider.notifier).playAgain(),
                      icon: const Icon(Icons.replay),
                      label: const Text('PLAY AGAIN', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.hero),
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
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 15)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
