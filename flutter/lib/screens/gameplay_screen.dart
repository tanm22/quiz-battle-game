import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../proto/quiz.pb.dart';
import '../providers/game_state.dart';
import '../theme/app_theme.dart';

// ─── Lively option palette ───────────────────────────────────────────────────
const _optionColors = [
  Color(0xFFFF7043), // A - warm coral
  Color(0xFF26C6DA), // B - bright cyan
  Color(0xFFAB47BC), // C - vivid purple
  Color(0xFF66BB6A), // D - fresh green
];
const _optionLabels = ['A', 'B', 'C', 'D'];

// ═════════════════════════════════════════════════════════════════════════════
// GameplayScreen
// ═════════════════════════════════════════════════════════════════════════════

class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({super.key});

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen>
    with TickerProviderStateMixin {
  late AnimationController _timerController;
  late AnimationController _revealController;
  late Animation<double> _revealCurve;

  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _currentStepKey = GlobalKey();

  // Track per-round results so completed checkpoints show ✓ or ✗.
  final Map<int, bool> _roundResults = {};

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(vsync: this, duration: const Duration(seconds: 15));
    _revealController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _revealCurve = CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic);

    // Reveal question card on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealController.forward());
  }

  @override
  void dispose() {
    _timerController.dispose();
    _revealController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _resetTimer(int deadlineUnix) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = deadlineUnix - now;
    if (remaining <= 0) return;
    _timerController.duration = Duration(seconds: remaining);
    _timerController.forward(from: 0.0);
  }

  void _onRoundChanged(int? prevRound, int newRound) {
    if (prevRound == null || newRound <= prevRound) return;

    // 1. Reset reveal for the new question.
    _revealController.reset();

    // 2. After a tick, scroll to the new checkpoint, then reveal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentStepKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          alignment: 0.15,
        ).then((_) => _revealController.forward());
      } else {
        _revealController.forward();
      }
    });
  }

  void _captureResult(int round, int? correctIdx, int? selectedIdx) {
    if (correctIdx != null && selectedIdx != null && !_roundResults.containsKey(round)) {
      _roundResults[round] = correctIdx == selectedIdx;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);
    final question = gs.currentQuestion;

    // ── Listeners ──
    ref.listen(gameStateProvider.select((s) => s.deadlineUnix), (prev, next) {
      if (next > 0 && next != prev) _resetTimer(next);
    });
    ref.listen(gameStateProvider.select((s) => s.round), (prev, next) {
      _onRoundChanged(prev, next);
    });
    ref.listen(
      gameStateProvider.select((s) => (s.round, s.correctIndex, s.selectedIndex)),
      (prev, next) => _captureResult(next.$1, next.$2, next.$3),
    );

    if (question == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.accent)));
    }

    final totalRounds = gs.totalRounds > 0 ? gs.totalRounds : 5;
    final currentRound = gs.round;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.scaffold,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ═══════════════════════════════════════════════════════════
              //  LEADERBOARD (fixed at top)
              // ═══════════════════════════════════════════════════════════
              _LeaderboardCard(
                entries: gs.leaderboard,
                currentUserId: gs.userId ?? '',
                onLeave: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: const Text('Leave match?', style: TextStyle(color: AppColors.text)),
                      content: const Text('You will forfeit this match.', style: TextStyle(color: AppColors.textSecondary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Stay', style: TextStyle(color: AppColors.accent))),
                        TextButton(
                          onPressed: () { Navigator.pop(ctx); ref.read(gameStateProvider.notifier).leaveMatch(); },
                          child: const Text('Leave', style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              // ═══════════════════════════════════════════════════════════
              //  JOURNEY (scrollable checkpoint path)
              // ═══════════════════════════════════════════════════════════
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                  child: Column(
                    children: [
                      for (int r = 1; r <= totalRounds; r++) ...[
                        // Connector line ABOVE the node (not for first)
                        if (r > 1)
                          _Connector(completed: r <= currentRound),

                        // Checkpoint step
                        _StepHeader(
                          key: r == currentRound ? _currentStepKey : null,
                          round: r,
                          isCompleted: r < currentRound,
                          isCurrent: r == currentRound,
                          isUpcoming: r > currentRound,
                          wasCorrect: _roundResults[r],
                          timerController: r == currentRound ? _timerController : null,
                        ),

                        // Current round: animated question card
                        if (r == currentRound)
                          FadeTransition(
                            opacity: _revealCurve,
                            child: SizeTransition(
                              sizeFactor: _revealCurve,
                              axisAlignment: -1,
                              child: _QuestionCard(
                                question: question,
                                selectedIndex: gs.selectedIndex,
                                correctIndex: gs.correctIndex,
                                onTap: (i) => ref.read(gameStateProvider.notifier).toggleAnswer(i),
                              ),
                            ),
                          ),
                      ],
                    ],
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

// ═════════════════════════════════════════════════════════════════════════════
// Leaderboard card (top section)
// ═════════════════════════════════════════════════════════════════════════════

class _LeaderboardCard extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String currentUserId;
  final VoidCallback onLeave;

  const _LeaderboardCard({
    required this.entries,
    required this.currentUserId,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = entries.toList()..sort((a, b) => b.score.compareTo(a.score));

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: appCardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.leaderboard_rounded, color: AppColors.gold, size: 18),
              const SizedBox(width: 6),
              const Text('STANDINGS', style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const Spacer(),
              const Text('LIVE', style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(width: 4),
              Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.danger)),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.textDim, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onLeave,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Player rows
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Waiting for scores...', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
            )
          else
            ...sorted.asMap().entries.map((e) {
              final rank = e.key;
              final entry = e.value;
              final isSelf = entry.userId == currentUserId;
              return _LeaderboardRow(entry: entry, rank: rank + 1, isSelf: isSelf);
            }),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final bool isSelf;
  const _LeaderboardRow({required this.entry, required this.rank, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    final name = entry.username.isNotEmpty ? entry.username : entry.userId;
    Color rankBg = rank == 1
        ? AppColors.gold
        : (rank == 2 ? AppColors.medalSilver : AppColors.border);

    return AnimatedContainer(
      duration: AppDurations.medium,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelf ? AppColors.accentBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelf ? Border.all(color: AppColors.accent.withAlpha(50)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle, color: rankBg),
            child: Center(
              child: rank == 1
                  ? const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 14)
                  : Text('#$rank', style: TextStyle(
                      color: rank == 2 ? Colors.white : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    )),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(name, overflow: TextOverflow.ellipsis, style: TextStyle(
                    color: isSelf ? AppColors.text : AppColors.textSecondary, fontSize: 13,
                    fontWeight: isSelf ? FontWeight.w700 : FontWeight.w500,
                  )),
                ),
                if (entry.plan == 'premium') ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.goldBg, borderRadius: BorderRadius.circular(5), border: Border.all(color: AppColors.gold.withAlpha(80))),
                    child: const Text('PRO', style: TextStyle(color: AppColors.gold, fontSize: 8, fontWeight: FontWeight.w700)),
                  ),
                ],
                if (isSelf) ...[
                  const SizedBox(width: 4),
                  Text('(you)', style: TextStyle(color: AppColors.accent.withAlpha(160), fontSize: 10)),
                ],
              ],
            ),
          ),
          _AnimatedScore(score: entry.score),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Journey components — checkpoint path with scroll-open question
// ═════════════════════════════════════════════════════════════════════════════

/// Vertical connector line between checkpoint nodes.
class _Connector extends StatelessWidget {
  final bool completed;
  const _Connector({required this.completed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 15), // center of the 34px node
        child: Container(
          width: 3,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: completed ? AppColors.success.withAlpha(180) : AppColors.border,
          ),
        ),
      ),
    );
  }
}

