import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import '../services/auth_service.dart';
import '../providers/game_state.dart';
import '../widgets/otp_input.dart';
import '../theme/app_theme.dart';

/// Bottom-sheet widget allowing guest users to link an email address.
///
/// Flow: enter email -> send verification code -> enter 6-digit code -> verify & link.
class LinkEmailScreen extends ConsumerStatefulWidget {
  const LinkEmailScreen({super.key});

  @override
  ConsumerState<LinkEmailScreen> createState() => _LinkEmailScreenState();
}

class _LinkEmailScreenState extends ConsumerState<LinkEmailScreen> {
  final _emailController = TextEditingController();
  final _otpKey = GlobalKey<OtpInputState>();

  bool _codeSent = false;
  bool _isSendingCode = false;
  bool _isVerifying = false;
  bool _isSuccess = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isSendingCode = true;
      _error = null;
    });

    try {
      await AuthService().sendEmailCode(email, 'link');
      setState(() {
        _codeSent = true;
        _isSendingCode = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _otpKey.currentState?.focus();
      });
    } on GrpcError catch (e) {
      setState(() {
        _error = e.message ?? 'Failed to send code';
        _isSendingCode = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSendingCode = false;
      });
    }
  }

  Future<void> _verifyAndLink([String? autoCode]) async {
    final email = _emailController.text.trim();
    final code = autoCode ?? _otpKey.currentState?.code ?? '';

    if (code.length != 6) {
      setState(() => _error = 'Please enter the full 6-digit code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      await AuthService().linkEmail(email, code);

      // Update Riverpod state so the rest of the app reflects the change.
      ref.read(gameStateProvider.notifier).linkEmailSuccess(email);

      setState(() {
        _isVerifying = false;
        _isSuccess = true;
      });

      // Auto-dismiss after a short delay.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentBg,
              ),
              child: const Icon(Icons.email_outlined, color: AppColors.accent, size: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'Link your email to save your progress',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            if (_isSuccess) ...[
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emeraldBg,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 32),
              ),
              const SizedBox(height: 12),
              const Text(
                'Email linked successfully!',
                style: TextStyle(color: AppColors.success, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ] else ...[
              // Email field
              TextField(
                controller: _emailController,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.email, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardTint,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border.withAlpha(100)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (!_codeSent) ...[
                // Send Code button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _isSendingCode ? null : AppGradients.primary,
                      color: _isSendingCode ? AppColors.border : null,
                      borderRadius: AppRadius.button,
                    ),
                    child: ElevatedButton(
                      onPressed: _isSendingCode ? null : _sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
                      ),
                      child: _isSendingCode
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textMuted,
                              ),
                            )
                          : const Text(
                              'Send Code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ] else ...[
                // Code sent info
                const Text(
                  'Enter the 6-digit code sent to your email',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),

                // 6-digit code input
                OtpInput(
                  key: _otpKey,
                  onCompleted: _verifyAndLink,
                ),
                const SizedBox(height: 20),

                // Verify & Link button
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
                      onPressed: _isVerifying ? null : _verifyAndLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textMuted,
                              ),
                            )
                          : const Text(
                              'Verify & Link',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Resend option
                TextButton(
                  onPressed: _isSendingCode ? null : _sendCode,
                  child: const Text(
                    'Resend code',
                    style: TextStyle(color: AppColors.accent, fontSize: 14),
                  ),
                ),
              ],

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger, fontSize: 14),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
