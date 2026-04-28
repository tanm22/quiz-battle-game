import 'package:flutter/material.dart';

/// AnimatedCounter — tweens an integer (or formatted-string) value
/// from a previous render to a new one, so coin balances, scores, and
/// stat numbers roll up smoothly instead of snapping. Mirrors the
/// SpeakX-style "watch the number tick up" micro-interaction that
/// signals reward-just-applied / state-just-changed.
///
/// Pass [value] as the current target; the widget remembers the
/// previously rendered value internally and tweens between them on
/// every change. Animation duration defaults to 600ms with an
/// easeOutCubic curve — fast enough to feel responsive but long
/// enough to read.
class AnimatedCounter extends StatefulWidget {
  final num value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final int decimalPlaces;
  final Duration duration;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimalPlaces = 0,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  num _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(
      begin: widget.value.toDouble(),
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  @override
  void didUpdateWidget(AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _previousValue = old.value;
      _animation = Tween<double>(
        begin: _previousValue.toDouble(),
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final n = _animation.value;
        final body = widget.decimalPlaces == 0
            ? n.round().toString()
            : n.toStringAsFixed(widget.decimalPlaces);
        return Text(
          '${widget.prefix}$body${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}
