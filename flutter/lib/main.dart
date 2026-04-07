import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/game_state.dart';
import 'screens/matchmaking_screen.dart';
import 'screens/gameplay_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/results_screen.dart';

void main() {
  runApp(const ProviderScope(child: QuizBattleApp()));
}

class QuizBattleApp extends StatelessWidget {
  const QuizBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Battle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
      ),
      home: const AppShell(),
    );
  }
}

/// Routes between screens and shows reconnection banner (step 68).
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);

    Widget screen;
    switch (gameState.currentScreen) {
      case GameScreen.matchmaking:
        screen = const MatchmakingScreen();
      case GameScreen.gameplay:
        screen = const GameplayScreen();
      case GameScreen.leaderboard:
        screen = const LeaderboardScreen();
      case GameScreen.results:
        screen = const ResultsScreen();
    }

    // Step 68: Reconnection banner overlay
    return Stack(
      children: [
        screen,
        if (gameState.isReconnecting)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.orange.shade900,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reconnecting...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
