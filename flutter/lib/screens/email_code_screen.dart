import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grpc/grpc.dart';
import '../services/auth_service.dart';

/// Screen for entering 6-digit email verification codes.
/// Used by email login, email linking, and password reset flows.
class EmailCodeScreen extends StatefulWidget {
  final String email;
  final String purpose; // "login", "link", or "reset"
  final void Function(String? token, String? userId) onVerified;

  const EmailCodeScreen({
    super.key,
    required this.email,
    required this.purpose,
    required this.onVerified,
  });

  @override
  State<EmailCodeScreen> createState() => _EmailCodeScreenState();
}

class _EmailCodeScreenState extends State<EmailCodeScreen> {
  final List<TextEditingController> _digitControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  String? _error;

  // Resend countdown
  int _resendCountdown = 60;
  Timer? _resendTimer;

  // Password reset fields (shown after code verified)
  bool _showPasswordReset = false;
  String? _verifiedCode;
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    // Auto-focus first digit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  String get _code {
    return _digitControllers.map((c) => c.text).join();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      // Auto-advance to next field
      _focusNodes[index + 1].requestFocus();
    }
    // If all 6 digits filled, auto-submit
    if (_code.length == 6) {
      _verifyCode();
    }
  }

  void _onDigitKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _digitControllers[index].text.isEmpty &&
        index > 0) {
      // Move focus back on backspace when current field is empty
      _digitControllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyCode() async {
    final code = _code;
    if (code.length != 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final auth = AuthService();
      final resp = await auth.verifyEmailCode(widget.email, code);

      if (!resp.verified) {
        setState(() {
          _error = 'Invalid code. Please try again.';
          _isVerifying = false;
        });
        return;
      }

      if (widget.purpose == 'reset') {
        // Show password reset fields
        setState(() {
          _showPasswordReset = true;
          _verifiedCode = code;
          _isVerifying = false;
        });
      } else {
        // login or link — call onVerified with token
        widget.onVerified(resp.token, resp.userId);
      }
    } on GrpcError catch (e) {
      setState(() {
        _error = e.message ?? 'Verification failed';
        _isVerifying = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isVerifying = false;
      });
    }
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0) return;

    try {
      final purpose = widget.purpose == 'login' ? 'login' : widget.purpose;
      await AuthService().sendEmailCode(widget.email, purpose);
      _startResendCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code resent'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on GrpcError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to resend code'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitPasswordReset() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty) {
      setState(() => _error = 'Enter a new password');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _isResetting = true;
      _error = null;
    });

    try {
      await AuthService().resetPassword(widget.email, _verifiedCode!, newPassword);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully. Please log in.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } on GrpcError catch (e) {
      setState(() {
        _error = e.message ?? 'Password reset failed';
        _isResetting = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isResetting = false;
      });
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white54),
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

  Widget _buildCodeEntry() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter the code sent to',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          widget.email,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),

        // 6-digit code input
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return Container(
              width: 44,
              height: 52,
              margin: EdgeInsets.only(left: index > 0 ? 8 : 0),
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) => _onDigitKeyDown(index, event),
                child: TextField(
                  controller: _digitControllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.amber, width: 2),
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => _onDigitChanged(index, value),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        // Error text
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),

        // Resend code button
        TextButton(
          onPressed: _resendCountdown > 0 ? null : _resendCode,
          child: Text(
            _resendCountdown > 0
                ? 'Resend code in ${_resendCountdown}s'
                : 'Resend code',
            style: TextStyle(
              color: _resendCountdown > 0 ? Colors.white38 : Colors.amber,
              fontSize: 14,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isVerifying ? null : _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.amber.withAlpha(100),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isVerifying
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Verify',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordReset() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 48),
        const SizedBox(height: 12),
        const Text(
          'Code verified! Set your new password.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('New Password', Icons.lock),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Confirm Password', Icons.lock_outline),
          onSubmitted: (_) => _submitPasswordReset(),
        ),
        const SizedBox(height: 8),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isResetting ? null : _submitPasswordReset,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.amber.withAlpha(100),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isResetting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Reset Password',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title;
    switch (widget.purpose) {
      case 'login':
        title = 'Email Login';
      case 'link':
        title = 'Link Email';
      case 'reset':
        title = 'Reset Password';
      default:
        title = 'Verify Email';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: Text(title),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: _showPasswordReset ? _buildPasswordReset() : _buildCodeEntry(),
          ),
        ),
      ),
    );
  }
}
