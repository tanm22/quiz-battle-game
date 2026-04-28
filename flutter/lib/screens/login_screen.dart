import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import '../providers/game_state.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import 'email_code_screen.dart';

/// LoginScreen — UX styled after the MANAS-exe/QUIZ_BATTLE_SYSTEM
/// reference: a coral hero badge, "Quiz Battle" headline + tagline,
/// Google-sign-in as the prominent primary CTA, and the credential
/// flow collapsed behind a `Use email / password` toggle. The tabbed
/// Login/Register form, the unique-username live check, the
/// email-or-username login dispatcher, the email-code flow, the
/// referral code, the forgot-password jump, and Quick Play (guest)
/// are all preserved — only the visual layout and motion changed.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _loginIdentityController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _showLoginPassword = false;

  final _regUsernameController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regReferralController = TextEditingController();

  bool? _usernameAvailable;
  bool _checkingUsername = false;
  Timer? _usernameDebounce;

  /// Tracks WHICH auth path is currently in flight, so:
  ///   1. Only the button the user actually tapped renders a spinner
  ///      (Google was previously sharing `_isLoading` with email
  ///      Login/Register, which made tapping Login spin the Google
  ///      button too — visually confusing and wrong).
  ///   2. Every other button is still disabled while one path is in
  ///      flight, preventing double-submit across actions (you can't
  ///      meaningfully fire Google + Register concurrently).
  _LoadingAction? _activeAction;
  bool _showCredentialForm = false;
  String? _error;

  /// True when any auth action is in flight. All buttons disable when
  /// this is true; only the matching button renders a spinner.
  bool get _busy => _activeAction != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loginIdentityController.addListener(_onLoginIdentityChanged);
    _regUsernameController.addListener(_onRegUsernameChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdentityController.dispose();
    _loginPasswordController.dispose();
    _regUsernameController.dispose();
    _regPasswordController.dispose();
    _regEmailController.dispose();
    _regReferralController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  void _onLoginIdentityChanged() {
    final text = _loginIdentityController.text.trim();
    final isEmail = text.contains('@');
    final shouldShowPassword = !isEmail && text.isNotEmpty;
    if (shouldShowPassword != _showLoginPassword) {
      setState(() => _showLoginPassword = shouldShowPassword);
    }
  }

  void _onRegUsernameChanged() {
    final username = _regUsernameController.text.trim();
    _usernameDebounce?.cancel();
    if (username.length < 3) {
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
      return;
    }
    setState(() => _checkingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final available = await AuthService().checkUsername(username);
        if (mounted && _regUsernameController.text.trim() == username) {
          setState(() {
            _usernameAvailable = available;
            _checkingUsername = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _usernameAvailable = null;
            _checkingUsername = false;
          });
        }
      }
    });
  }

  /// Surface an inline error in the form (animated shake) instead of a
  /// snackbar — matches the reference's affordance and keeps the user's
  /// eye on the actual offending input.
  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  void _navigateToMatchmaking(AuthService auth) {
    QuizService().setAuthToken(auth.token!);
    final notifier = ref.read(gameStateProvider.notifier);
    notifier.setAuth(
      auth.userId!,
      auth.token!,
      auth.rating,
      email: auth.email,
      isGuest: auth.isGuest,
    );
    // Fire-and-forget: register FCM token so push notifications reach
    // this user. The handler is internally idempotent and never throws.
    unawaited(FcmService.instance.registerForUser());
  }

  /// Used after register / Google sign-in. If onboarding is incomplete,
  /// routes to profile setup AND deliberately skips FCM registration —
  /// the OS notification permission dialog must wait until the prime
  /// screen fires it, otherwise the prime screen has nothing left to
  /// ask for. Already-onboarded users (e.g. a returning Google account)
  /// take the same path as Login.
  void _navigateAfterSignup(AuthService auth) {
    if (!auth.onboardingCompleted) {
      QuizService().setAuthToken(auth.token!);
      final notifier = ref.read(gameStateProvider.notifier);
      notifier.setAuth(
        auth.userId!,
        auth.token!,
        auth.rating,
        email: auth.email,
        isGuest: auth.isGuest,
      );
      // Intentionally NOT calling FcmService.registerForUser() —
      // permission ask is deferred to the prime screen so the OS
      // dialog fires after the user has seen the explanatory context.
      notifier.navigateToOnboardingProfileSetup();
    } else {
      _navigateToMatchmaking(auth);
    }
  }

  /// Sets [_activeAction] and clears [_error] in one frame. Used by
  /// every auth handler at start.
  void _enter(_LoadingAction a) {
    if (!mounted) return;
    setState(() {
      _activeAction = a;
      _error = null;
    });
  }

  /// Resets [_activeAction] back to null. Used in every auth handler's
  /// `finally` block (and in the early-return success paths that need
  /// to clear before navigating).
  void _exit() {
    if (!mounted) return;
    setState(() => _activeAction = null);
  }

  Future<void> _googleSignIn() async {
    _enter(_LoadingAction.google);
    try {
      final auth = AuthService();
      await auth.signInWithGoogle();
      _navigateAfterSignup(auth);
    } on GrpcError catch (e) {
      _setError(e.message ?? 'Google sign-in failed');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled')) return;
      // ApiException 12500 / 12501 = Google Play Services missing or misconfigured
      if (msg.contains('12500') ||
          msg.contains('12501') ||
          msg.contains('ApiException')) {
        _setError('Google Play Services not available. Use credentials or Quick Play instead.');
      } else {
        _setError(msg);
      }
    } finally {
      _exit();
    }
  }

  Future<void> _guestLogin() async {
    _enter(_LoadingAction.guest);
    try {
      final auth = AuthService();
      await auth.guestLogin();
      _navigateToMatchmaking(auth);
    } on GrpcError catch (e) {
      _setError(e.message ?? 'Guest login failed');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _exit();
    }
  }

  Future<void> _submitLogin() async {
    final identity = _loginIdentityController.text.trim();
    if (identity.isEmpty) {
      _setError('Enter a username or email');
      return;
    }
    final isEmail = identity.contains('@');

    if (isEmail) {
      _enter(_LoadingAction.login);
      try {
        final auth = AuthService();
        await auth.loginWithEmail(identity);
        if (!mounted) return;
        _exit();
        _openEmailCodeScreen(identity, 'login');
      } on GrpcError catch (e) {
        _setError(e.message ?? 'Failed to send login code');
        _exit();
      } catch (e) {
        _setError(e.toString());
        _exit();
      }
    } else {
      final password = _loginPasswordController.text;
      if (password.isEmpty) {
        _setError('Password required');
        return;
      }
      _enter(_LoadingAction.login);
      try {
        final auth = AuthService();
        await auth.login(identity, password);
        _navigateToMatchmaking(auth);
      } on GrpcError catch (e) {
        _setError(e.message ?? 'Login failed');
      } catch (e) {
        _setError(e.toString());
      } finally {
        _exit();
      }
    }
  }

  Future<void> _submitRegister() async {
    final username = _regUsernameController.text.trim();
    final password = _regPasswordController.text;
    final email = _regEmailController.text.trim();
    final referral = _regReferralController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      _setError('Username and password required');
      return;
    }
    if (username.length < 3) {
      _setError('Username must be at least 3 characters');
      return;
    }
    _enter(_LoadingAction.register);
    try {
      final auth = AuthService();
      await auth.register(
        username,
        password,
        email: email.isNotEmpty ? email : null,
        referralCode: referral.isNotEmpty ? referral : null,
      );
      _navigateAfterSignup(auth);
    } on GrpcError catch (e) {
      _setError(e.message ?? 'Registration failed');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _exit();
    }
  }

  Future<void> _forgotPassword() async {
    final email = _loginIdentityController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _setError('Enter your email address above first');
      return;
    }
    _enter(_LoadingAction.forgot);
    try {
      await AuthService().sendEmailCode(email, 'reset');
      if (!mounted) return;
      _exit();
      _openEmailCodeScreen(email, 'reset');
    } on GrpcError catch (e) {
      _setError(e.message ?? 'Failed to send reset code');
      _exit();
    } catch (e) {
      _setError(e.toString());
      _exit();
    }
  }

  void _openEmailCodeScreen(String email, String purpose) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmailCodeScreen(
          email: email,
          purpose: purpose,
          onVerified: (token, userId) async {
            if (token != null && userId != null) {
              final auth = AuthService();
              QuizService().setAuthToken(auth.token!);
              await auth.refreshProfile();
            }
            if (!mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
            if (token != null && userId != null) {
              _navigateAfterSignup(AuthService());
            }
          },
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Sub-widgets
  // ──────────────────────────────────────────────────────────────────

  /// Coral logo badge — circle with a faint coral fill and a 2px coral
  /// border, bolt icon centered. Animates on mount: fade + elastic
  /// scale matching the reference.
  Widget _buildLogo() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2),
      ),
      child: const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 44),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1, 1),
          duration: 500.ms,
          curve: Curves.elasticOut,
        );
  }

  Widget _buildHeadline() {
    return Column(
      children: [
        const Text(
          'Quiz Battle',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
        const SizedBox(height: 6),
        Text(
          'Challenge friends. Climb the ranks.',
          style: TextStyle(
            color: AppColors.text.withValues(alpha: 0.45),
            fontSize: 14,
          ),
        ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
      ],
    );
  }

  /// Primary action — large white Google button with the official "G"
  /// glyph. Above the fold, full width, fade-in delay 450ms.
  Widget _buildGoogleButton() {
    final googleInFlight = _activeAction == _LoadingAction.google;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _busy ? null : _googleSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: 15),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
        ),
        child: googleInFlight
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Color(0xFF1F1F1F),
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleLogo(),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                ],
              ),
      ),
    ).animate().fadeIn(delay: 450.ms, duration: 400.ms);
  }

  /// Secondary action — Quick Play (guest). Lighter weight than
  /// Google so it reads as the alt path, not a competing CTA.
  Widget _buildQuickPlayButton() {
    final guestInFlight = _activeAction == _LoadingAction.guest;
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _busy ? null : _guestLogin,
        icon: guestInFlight
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textMuted,
                ),
              )
            : const Icon(Icons.flash_on_rounded, color: AppColors.textMuted),
        label: const Text(
          'Quick Play (no account)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: AppColors.text.withValues(alpha: 0.12)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(
              color: AppColors.text.withValues(alpha: 0.35),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: AppColors.text.withValues(alpha: 0.12)),
        ),
      ],
    ).animate().fadeIn(delay: 550.ms, duration: 400.ms);
  }

  /// Tap-to-expand toggle that reveals the credential form below.
  Widget _buildCredentialToggle() {
    return GestureDetector(
      onTap: () => setState(() {
        _showCredentialForm = !_showCredentialForm;
        _error = null;
      }),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Use email / password',
            style: TextStyle(
              color: AppColors.text.withValues(alpha: 0.5),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            _showCredentialForm
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 400.ms);
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: AppRadius.button,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? '',
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).shakeX(hz: 3, amount: 4);
  }

  Widget _buildTermsNote() {
    return Text(
      'By continuing, you agree to our Terms and Privacy Policy.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.text.withValues(alpha: 0.3),
        fontSize: 11,
        height: 1.4,
      ),
    ).animate().fadeIn(delay: 700.ms, duration: 400.ms);
  }

  // ── Credential form (collapsed by default) ─────────────────────────

  InputDecoration _inputDecoration(String label, IconData icon,
      {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _buildCredentialForm() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Login'),
              Tab(text: 'Register'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListenableBuilder(
          listenable: _tabController,
          builder: (context, _) {
            return IndexedStack(
              index: _tabController.index,
              children: [_buildLoginTab(), _buildRegisterTab()],
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildLoginTab() {
    final identity = _loginIdentityController.text.trim();
    final isEmail = identity.contains('@');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _loginIdentityController,
          style: const TextStyle(color: AppColors.text),
          decoration: _inputDecoration('Username or Email', Icons.person_outline_rounded),
          onSubmitted: (_) => _showLoginPassword ? null : _submitLogin(),
        ),
        if (_showLoginPassword && !isEmail) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _loginPasswordController,
            obscureText: true,
            style: const TextStyle(color: AppColors.text),
            decoration: _inputDecoration('Password', Icons.lock_outline_rounded),
            onSubmitted: (_) => _submitLogin(),
          ),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : _forgotPassword,
            child: Text(
              _activeAction == _LoadingAction.forgot
                  ? 'Sending…'
                  : 'Forgot password?',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildPrimaryActionButton(
          onPressed: _busy ? null : _submitLogin,
          label: isEmail ? 'Send Login Code' : 'Login',
          showSpinner: _activeAction == _LoadingAction.login,
        ),
      ],
    );
  }

  Widget _buildRegisterTab() {
    Widget? usernameSuffix;
    if (_checkingUsername) {
      usernameSuffix = const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textMuted,
          ),
        ),
      );
    } else if (_usernameAvailable == true) {
      usernameSuffix = const Icon(Icons.check_circle, color: AppColors.success);
    } else if (_usernameAvailable == false) {
      usernameSuffix = const Icon(Icons.cancel, color: AppColors.danger);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _regUsernameController,
          style: const TextStyle(color: AppColors.text),
          decoration: _inputDecoration('Username', Icons.person_outline_rounded,
              suffix: usernameSuffix),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _regPasswordController,
          obscureText: true,
          style: const TextStyle(color: AppColors.text),
          decoration: _inputDecoration('Password', Icons.lock_outline_rounded),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _regEmailController,
          style: const TextStyle(color: AppColors.text),
          decoration: _inputDecoration('Email (optional)', Icons.email_outlined),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _regReferralController,
          style: const TextStyle(color: AppColors.text),
          decoration: _inputDecoration(
              'Referral code (optional)', Icons.card_giftcard_rounded),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 16),
        _buildPrimaryActionButton(
          onPressed: _busy ? null : _submitRegister,
          label: 'Create account',
          showSpinner: _activeAction == _LoadingAction.register,
        ),
      ],
    );
  }

  Widget _buildPrimaryActionButton({
    VoidCallback? onPressed,
    required String label,
    required bool showSpinner,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: showSpinner
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLogo(),
                const SizedBox(height: 20),
                _buildHeadline(),
                const SizedBox(height: 40),
                _buildGoogleButton(),
                const SizedBox(height: 12),
                _buildQuickPlayButton(),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 20),
                _buildCredentialToggle(),
                if (_showCredentialForm) ...[
                  const SizedBox(height: 16),
                  _buildCredentialForm(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorBanner(),
                ],
                const SizedBox(height: 40),
                _buildTermsNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline "G" Google glyph — a 24×24 white tile with a colored G.
/// Avoids depending on a network asset and matches the reference's
/// approach of drawing the logo locally.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontWeight: FontWeight.w700,
            fontSize: 16,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Auth path enum used by [_LoginScreenState._activeAction] to gate
/// per-button spinners while preserving global "any action in flight
/// → all buttons disabled" semantics.
enum _LoadingAction { google, guest, login, register, forgot }
