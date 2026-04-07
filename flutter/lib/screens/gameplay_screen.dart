import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';

/// Steps 62-65: Gameplay screen with countdown ring, option buttons,
/// optimistic answer UI, and mini leaderboard overlay.
class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({super.key});

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerController;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  void _resetTimer(int deadlineUnix) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = deadlineUnix - now;
    if (remaining <= 0) return;

    _timerController.duration = Duration(seconds: remaining);
    _timerController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final question = gameState.currentQuestion;

    // Step 62: Reset timer on new QuestionBroadcast
    ref.listen(
      gameStateProvider.select((s) => s.deadlineUnix),
      (prev, next) {
        if (next > 0 && next != prev) {
          _resetTimer(next);
        }
      },
    );

    if (question == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // Round indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Round ${gameState.round} / 5',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Step 63: Countdown ring
            SizedBox(
              height: 100,
              width: 100,
              child: AnimatedBuilder(
                animation: _timerController,
                builder: (context, child) {
                  final remaining = (1.0 - _timerController.value) *
                      (_timerController.duration?.inSeconds ?? 15);
                  return CustomPaint(
                    painter: _CountdownRingPainter(
                      progress: 1.0 - _timerController.value,
                      isUrgent: remaining <= 3,
                    ),
                    child: Center(
                      child: Text(
                        '${remaining.ceil()}',
                        style: TextStyle(
                          color: remaining <= 3 ? Colors.red : Colors.amber,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Question text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                question.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Step 64: Option buttons
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: List.generate(question.options.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OptionButton(
                        text: question.options[index],
                        index: index,
                        selectedIndex: gameState.selectedIndex,
                        correctIndex: gameState.correctIndex,
                        onTap: () {
                          ref
                              .read(gameStateProvider.notifier)
                              .selectAnswer(index);
                        },
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Step 65: Mini leaderboard overlay
            _MiniLeaderboard(scores: gameState.scores),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 63: Countdown ring CustomPainter
// ---------------------------------------------------------------------------

class _CountdownRingPainter extends CustomPainter {
  final double progress; // 1.0 = full, 0.0 = empty
  final bool isUrgent;

  _CountdownRingPainter({required this.progress, required this.isUrgent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc: amber → red in final 3s
    final fgPaint = Paint()
      ..color = isUrgent ? Colors.red : Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // start at top
      2 * pi * progress, // sweep
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isUrgent != isUrgent;
  }
}

// ---------------------------------------------------------------------------
// Step 64: Option button with optimistic UI
// ---------------------------------------------------------------------------

class _OptionButton extends StatelessWidget {
  final String text;
  final int index;
  final int? selectedIndex;
  final int? correctIndex;
  final VoidCallback onTap;

  const _OptionButton({
    required this.text,
    required this.index,
    required this.selectedIndex,
    required this.correctIndex,
    required this.onTap,
  });

  Color _getColor() {
    if (correctIndex != null) {
      // RoundResult received — show correct/wrong
      if (index == correctIndex) return Colors.green;
      if (index == selectedIndex) return Colors.red;
      return Colors.white12;
    }
    if (index == selectedIndex) {
      // Optimistic: selected but not yet confirmed
      return Colors.amber.withValues(alpha: 0.6);
    }
    return Colors.white12;
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = selectedIndex != null;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getColor(),
          disabledBackgroundColor: _getColor(),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 65: Mini leaderboard overlay
// ---------------------------------------------------------------------------

class _MiniLeaderboard extends StatelessWidget {
  final Map<String, double> scores;

  const _MiniLeaderboard({required this.scores});

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) return const SizedBox.shrink();

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: sorted.take(4).map((e) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                e.key,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${e.value.toInt()}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
