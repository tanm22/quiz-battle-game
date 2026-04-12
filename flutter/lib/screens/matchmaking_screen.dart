import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';

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
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
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

  @override
  Widget build(BuildContext context) {
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing search animation
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 130 + (_pulseController.value * 30),
                        height: 130 + (_pulseController.value * 30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withValues(alpha: 1.0 - _pulseController.value),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00E5FF).withAlpha(20),
                            ),
                            child: const Icon(Icons.search, color: Color(0xFF00E5FF), size: 44),
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
                    onPressed: () {
                      _pulseController.stop();
                      _pulseController.reset();
                      ref.read(gameStateProvider.notifier).leaveMatch();
                    },
                    child: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