/// A single checkpoint node row.
class _StepHeader extends StatefulWidget {
  final int round;
  final bool isCompleted;
  final bool isCurrent;
  final bool isUpcoming;
  final bool? wasCorrect;
  final AnimationController? timerController;

  const _StepHeader({
    super.key,
    required this.round,
    required this.isCompleted,
    required this.isCurrent,
    required this.isUpcoming,
    this.wasCorrect,
    this.timerController,
  });

  @override
  State<_StepHeader> createState() => _StepHeaderState();
}

class _StepHeaderState extends State<_StepHeader> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    if (widget.isCurrent) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StepHeader old) {
    super.didUpdateWidget(old);
    if (widget.isCurrent && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isCurrent && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // ── Node circle ──
          _buildNode(),
          const SizedBox(width: 12),
          // ── Round label ──
          Text(
            'Round ${widget.round}',
            style: TextStyle(
              color: widget.isCurrent
                  ? AppColors.text
                  : widget.isCompleted
                      ? AppColors.textSecondary
                      : AppColors.textDim,
              fontSize: 14,
              fontWeight: widget.isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          // Result tag for completed rounds
          if (widget.isCompleted && widget.wasCorrect != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.wasCorrect! ? AppColors.emeraldBg : AppColors.roseBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.wasCorrect! ? 'Correct' : 'Wrong',
                style: TextStyle(color: widget.wasCorrect! ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const Spacer(),
          // Timer for current round
          if (widget.isCurrent && widget.timerController != null)
            _CompactTimer(controller: widget.timerController!),
        ],
      ),
    );
  }

  Widget _buildNode() {
    const size = 34.0;

    if (widget.isCompleted) {
      return Container(
        width: size, height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.success, Color(0xFF34D399)]),
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
      );
    }

