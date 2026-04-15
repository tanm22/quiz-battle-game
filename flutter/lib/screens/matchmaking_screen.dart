import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';
import '../theme/app_theme.dart';

class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    // Auto-start matchmaking when this screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSearch());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startSearch() {
    final gameState = ref.read(gameStateProvider);
    final userId = gameState.userId;
    if (userId == null) return;
    _pulseController.repeat();
    ref.read(gameStateProvider.notifier).joinMatchmaking(userId, gameState.rating);
  }

  void _retry() {
    ref.read(gameStateProvider.notifier).clearError();
    _startSearch();
  }

  void _cancel() {
    _pulseController.stop();
    _pulseController.reset();
    ref.read(gameStateProvider.notifier).leaveMatch();
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = ref.watch(gameStateProvider.select((s) => s.errorMessage));

    // When we enter an error state, stop the pulse so it doesn't keep burning
    // frames underneath the retry card.
    if (errorMessage != null && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    return Scaffold(
      body: ScaffoldGradientBackground(
        child: SafeArea(
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
                        onCancel: _cancel,
                      ),
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
  final VoidCallback onCancel;
  const _SearchingView({super.key, required this.pulseController, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pulsing search animation
        AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            return Container(
              width: 130 + (pulseController.value * 30),
              height: 130 + (pulseController.value * 30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 1.0 - pulseController.value),
                  width: 3,
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary.withAlpha(20),
                  ),
                  child: const Icon(Icons.search, color: AppColors.secondary, size: 44),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text('Finding opponent...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Searching for a worthy challenger', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 14)),
        const SizedBox(height: 28),
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
        ),
      ],
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
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: AppRadius.hero,
        border: Border.all(color: AppColors.danger.withAlpha(80)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.danger.withAlpha(30),
            ),
            child: const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            "Couldn't start the match",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onCancel,
            child: Text(
              'Back to home',
              style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
