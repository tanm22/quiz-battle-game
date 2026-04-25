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
import 'screens/onboarding/carousel_screen.dart';
import 'screens/onboarding/permission_prime_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/onboarding/topic_picker_screen.dart';
import 'screens/referral_screen.dart';
import 'screens/results_screen.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/onboarding_service.dart';
import 'services/quiz_service.dart';
import 'theme/app_theme.dart';

/// Global navigator key so the FCM tap handler can push screens
/// (ReferralScreen, etc.) from outside any widget's BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

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
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.bg,
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
    // Register the FCM tap router before `registerForUser()` runs inside
    // `_tryRestoreSession`, so a notification that opened a terminated app
    // (delivered via getInitialMessage) reaches our handler.
    FcmService.instance.addTapHandler(_handleFcmTap);
    _tryRestoreSession();
  }

  @override
  void dispose() {
    FcmService.instance.removeTapHandler(_handleFcmTap);
    super.dispose();
  }

  /// Route the user to the most relevant screen for the tapped notification.
  /// Ignored when the user isn't authenticated — tapping a push while logged
  /// out should just open the login screen, which is already the default.
  void _handleFcmTap(String event, Map<String, dynamic> data) {
    final notifier = ref.read(gameStateProvider.notifier);
    final state = ref.read(gameStateProvider);
    if (state.userId == null) return;

    switch (event) {
      case 'notif.match.invite':
        notifier.navigateToMatchmaking();
      case 'notif.streak.warning':
      case 'notif.daily.reward':
      case 'notif.tournament.remind':
        // Tournament/streak/daily-reward UI all live on the home screen; the
        // user can tap the relevant card from there. Routing directly to
        // TournamentScreen would require the user's plan, which isn't in
        // the FCM payload.
        notifier.navigateToHome();
      case 'notif.referral.converted':
        notifier.navigateToHome();
        // Push ReferralScreen on top so the tap lands the user directly on
        // the reward list. Uses rootNavigatorKey because _handleFcmTap can
        // fire from outside a widget build context.
        rootNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const ReferralScreen()),
        );
      default:
        // Unknown event — best-effort fallback to home so the user isn't
        // stranded on a stale screen.
        notifier.navigateToHome();
    }
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
      // If signed in but onboarding not completed (e.g. installed, signed up,
      // killed app before finishing), resume at the right step.
      if (!auth.onboardingCompleted) {
        ref.read(gameStateProvider.notifier).navigateToOnboardingProfileSetup();
      }
    } else {
      // No session — if the user has never seen the intro, show it first.
      final seen = await OnboardingService.hasSeenCarousel();
      if (!seen) {
        ref.read(gameStateProvider.notifier).navigateToOnboardingCarousel();
      }
    }
    setState(() => _checkedAuth = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
              backgroundColor: AppColors.danger,
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
      case GameScreen.onboardingCarousel:
        screen = const OnboardingCarouselScreen();
      case GameScreen.onboardingProfileSetup:
        screen = const ProfileSetupScreen();
      case GameScreen.onboardingTopicPicker:
        screen = const TopicPickerScreen();
      case GameScreen.onboardingPermissionPrime:
        screen = const PermissionPrimeScreen();
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
          duration: AppDurations.medium,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            // Hero-style "fade through": new screen fades in while scaling from
            // 0.97 → 1.0 and sliding up 12px. Old screen just fades out. Gives
            // the login→home handoff (and other major screen changes) a sense
            // of forward motion without being jarring.
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(animation);
            final scale = Tween<double>(begin: 0.97, end: 1.0).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: slide,
                child: ScaleTransition(scale: scale, child: child),
              ),
            );
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
                    colors: [AppColors.danger, AppColors.primary],
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
