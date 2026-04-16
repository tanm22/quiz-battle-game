import 'dart:async';
import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import '../services/auth_service.dart';
import '../widgets/otp_input.dart';
import '../theme/app_theme.dart';

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
  final _otpKey = GlobalKey<OtpInputState>();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpKey.currentState?.focus();
    });
  }

  @override
  void dispose() {
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

  Future<void> _verifyCode([String? autoCode]) async {
    final code = autoCode ?? _otpKey.currentState?.code ?? '';
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
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on GrpcError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to resend code'),
            backgroundColor: AppColors.danger,
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
          backgroundColor: AppColors.success,
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
      labelStyle: const TextStyle(color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    );
  }

  Widget _buildCodeEntry() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Enter the code sent to',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          widget.email,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),

        // 6-digit code input
        OtpInput(
          key: _otpKey,
          onCompleted: _verifyCode,
        ),

        const SizedBox(height: 16),

        // Error text
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 14),
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
              color: _resendCountdown > 0 ? AppColors.textDim : AppColors.accent,
              fontSize: 14,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _isVerifying ? null : AppGradients.primary,
              color: _isVerifying ? AppColors.border : null,
              borderRadius: AppRadius.button,
            ),
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
              ),
              child: _isVerifying
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
                    )
                  : const Text(
                      'Verify',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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
        const Icon(Icons.check_circle, color: AppColors.success, size: 48),
        const SizedBox(height: 12),
        const Text(
          'Code verified! Set your new password.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          style: const TextStyle(color: AppColors.text),
          decoration: _inputDecoration('New Password', Icons.lock),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          style: const TextStyle(color: AppColors.text),
          decoration: _inputDecoration('Confirm Password', Icons.lock_outline),
          onSubmitted: (_) => _submitPasswordReset(),
        ),
        const SizedBox(height: 8),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _isResetting ? null : AppGradients.primary,
              color: _isResetting ? AppColors.border : null,
              borderRadius: AppRadius.button,
            ),
            child: ElevatedButton(
              onPressed: _isResetting ? null : _submitPasswordReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
              ),
              child: _isResetting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
                    )
                  : const Text(
                      'Reset Password',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        title: Text(title),
        elevation: 0,
      ),
      body: ScaffoldGradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: _showPasswordReset ? _buildPasswordReset() : _buildCodeEntry(),
            ),
          ),
        ),
      ),
    );
  }
}
