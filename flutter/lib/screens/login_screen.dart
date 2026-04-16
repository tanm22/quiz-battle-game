import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import '../providers/game_state.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import 'email_code_screen.dart';

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

  bool _isLoading = false;

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
      setState(() { _usernameAvailable = null; _checkingUsername = false; });
      return;
    }
    setState(() => _checkingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final available = await AuthService().checkUsername(username);
        if (mounted && _regUsernameController.text.trim() == username) {
          setState(() { _usernameAvailable = available; _checkingUsername = false; });
        }
      } catch (_) {
        if (mounted) setState(() { _usernameAvailable = null; _checkingUsername = false; });
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
    );
  }

  void _navigateToMatchmaking(AuthService auth) {
    QuizService().setAuthToken(auth.token!);
    ref.read(gameStateProvider.notifier).setAuth(
      auth.userId!, auth.token!, auth.rating,
      email: auth.email, isGuest: auth.isGuest,
    );
    // Fire-and-forget: register FCM token so push notifications reach this user.
    // Handler is internally idempotent and never throws.
    unawaited(FcmService.instance.registerForUser());
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final auth = AuthService();
      await auth.signInWithGoogle();
      _navigateToMatchmaking(auth);
    } on GrpcError catch (e) {
      _showError(e.message ?? 'Google sign-in failed');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled')) return;
      // ApiException 12500 / 12501 = Google Play Services missing or misconfigured
      if (msg.contains('12500') || msg.contains('12501') || msg.contains('ApiException')) {
        _showError('Google Play Services not available. Use credentials or Quick Play instead.');
      } else {
        _showError(msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guestLogin() async {
    setState(() => _isLoading = true);
    try {
      final auth = AuthService();
      await auth.guestLogin();
      _navigateToMatchmaking(auth);
    } on GrpcError catch (e) {
      _showError(e.message ?? 'Guest login failed');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitLogin() async {
    final identity = _loginIdentityController.text.trim();
    if (identity.isEmpty) { _showError('Enter a username or email'); return; }
    final isEmail = identity.contains('@');

    if (isEmail) {
      setState(() => _isLoading = true);
      try {
        final auth = AuthService();
        await auth.loginWithEmail(identity);
        if (!mounted) return;
        setState(() => _isLoading = false);
        _openEmailCodeScreen(identity, 'login');
      } on GrpcError catch (e) {
        _showError(e.message ?? 'Failed to send login code');
        if (mounted) setState(() => _isLoading = false);
      } catch (e) {
        _showError(e.toString());
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      final password = _loginPasswordController.text;
      if (password.isEmpty) { _showError('Password required'); return; }
      setState(() => _isLoading = true);
      try {
        final auth = AuthService();
        await auth.login(identity, password);
        _navigateToMatchmaking(auth);
      } on GrpcError catch (e) {
        _showError(e.message ?? 'Login failed');
      } catch (e) {
        _showError(e.toString());
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitRegister() async {
    final username = _regUsernameController.text.trim();
    final password = _regPasswordController.text;
    final email = _regEmailController.text.trim();
    final referral = _regReferralController.text.trim();
    if (username.isEmpty || password.isEmpty) { _showError('Username and password required'); return; }
    if (username.length < 3) { _showError('Username must be at least 3 characters'); return; }
    setState(() => _isLoading = true);
    try {
      final auth = AuthService();
      await auth.register(username, password, email: email.isNotEmpty ? email : null, referralCode: referral.isNotEmpty ? referral : null);
      _navigateToMatchmaking(auth);
    } on GrpcError catch (e) {
      _showError(e.message ?? 'Registration failed');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _loginIdentityController.text.trim();
    if (email.isEmpty || !email.contains('@')) { _showError('Enter your email address above first'); return; }
    setState(() => _isLoading = true);
    try {
      await AuthService().sendEmailCode(email, 'reset');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _openEmailCodeScreen(email, 'reset');
    } on GrpcError catch (e) {
      _showError(e.message ?? 'Failed to send reset code');
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      _showError(e.toString());
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openEmailCodeScreen(String email, String purpose) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmailCodeScreen(
          email: email,
          purpose: purpose,
          onVerified: (token, userId) {
            if (token != null && userId != null) {
              final auth = AuthService();
              QuizService().setAuthToken(auth.token!);
              ref.read(gameStateProvider.notifier).setAuth(
                auth.userId!, auth.token!, auth.rating,
                email: auth.email, isGuest: auth.isGuest,
              );
              unawaited(FcmService.instance.registerForUser());
            }
            if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffix}) {
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
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
    );
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
          decoration: _inputDecoration('Username or Email', Icons.person),
          onSubmitted: (_) => _showLoginPassword ? null : _submitLogin(),
        ),
        if (_showLoginPassword && !isEmail) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _loginPasswordController,
            obscureText: true,
            style: const TextStyle(color: AppColors.text),
            decoration: _inputDecoration('Password', Icons.lock),
            onSubmitted: (_) => _submitLogin(),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : _forgotPassword,
            child: const Text('Forgot password?', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          onPressed: _isLoading ? null : _submitLogin,
          label: isEmail ? 'Send Login Code' : 'Login',
        ),
      ],
    );
  }

  Widget _buildRegisterTab() {
    Widget? usernameSuffix;
    if (_checkingUsername) {
      usernameSuffix = const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted)),
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
          decoration: _inputDecoration('Username', Icons.person, suffix: usernameSuffix),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _regPasswordController,
          obscureText: true,
          style: const TextStyle(color: AppColors.text),
          decoration: _inputDecoration('Password', Icons.lock),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _regEmailController,
          style: const TextStyle(color: AppColors.text),
          decoration: _inputDecoration('Email (optional)', Icons.email),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _regReferralController,
          style: const TextStyle(color: AppColors.text),
          decoration: _inputDecoration('Referral code (optional)', Icons.card_giftcard),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          onPressed: _isLoading ? null : _submitRegister,
          label: 'Register',
        ),
      ],
    );
  }

  Widget _buildActionButton({VoidCallback? onPressed, required String label}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScaffoldGradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentBg,
                      boxShadow: [BoxShadow(color: AppColors.accent.withAlpha(40), blurRadius: 30)],
                    ),
                    child: const Icon(Icons.bolt, size: 48, color: AppColors.accent),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'QUIZ BATTLE',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.accent, letterSpacing: 2),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Challenge your mind',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted, letterSpacing: 1),
                  ),
                  const SizedBox(height: 36),

                  // Google Sign-In -- primary auth
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Container(
                      decoration: appCardDecoration(),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _googleSignIn,
                        icon: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Text('G', style: TextStyle(
                              color: Color(0xFF4285F4),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 1,
                            )),
                          ),
                        ),
                        label: const Text('Sign in with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: AppColors.text,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Guest login
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : _guestLogin,
                      icon: const Icon(Icons.flash_on, color: AppColors.textMuted),
                      label: const Text('Quick Play', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or use credentials', style: TextStyle(color: AppColors.textDim)),
                      ),
                      const Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tab bar
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
                        color: AppColors.accentBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.accent.withAlpha(60)),
                      ),
                      labelColor: AppColors.accent,
                      unselectedLabelColor: AppColors.textMuted,
                      dividerColor: Colors.transparent,
                      tabs: const [Tab(text: 'Login'), Tab(text: 'Register')],
                    ),
                  ),
                  const SizedBox(height: 24),

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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
