import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import '../../providers/game_state.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../theme/app_theme.dart';

/// Educational screen shown right before the OS notification permission
/// dialog. The user sees the bullet list explaining why notifications
/// matter, *then* taps "Got it" which triggers the system prompt with
/// context already in their head. Whether they grant or deny, we mark
/// onboarding complete and route to home — denial is recoverable later
/// from Settings.
class PermissionPrimeScreen extends ConsumerStatefulWidget {
  const PermissionPrimeScreen({super.key});

  @override
  ConsumerState<PermissionPrimeScreen> createState() => _PermissionPrimeScreenState();
}

class _PermissionPrimeScreenState extends ConsumerState<PermissionPrimeScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _finish() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Trigger FCM registration NOW (which asks the OS for permission
      // internally) so the system dialog fires only after the user has
      // seen the bullet-list context. Earlier signup flows deferred this
      // call exactly so it would land here. Failures are non-fatal:
      // denial just means push won't reach this device — but a thrown
      // exception from the Firebase plugin (no Play Services, network
      // hiccup during getToken, etc.) MUST NOT prevent us from marking
      // onboarding complete, or the user is wedged on this screen with
      // no recovery beyond tapping the button again.
      try {
        await FcmService.instance.registerForUser();
      } catch (e, st) {
        debugPrint('FCM registration failed during onboarding finish: $e\n$st');
      }
      await AuthService().updateProfile(markOnboardingCompleted: true);
      if (!mounted) return;
      ref.read(gameStateProvider.notifier).navigateToHome();
    } on GrpcError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Failed to finish onboarding';
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ScaffoldGradientBackground(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentBg,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      size: 56,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Stay in the game',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Notifications keep you in the loop on:',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
                const SizedBox(height: 24),
                _Bullet(
                  icon: Icons.bolt_rounded,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.orangeBg,
                  text: 'Match invites from friends',
                ),
                const SizedBox(height: 12),
                _Bullet(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: AppColors.danger,
                  iconBg: AppColors.roseBg,
                  text: "Streak reminders so you don't lose your run",
                ),
                const SizedBox(height: 12),
                _Bullet(
                  icon: Icons.emoji_events_rounded,
                  iconColor: AppColors.gold,
                  iconBg: AppColors.goldBg,
                  text: 'Tournament starts and prize results',
                ),
                const Spacer(),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: AppRadius.button,
                    ),
                    child: ElevatedButton(
                      onPressed: _saving ? null : _finish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Got it, let's play",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    "You can change this later in Settings",
                    style: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String text;

  const _Bullet({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
