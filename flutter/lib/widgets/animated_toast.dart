import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A lightweight overlay toast that slides up from the bottom, fades in, and
/// auto-dismisses. Preferred over ScaffoldMessenger's SnackBar for small
/// confirmation moments (e.g. "Code copied!") because:
///
///   * It doesn't push FAB / bottom nav out of the way.
///   * It uses our AppDurations + AppColors palette, so motion matches the
///     rest of the app.
///   * It renders via Overlay, so it can be called from anywhere without a
///     Scaffold in scope.
///
/// Usage:
///
///   showAnimatedToast(context, message: 'Code copied!', icon: Icons.check);
///
/// Only one toast is visible at a time; calling again while one is showing
/// replaces it.
void showAnimatedToast(
  BuildContext context, {
  required String message,
  IconData icon = Icons.check_circle,
  Color accent = AppColors.success,
  Duration hold = const Duration(milliseconds: 1400),
}) {
  _ToastController.instance.show(
    context: context,
    message: message,
    icon: icon,
    accent: accent,
    hold: hold,
  );
}

class _ToastController {
  _ToastController._();
  static final instance = _ToastController._();

  OverlayEntry? _entry;
  Timer? _hideTimer;
  final GlobalKey<_AnimatedToastState> _key = GlobalKey<_AnimatedToastState>();

  void show({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color accent,
    required Duration hold,
  }) {
    // If there's already a toast up, ask it to dismiss and then show the new
    // one once the old overlay has torn down. This keeps them from stacking.
    if (_entry != null) {
      _hideTimer?.cancel();
      _key.currentState?.playOut(onDone: _disposeEntry);
      // Let the out-animation finish; then reshow.
      Future.delayed(AppDurations.medium, () {
        if (context.mounted) {
          show(
            context: context,
            message: message,
            icon: icon,
            accent: accent,
            hold: hold,
          );
        }
      });
      return;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (_) => _AnimatedToast(
        key: _key,
        message: message,
        icon: icon,
        accent: accent,
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    _hideTimer = Timer(hold, () {
      _key.currentState?.playOut(onDone: _disposeEntry);
    });
  }

  void _disposeEntry() {
    _entry?.remove();
    _entry = null;
    _hideTimer?.cancel();
    _hideTimer = null;
  }
}

class _AnimatedToast extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color accent;
  const _AnimatedToast({
    super.key,
    required this.message,
    required this.icon,
    required this.accent,
  });

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: AppDurations.medium);
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  /// Play the exit animation (reverse of the enter), then invoke [onDone] so
  /// the controller can clean up the OverlayEntry.
  void playOut({required VoidCallback onDone}) {
    _c.reverse().whenComplete(onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 72),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgTop,
                      borderRadius: AppRadius.pill,
                      border: Border.all(color: widget.accent.withAlpha(80)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(120),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, color: widget.accent, size: 18),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
