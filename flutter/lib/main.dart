import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/game_state.dart';
import 'screens/login_screen.dart';
import 'screens/matchmaking_screen.dart';
import 'screens/gameplay_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/results_screen.dart';
import 'services/auth_service.dart';
import 'services/quiz_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
/// On first build, attempts to restore a saved session.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _checkedAuth = false;

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    final auth = AuthService();
    final restored = await auth.tryRestoreSession();
    if (restored) {
      QuizService().setAuthToken(auth.token!);
      ref.read(gameStateProvider.notifier).setAuth(
            auth.userId!,
            auth.token!,
            auth.rating,
          );
    }
    setState(() => _checkedAuth = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedAuth) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final gameState = ref.watch(gameStateProvider);

    Widget screen;
    switch (gameState.currentScreen) {
      case GameScreen.login:
        screen = const LoginScreen();
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
