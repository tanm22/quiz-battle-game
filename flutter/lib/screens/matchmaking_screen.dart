import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';
import '../theme/app_theme.dart';

/// MatchmakingScreen — UX styled after the MANAS-exe/QUIZ_BATTLE_SYSTEM
/// reference. The center search affordance is now a multi-ring pulse
/// radar (two outer rings + a spinning dashed ring + a glowing coral
/// orb), matching the reference's `_buildPulseRadar`. The error state
/// retains its retry-or-cancel card (visual refresh only). All RPC
/// wiring (joinMatchmaking, leaveMatch, errorMessage) is unchanged.
class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _spinController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    // Pulse: outer-ring expand-and-fade, looped.
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulseScale = Tween<double>(begin: 0.85, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    // Spin: slow continuous rotation for the dashed inner ring.
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    // Auto-start matchmaking when this screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSearch());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  void _startSearch() {
    final gameState = ref.read(gameStateProvider);
    final userId = gameState.userId;
    if (userId == null) return;
    if (!_pulseController.isAnimating) _pulseController.repeat();
    if (!_spinController.isAnimating) _spinController.repeat();
    ref
        .read(gameStateProvider.notifier)
        .joinMatchmaking(userId, gameState.rating);
  }

  void _retry() {
    ref.read(gameStateProvider.notifier).clearError();
    _startSearch();
  }

  void _cancel() {
    _pulseController.stop();
    _pulseController.reset();
    _spinController.stop();
    _spinController.reset();
    ref.read(gameStateProvider.notifier).leaveMatch();
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage =
        ref.watch(gameStateProvider.select((s) => s.errorMessage));

    // When we enter an error state, stop the pulse so it doesn't keep
    // burning frames underneath the retry card.
    if (errorMessage != null && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
      _spinController.stop();
      _spinController.reset();
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: AnimatedSwitcher(
              duration: AppDurations.medium,
              child: errorMessage != null
                  ? _ErrorView(
                      key: const ValueKey('error'),
                      message: errorMessage,
                      onRetry: _retry,
                      onCancel: _cancel,
                    )
                  : _SearchingView(
                      key: const ValueKey('searching'),
                      pulseController: _pulseController,
                      spinController: _spinController,
                      pulseScale: _pulseScale,
                      pulseOpacity: _pulseOpacity,
                      onCancel: _cancel,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchingView extends StatelessWidget {
  final AnimationController pulseController;
  final AnimationController spinController;
  final Animation<double> pulseScale;
  final Animation<double> pulseOpacity;
  final VoidCallback onCancel;

  const _SearchingView({
    super.key,
    required this.pulseController,
    required this.spinController,
    required this.pulseScale,
    required this.pulseOpacity,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PulseRadar(
          pulseController: pulseController,
          spinController: spinController,
          pulseScale: pulseScale,
          pulseOpacity: pulseOpacity,
        ),
        const SizedBox(height: 32),
        const Text(
          'Finding opponent…',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
        const SizedBox(height: 6),
        const Text(
          'Searching for a worthy challenger.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
        const SizedBox(height: 36),
        TextButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close_rounded,
              color: AppColors.danger, size: 18),
          label: const Text(
            'Cancel search',
            style: TextStyle(
                color: AppColors.danger,
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          style: TextButton.styleFrom(
            backgroundColor: AppColors.danger.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          ),
        ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
      ],
    );
  }
}

/// Multi-ring pulse radar: two outer rings expand-and-fade, a dashed
/// ring spins slowly, a coral orb glows in the center. Direct port of
/// the reference's `_buildPulseRadar`.
class _PulseRadar extends StatelessWidget {
  final AnimationController pulseController;
  final AnimationController spinController;
  final Animation<double> pulseScale;
  final Animation<double> pulseOpacity;

  const _PulseRadar({
    required this.pulseController,
    required this.spinController,
    required this.pulseScale,
    required this.pulseOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring (1.2× the base scale for offset).
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, _) => Transform.scale(
              scale: pulseScale.value * 1.2,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary
                        .withValues(alpha: pulseOpacity.value * 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          // Middle pulse ring.
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, _) => Transform.scale(
              scale: pulseScale.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary
                        .withValues(alpha: pulseOpacity.value * 0.7),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          // Spinning thin ring around the orb.
          AnimatedBuilder(
            animation: spinController,
            builder: (_, child) => Transform.rotate(
              angle: spinController.value * 6.283,
              child: child,
            ),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
          ),
          // Center coral orb.
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 28,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 32,
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                curve: Curves.elasticOut,
                duration: 700.ms,
              ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: appCardDecoration(
          borderColor: AppColors.danger.withValues(alpha: 0.3)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.danger.withValues(alpha: 0.15),
              border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: AppColors.danger, size: 40),
          )
              .animate()
              .fadeIn(duration: 300.ms)
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                curve: Curves.elasticOut,
              ),
          const SizedBox(height: 20),
          const Text(
            "Couldn't start the match",
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ).animate().fadeIn(delay: 250.ms, duration: 300.ms),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: AppRadius.button,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.button),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onCancel,
            child: const Text(
              'Back to home',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ).animate().fadeIn(delay: 450.ms, duration: 300.ms),
        ],
      ),
    );
  }
}
