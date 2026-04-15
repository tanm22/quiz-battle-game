import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/game_state.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/matchmaking_screen.dart';
import 'screens/gameplay_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/results_screen.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/quiz_service.dart';

/// FCM background isolate entry point. Android runs this in a fresh isolate
/// when a push arrives while the app is terminated or backgrounded, so it
/// must be a top-level function annotated with `vm:entry-point`. We leave
/// the body empty because the backend always sends a `notification` payload
/// alongside the data — Android auto-renders that via the default channel
/// declared in AndroidManifest.xml. This handler just needs to exist so
/// FirebaseMessaging can wake the isolate for data-only messages.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase early so FCM is ready before any auth flow starts.
  // Failures are logged inside — the app still boots if init throws (e.g. in
  // environments without google-services.json).
  await FcmService.instance.initializeFirebase();
  // Register the background handler only after Firebase has initialized;
  // calling this when Firebase.apps is empty throws. If init failed the app
  // still boots, just without background push wake-up.
  if (Firebase.apps.isNotEmpty) {
    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
  }
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
          seedColor: const Color(0xFFFF6B35),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0E2E),
        fontFamily: 'Roboto',
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
            email: auth.email,
            isGuest: auth.isGuest,
          );
      // Auth restored — register this device's FCM token so push notifications
      // can reach the user. Non-blocking: notification failures must not gate
      // the UI swap from splash to home.
      unawaited(FcmService.instance.registerForUser());
    }
    setState(() => _checkedAuth = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))),
      );
    }

    final gameState = ref.watch(gameStateProvider);

    // Show error messages as SnackBar
    ref.listen(
      gameStateProvider.select((s) => s.errorMessage),
      (prev, next) {
        if (next != null && next != prev) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next),
              backgroundColor: const Color(0xFFFF4444),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          ref.read(gameStateProvider.notifier).clearError();
        }
      },
    );

    Widget screen;
    switch (gameState.currentScreen) {
      case GameScreen.login:
        screen = const LoginScreen();
      case GameScreen.home:
        screen = const HomeScreen();
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey(gameState.currentScreen),
            child: screen,
          ),
        ),
        if (gameState.isReconnecting)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF4444), Color(0xFFFF6B35)],
                  ),
                ),
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
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
