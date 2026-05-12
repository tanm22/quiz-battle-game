// CountdownRing — circular timer ring with centered seconds text.
//
// Track `surfaceHi`, progress `primary` (drops to `danger` in the last
// 5s). Stroke 8px with rounded caps. The fill animates 1.0 → 0.0 over
// [duration]. When ≤ 5s, applies a 1.0 → 1.05 → 1.0 scale pulse
// every 500ms.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CountdownRing extends StatefulWidget {
  final Duration duration;
  final double size;
  final VoidCallback? onComplete;
  final bool active;

  const CountdownRing({
    super.key,
    required this.duration,
    this.size = 80,
    this.onComplete,
    this.active = true,
  });

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing>
    with TickerProviderStateMixin {
  late final AnimationController _progress;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: widget.duration);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.active) {
      _progress.forward().whenComplete(() => widget.onComplete?.call());
    }
  }

  @override
  void didUpdateWidget(covariant CountdownRing old) {
    super.didUpdateWidget(old);
    if (old.duration != widget.duration) {
      _progress.duration = widget.duration;
      _progress
        ..reset()
        ..forward().whenComplete(() => widget.onComplete?.call());
    }
    if (old.active != widget.active) {
      if (widget.active) {
        _progress.forward().whenComplete(() => widget.onComplete?.call());
      } else {
        _progress.stop();
      }
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final remaining = (widget.duration * (1 - _progress.value));
        final remainingSeconds = remaining.inMilliseconds / 1000.0;
        final critical = remainingSeconds <= 5.0 && widget.active;

        // Start the pulse once we cross the critical threshold.
        if (critical && !_pulse.isAnimating) {
          _pulse.repeat(reverse: true);
        } else if (!critical && _pulse.isAnimating) {
          _pulse.stop();
          _pulse.value = 0;
        }

        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final scale = 1.0 + (_pulse.value * 0.05);
            return Transform.scale(scale: scale, child: child);
          },
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _RingPainter(
                progress: 1 - _progress.value,
                trackColor: AppColors.surfaceHi,
                fillColor: critical ? AppColors.danger : AppColors.primary,
                stroke: 8,
              ),
              child: Center(
                child: Text(
                  remainingSeconds.ceil().toString(),
                  style: AppText.h1.copyWith(
                    color: critical ? AppColors.danger : AppColors.text,
                  ),
                ),
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
  final Color trackColor;
  final Color fillColor;
  final double stroke;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor ||
      old.stroke != stroke;
}
