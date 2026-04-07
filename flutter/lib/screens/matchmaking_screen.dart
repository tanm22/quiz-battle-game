import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';

/// Step 61: Matchmaking screen — username input, Start Battle button,
/// pulsing ring animation while waiting, navigates on match_found.
class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  late final AnimationController _pulseController;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startBattle() {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() => _isSearching = true);
    _pulseController.repeat();

    ref.read(gameStateProvider.notifier).joinMatchmaking(username, 1200);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Quiz Battle',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),

              if (_isSearching) ...[
                // Pulsing ring animation
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 120 + (_pulseController.value * 30),
                      height: 120 + (_pulseController.value * 30),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.amber.withValues(
                            alpha: 1.0 - _pulseController.value,
                          ),
                          width: 3,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.search,
                          color: Colors.amber,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Finding opponent...',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 16),
                // Player count / ETA label
                const Text(
                  'Waiting for players',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    setState(() => _isSearching = false);
                    _pulseController.stop();
                    _pulseController.reset();
                    ref.read(gameStateProvider.notifier).playAgain();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ] else ...[
                // Username input
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter your username',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon:
                        const Icon(Icons.person, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 24),

                // Start Battle button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _startBattle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Start Battle',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