    if (widget.isCurrent) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final glow = _pulse.value * 0.6;
          return Container(
            width: size + 4, height: size + 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [AppColors.primarySoft, AppColors.primary]),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha((50 + 60 * glow).toInt()),
                  blurRadius: 12 + 8 * glow,
                  spreadRadius: 1 + 2 * glow,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${widget.round}',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ),
          );
        },
      );
    }

    // Upcoming
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cardTint,
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Center(
        child: Icon(Icons.lock_rounded, color: AppColors.textDim, size: 15),
      ),
    );
  }
}

/// The question card + options that "unfurls" at the current checkpoint.
class _QuestionCard extends StatelessWidget {
  final QuestionBroadcast question;
  final int? selectedIndex;
  final int? correctIndex;
  final ValueChanged<int> onTap;

  const _QuestionCard({
    required this.question,
    required this.selectedIndex,
    required this.correctIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8, top: 10, bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withAlpha(30)),
        boxShadow: [
          BoxShadow(color: AppColors.accent.withAlpha(12), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              question.text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
          const SizedBox(height: 14),
          // Options
          ...List.generate(question.options.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionButton(
                text: question.options[i],
                index: i,
                selectedIndex: selectedIndex,
                correctIndex: correctIndex,
                onTap: () => onTap(i),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Compact timer ring
// ═════════════════════════════════════════════════════════════════════════════

class _CompactTimer extends StatelessWidget {
  final AnimationController controller;
  const _CompactTimer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final remaining = (1.0 - controller.value) * (controller.duration?.inSeconds ?? 15);
        final isUrgent = remaining <= 3;
        return SizedBox(
          width: 38, height: 38,
          child: CustomPaint(
            painter: _RingPainter(progress: 1.0 - controller.value, isUrgent: isUrgent),
            child: Center(
              child: Text(
                '${remaining.ceil()}',
                style: TextStyle(color: isUrgent ? AppColors.danger : AppColors.text, fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isUrgent;
  _RingPainter({required this.progress, required this.isUrgent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 3;
    canvas.drawCircle(center, radius, Paint()..color = AppColors.border..style = PaintingStyle.stroke..strokeWidth = 3.5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius), -pi / 2, 2 * pi * progress, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round..color = isUrgent ? AppColors.danger : AppColors.secondary,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.isUrgent != isUrgent;
}

// ═════════════════════════════════════════════════════════════════════════════
// Animated score pop
// ═════════════════════════════════════════════════════════════════════════════

class _AnimatedScore extends StatefulWidget {
  final double score;
  const _AnimatedScore({required this.score});

  @override
  State<_AnimatedScore> createState() => _AnimatedScoreState();
}

class _AnimatedScoreState extends State<_AnimatedScore> with SingleTickerProviderStateMixin {
  late AnimationController _pop;
  late Animation<double> _scale;
  double _prev = 0;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 65),
    ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOut));
    _prev = widget.score;
  }

  @override
  void dispose() { _pop.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(covariant _AnimatedScore old) {
    super.didUpdateWidget(old);
    if (widget.score != old.score) { _prev = old.score; _pop.forward(from: 0); }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pop,
      builder: (context, _) => Transform.scale(
        scale: _scale.value,
        child: Text(
          '${widget.score.toInt()}',
          style: TextStyle(
            color: _pop.isAnimating ? (widget.score > _prev ? AppColors.success : AppColors.danger) : AppColors.text,
            fontSize: 16, fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Option button
// ═════════════════════════════════════════════════════════════════════════════

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
    Color textColor = AppColors.text;

    if (roundResolved) {
      if (isCorrect) {
        bgColor = AppColors.emeraldBg;
        borderColor = AppColors.success;
      } else if (isWrong) {
        bgColor = AppColors.roseBg;
        borderColor = AppColors.danger;
      } else {
        bgColor = AppColors.cardTint;
        borderColor = AppColors.border;
        textColor = AppColors.textDim;
      }
    } else if (isSelected) {
      bgColor = baseColor.withAlpha(20);
      borderColor = baseColor;
    } else {
      bgColor = AppColors.surface;
      borderColor = AppColors.border;
    }

    return GestureDetector(
      onTap: roundResolved ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected && !roundResolved ? 2.5 : 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected && !roundResolved ? baseColor : baseColor.withAlpha(25),
              ),
              child: Center(child: Text(
                _optionLabels[index % _optionLabels.length],
                style: TextStyle(color: isSelected && !roundResolved ? Colors.white : baseColor, fontWeight: FontWeight.bold, fontSize: 13),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500))),
            if (roundResolved && isCorrect) const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
            if (isWrong) const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 22),
          ],
        ),
      ),
    );
  }
}
