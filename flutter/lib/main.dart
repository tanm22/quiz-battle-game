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
import 'screens/friends_screen.dart';
import 'screens/referral_screen.dart';
import 'screens/results_screen.dart';
import 'providers/friends_state.dart';
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
      theme: _buildDarkTheme(),
      home: const AppShell(),
    );
  }

  /// Dark Material3 theme aligned with the reference UI's
  /// (MANAS-exe/QUIZ_BATTLE_SYSTEM) tokens — coral primary, dark-navy
  /// surfaces, gold secondary. Every screen-level color reads through
  /// the AppColors tokens so this builder only needs to wire the
  /// ColorScheme + global widget theming (cards, buttons, dividers,
  /// inputs) to match.
  ThemeData _buildDarkTheme() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.gold,
      onSecondary: Color(0xFF1A1632),
      tertiary: AppColors.accent,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.cardTint,
      outline: AppColors.border,
      outlineVariant: AppColors.borderBright,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'Roboto',
      // Type ramp matching the reference's TextTheme weights/sizes —
      // bolder displays for hero copy, slightly chunkier titles.
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.text),
        displayMedium:
            TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.text),
        titleLarge:
            TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
        titleMedium:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
        bodyLarge:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.text),
        bodyMedium:
            TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        labelSmall:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.textMuted,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.borderBright),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle:
            TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgNav,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: TextStyle(color: AppColors.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.bgTop,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        titleTextStyle:
            TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
        contentTextStyle:
            TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgTop,
        modalBackgroundColor: AppColors.bgTop,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
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

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  bool _checkedAuth = false;
  Timer? _presenceTicker;

  @override
  void initState() {
    super.initState();
    // Register the FCM tap router before `registerForUser()` runs inside
    // `_tryRestoreSession`, so a notification that opened a terminated app
    // (delivered via getInitialMessage) reaches our handler.
    FcmService.instance.addTapHandler(_handleFcmTap);
    WidgetsBinding.instance.addObserver(this);
    _tryRestoreSession();
  }

  @override
  void dispose() {
    FcmService.instance.removeTapHandler(_handleFcmTap);
    WidgetsBinding.instance.removeObserver(this);
    _stopPresenceTicker();
    super.dispose();
  }

  /// Pause the presence ticker when the app goes to the background and
  /// fire one immediate Heartbeat when it comes back so the user's
  /// online flag flips back fast (don't wait the full 30s tick).
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    super.didChangeAppLifecycleState(s);
    if (s == AppLifecycleState.resumed) {
      _startPresenceTicker(); // idempotent
      // Fire one heartbeat immediately on resume.
      _heartbeatNow();
    } else if (s == AppLifecycleState.paused ||
        s == AppLifecycleState.detached) {
      _stopPresenceTicker();
    }
  }

  /// Starts a 30s presence ticker that pings `Heartbeat` so the
  /// caller's `presence:{userId}` TTL on Redis stays fresh — that's
  /// how friends see them as "online" on their list. No-op if a
  /// ticker is already running, or if the user isn't logged in.
  void _startPresenceTicker() {
    if (_presenceTicker != null) return;
    _heartbeatNow();
    _presenceTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _heartbeatNow(),
    );
  }

  void _stopPresenceTicker() {
    _presenceTicker?.cancel();
    _presenceTicker = null;
  }

  void _heartbeatNow() {
    final state = ref.read(gameStateProvider);
    if (state.userId == null) return;
    // Fire-and-forget — heartbeat failures don't matter, the next
    // tick recovers naturally and the server's TTL keeps presence
    // accurate. catchError swallows the future's error so a network
    // blip / expired JWT / gRPC unavailable doesn't surface as an
    // "Unhandled Exception" in Dart's uncaught-error console.
    unawaited(
      ref.read(friendsServiceProvider).heartbeat().catchError((_) {}),
    );
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
      case 'notif.friend.request_received':
        // Land the user on the Requests tab (Friends screen, second tab)
        // so the inbound request is the first thing they see. Invalidate
        // the providers so the new request shows up before navigation.
        // initialTabIndex: 1 sends them straight to the Requests tab
        // instead of the default Friends list (where the new request
        // wouldn't be visible until they swipe over).
        ref.invalidate(friendRequestsProvider);
        notifier.navigateToHome();
        rootNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => const FriendsScreen(initialTabIndex: 1),
          ),
        );
      case 'notif.friend.request_accepted':
        // The original sender's friends list just gained a member —
        // refetch so the new friend appears without a manual pull.
        ref.invalidate(friendsListProvider);
        notifier.navigateToHome();
        rootNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const FriendsScreen()),
        );
      case 'notif.friend.challenge':
        // The challenger has already created the room server-side with
        // both players. Join it directly using the roomId from the FCM
        // payload — entering the rating-based pool here would pair the
        // recipient with a stranger instead of the challenger.
        final roomId = data['roomId'] as String?;
        if (roomId != null && roomId.isNotEmpty) {
          notifier.joinChallengeRoom(roomId);
        } else {
          // Defensive: missing roomId means the upstream notif payload
          // was malformed. Land on home rather than the wrong opponent.
          notifier.navigateToHome();
        }
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
      final notifier = ref.read(gameStateProvider.notifier);
      notifier.setAuth(
            auth.userId!,
            auth.token!,
            auth.rating,
            email: auth.email,
            isGuest: auth.isGuest,
          );
      // Grandfather pre-existing accounts: a user with matches under
      // their belt was created before the onboarding fields existed and
      // gets `onboardingCompleted=false` from the proto default. Don't
      // drop those users into onboarding — they earned their way past
      // it. Treat them as completed and route to home.
      final isGrandfathered =
          !auth.onboardingCompleted && auth.matchesPlayed > 0;
      if (auth.onboardingCompleted || isGrandfathered) {
        // Onboarded users get FCM registered immediately so push reaches
        // them. The OS dialog (if not previously answered) appears here,
        // which is fine for established accounts.
        unawaited(FcmService.instance.registerForUser());
        // Start the presence heartbeat so the user shows up as
        // "online" on their friends' lists. Fired immediately + every
        // 30s while foregrounded.
        _startPresenceTicker();
      } else {
        // Resume mid-onboarding — defer FCM registration to the prime
        // screen so the OS permission dialog only appears after the
        // user sees the explanatory context. Route to whichever step
        // the user actually got to based on the partial state already
        // saved on the server.
        if (auth.preferredTopics.isNotEmpty) {
          // Topics already saved → only the prime screen is left.
          notifier.navigateToOnboardingPermissionPrime();
        } else if ((auth.avatarUrl ?? '').isNotEmpty ||
            (auth.displayName ?? '').isNotEmpty) {
          // Display name / avatar saved → resume at topic picker.
          notifier.navigateToOnboardingTopicPicker();
        } else {
          // Nothing saved → start at profile setup.
          notifier.navigateToOnboardingProfileSetup();
        }
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

    // Start the presence heartbeat ticker the moment a user authenticates
    // via a fresh login (login_screen calls setAuth which flips userId
    // from null → non-null). Without this hook the ticker only runs on
    // the session-restore path inside _tryRestoreSession, so a freshly
    // logged-in user would appear "offline" to friends until the next
    // app pause/resume cycle. _startPresenceTicker is idempotent (its
    // first line is `if (_presenceTicker != null) return`) so this is
    // safe even if the ticker is already running.
    ref.listen<String?>(
      gameStateProvider.select((gs) => gs.userId),
      (prev, next) {
        if ((prev == null || prev.isEmpty) &&
            next != null &&
            next.isNotEmpty) {
          _startPresenceTicker();
        }
      },
    );

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
