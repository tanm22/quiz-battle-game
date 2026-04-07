import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import '../providers/game_state.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import 'email_code_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Login tab controllers
  final _loginIdentityController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _showLoginPassword = false;

  // Register tab controllers
  final _regUsernameController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regEmailController = TextEditingController();

  // Username availability check state
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToMatchmaking(AuthService auth) {
    QuizService().setAuthToken(auth.token!);
    ref.read(gameStateProvider.notifier).setAuth(
          auth.userId!,
          auth.token!,
          auth.rating,
          email: auth.email,
          isGuest: auth.isGuest,
        );
  }

  // --- Guest Login ---

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

  // --- Login Tab ---

  Future<void> _submitLogin() async {
    final identity = _loginIdentityController.text.trim();
    if (identity.isEmpty) {
      _showError('Enter a username or email');
      return;
    }

    final isEmail = identity.contains('@');

    if (isEmail) {
      // Email login: send code, then navigate to code screen
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
      // Username login: require password
      final password = _loginPasswordController.text;
      if (password.isEmpty) {
        _showError('Password required');
        return;
      }

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

  // --- Register Tab ---

  Future<void> _submitRegister() async {
    final username = _regUsernameController.text.trim();
    final password = _regPasswordController.text;
    final email = _regEmailController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('Username and password required');
      return;
    }

    if (username.length < 3) {
      _showError('Username must be at least 3 characters');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = AuthService();
      await auth.register(username, password, email: email.isNotEmpty ? email : null);
      _navigateToMatchmaking(auth);
    } on GrpcError catch (e) {
      _showError(e.message ?? 'Registration failed');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Forgot Password ---

  Future<void> _forgotPassword() async {
    final email = _loginIdentityController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Enter your email address above first');
      return;
    }

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

  // --- Email Code Navigation ---

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
                    auth.userId!,
                    auth.token!,
                    auth.rating,
                    email: auth.email,
                    isGuest: auth.isGuest,
                  );
            }
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
      ),
    );
  }

  // --- Build Helpers ---

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white54),
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.amber),
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
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Username or Email', Icons.person),
          onSubmitted: (_) => _showLoginPassword ? null : _submitLogin(),
        ),
        if (_showLoginPassword && !isEmail) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _loginPasswordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Password', Icons.lock),
            onSubmitted: (_) => _submitLogin(),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : _forgotPassword,
            child: const Text(
              'Forgot password?',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.amber.withAlpha(100),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isEmail ? 'Send Login Code' : 'Login',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
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
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    } else if (_usernameAvailable == true) {
      usernameSuffix = const Icon(Icons.check_circle, color: Colors.green);
    } else if (_usernameAvailable == false) {
      usernameSuffix = const Icon(Icons.cancel, color: Colors.redAccent);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _regUsernameController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Username', Icons.person, suffix: usernameSuffix),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _regPasswordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Password', Icons.lock),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _regEmailController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Email (optional)', Icons.email),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.amber.withAlpha(100),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Register',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.quiz, size: 64, color: Colors.amber),
                const SizedBox(height: 16),
                const Text(
                  'Quiz Battle',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // Guest login button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _guestLogin,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      'Play as Guest',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: const BorderSide(color: Colors.amber),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white24)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or', style: TextStyle(color: Colors.white38)),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),

                const SizedBox(height: 16),

                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.amber.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.amber,
                    unselectedLabelColor: Colors.white54,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Login'),
                      Tab(text: 'Register'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Tab content
                ListenableBuilder(
                  listenable: _tabController,
                  builder: (context, _) {
                    return IndexedStack(
                      index: _tabController.index,
                      children: [
                        _buildLoginTab(),
                        _buildRegisterTab(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
