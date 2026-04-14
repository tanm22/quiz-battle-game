import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../proto/quiz.pb.dart';
import '../providers/game_state.dart';

const _optionColors = [
  Color(0xFFFF6B35), // A - orange
  Color(0xFF00BCD4), // B - cyan
  Color(0xFF9C27B0), // C - purple
  Color(0xFF4CAF50), // D - green
];

const _optionLabels = ['A', 'B', 'C', 'D'];

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
    _timerController = AnimationController(vsync: this, duration: const Duration(seconds: 15));
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

    ref.listen(
      gameStateProvider.select((s) => s.deadlineUnix),
      (prev, next) {
        if (next > 0 && next != prev) _resetTimer(next);
      },
    );

    if (question == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))),
      );
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
              // Top bar: round + leave
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFF6B35).withAlpha(80)),
                      ),
                      child: Text(
                        gameState.totalRounds > 0
                            ? 'Round ${gameState.round}/${gameState.totalRounds}'
                            : 'Round ${gameState.round}',
                        style: const TextStyle(color: Color(0xFFFF8F5E), fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white38),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF2A1F5E),
                            title: const Text('Leave match?', style: TextStyle(color: Colors.white)),
                            content: const Text('You will forfeit this match.', style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
                              TextButton(
                                onPressed: () { Navigator.pop(ctx); ref.read(gameStateProvider.notifier).leaveMatch(); },
                                child: const Text('Leave', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Countdown ring
              SizedBox(
                height: 90,
                width: 90,
                child: AnimatedBuilder(
                  animation: _timerController,
                  builder: (context, child) {
                    final remaining = (1.0 - _timerController.value) * (_timerController.duration?.inSeconds ?? 15);
                    return CustomPaint(
                      painter: _CountdownRingPainter(
                        progress: 1.0 - _timerController.value,
                        isUrgent: remaining <= 3,
                      ),
                      child: Center(
                        child: Text(
                          '${remaining.ceil()}',
                          style: TextStyle(
                            color: remaining <= 3 ? const Color(0xFFFF4444) : Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Question card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withAlpha(20)),
                  ),
                  child: Text(
                    question.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Option buttons
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                            ref.read(gameStateProvider.notifier).toggleAnswer(index);
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // Mini leaderboard
              _MiniLeaderboard(entries: gameState.leaderboard),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  final double progress;
  final bool isUrgent;
  _CountdownRingPainter({required this.progress, required this.isUrgent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 5;

    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    if (isUrgent) {
      fgPaint.color = const Color(0xFFFF4444);
    } else {
      fgPaint.shader = const SweepGradient(
        colors: [Color(0xFF00E5FF), Color(0xFFFF6B35)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isUrgent != isUrgent;
}

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

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    final roundResolved = correctIndex != null;
    final isCorrect = index == correctIndex;
    final isWrong = roundResolved && isSelected && !isCorrect;
    final baseColor = _optionColors[index % _optionColors.length];

    Color bgColor;
    Color borderColor;
    Color textColor = Colors.white;

    if (roundResolved) {
      if (isCorrect) {
        bgColor = const Color(0xFF4CAF50).withAlpha(50);
        borderColor = const Color(0xFF4CAF50);
      } else if (isWrong) {
        bgColor = const Color(0xFFFF4444).withAlpha(50);
        borderColor = const Color(0xFFFF4444);
      } else {
        bgColor = Colors.white.withAlpha(5);
        borderColor = Colors.white.withAlpha(15);
        textColor = Colors.white38;
      }
    } else if (isSelected) {
      bgColor = baseColor.withAlpha(40);
      borderColor = baseColor;
    } else {
      bgColor = Colors.white.withAlpha(8);
      borderColor = Colors.white.withAlpha(25);
    }

    return GestureDetector(
      onTap: roundResolved ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected && !roundResolved ? 2.5 : 1.5),
        ),
        child: Row(
          children: [
            // Option label badge
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected && !roundResolved ? baseColor : baseColor.withAlpha(40),
              ),
              child: Center(
                child: Text(
                  _optionLabels[index % _optionLabels.length],
                  style: TextStyle(
                    color: isSelected && !roundResolved ? Colors.white : baseColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(text, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            if (roundResolved && isCorrect)
              const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
            if (isWrong)
              const Icon(Icons.cancel, color: Color(0xFFFF4444), size: 24),
          ],
        ),
      ),
    );
  }
}

class _MiniLeaderboard extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  const _MiniLeaderboard({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final sorted = entries.toList()..sort((a, b) => b.score.compareTo(a.score));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(10), Colors.white.withAlpha(5)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: sorted.take(4).indexed.map((item) {
          final (i, e) = item;
          final name = e.username.isNotEmpty ? e.username : e.userId;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i == 0) const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name.length > 8 ? '${name.substring(0, 8)}..' : name,
                    style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (e.plan == 'premium')
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Icon(Icons.workspace_premium, color: const Color(0xFFFFD700), size: 12),
                    ),
                ],
              ),
              Text(
                '${e.score.toInt()}',
                style: TextStyle(
                  color: i == 0 ? const Color(0xFFFFD700) : Colors.white,
                  fontSize: 17,
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
