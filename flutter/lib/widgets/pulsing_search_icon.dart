// PulsingSearchIcon — the centered "searching for opponents" affordance
// used on the matchmaking screen. Two ripples scale outward and fade,
// staggered by 1s; a steady tinted circle holds the magnifying-glass
// icon in the center.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PulsingSearchIcon extends StatefulWidget {
  final double size;
  final IconData icon;
  final Color color;

  const PulsingSearchIcon({
    super.key,
    this.size = 100,
    this.icon = Icons.search_rounded,
    this.color = AppColors.primary,
  });

  @override
  State<PulsingSearchIcon> createState() => _PulsingSearchIconState();
}

class _PulsingSearchIconState extends State<PulsingSearchIcon>
    with TickerProviderStateMixin {
  late final AnimationController _ripple1;
  late final AnimationController _ripple2;

  @override
  void initState() {
    super.initState();
    _ripple1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _ripple2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    // Stagger the second ripple by 1s so the two waves interleave.
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _ripple2.repeat();
    });
  }

  @override
  void dispose() {
    _ripple1.dispose();
    _ripple2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.8,
      height: widget.size * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ripple(_ripple1),
          _ripple(_ripple2),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.12),
              border: Border.all(color: widget.color, width: 2),
            ),
            child: Icon(widget.icon, color: widget.color, size: widget.size * 0.32),
          ),
        ],
      ),
    );
  }

  Widget _ripple(AnimationController c) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final scale = 1.0 + c.value * 0.8;
        final opacity = (1 - c.value).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.18),
              ),
            ),
          ),
        );
      },
    );
  }
}
