import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';

import '../providers/friends_state.dart';
import '../theme/app_theme.dart';

/// AddFriendModal — modal bottom sheet for sending a friend request.
/// Two paths in one form: by username (default) or by referral code
/// (segmented toggle). Either path returns `true` to the caller via
/// `Navigator.pop` so the friends list can refetch.
///
/// Surfaces typed `error_code` values from the SendFriendRequest RPC
/// as friendly inline copy (USER_NOT_FOUND, ALREADY_FRIENDS,
/// ALREADY_PENDING, SELF, INVALID_ARGUMENT).
class AddFriendModal extends ConsumerStatefulWidget {
  const AddFriendModal({super.key});

  @override
  ConsumerState<AddFriendModal> createState() => _AddFriendModalState();
}

enum _Mode { username, referral }

class _AddFriendModalState extends ConsumerState<AddFriendModal> {
  _Mode _mode = _Mode.username;
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = _mode == _Mode.username
          ? 'Enter a username'
          : 'Enter a referral code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = false;
    });
    try {
      final svc = ref.read(friendsServiceProvider);
      final r = await svc.sendRequest(
        username: _mode == _Mode.username ? raw : null,
        referralCode: _mode == _Mode.referral ? raw.toUpperCase() : null,
      );
      if (!mounted) return;
      if (r.success) {
        setState(() {
          _busy = false;
          _success = true;
          _error = null;
        });
        // Auto-dismiss after a short success beat.
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _busy = false;
          _error = _copyForCode(r.errorCode);
        });
      }
    } on GrpcError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message ?? 'Failed to send request';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  String _copyForCode(String? code) {
    switch (code) {
      case 'USER_NOT_FOUND':
        return _mode == _Mode.username
            ? "We couldn't find that username."
            : "That referral code doesn't match anyone.";
      case 'ALREADY_FRIENDS':
        return "You're already friends.";
      case 'ALREADY_PENDING':
        return "You've already sent a request to this user.";
      case 'SELF':
        return "You can't friend yourself!";
      case 'INVALID_ARGUMENT':
        return 'Please enter a valid username or referral code.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgTop,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Hero badge
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.elasticOut,
                  duration: 500.ms,
                ),
            const SizedBox(height: 14),
            const Text(
              'Add a friend',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Search by username or paste their referral code.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _ModeToggle(
              mode: _mode,
              onChanged: (m) => setState(() {
                _mode = m;
                _ctrl.clear();
                _error = null;
                _success = false;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: _mode == _Mode.referral
                  ? TextCapitalization.characters
                  : TextCapitalization.none,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: _mode == _Mode.username
                    ? 'e.g. alice'
                    : 'e.g. ABC123',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(
                  _mode == _Mode.username
                      ? Icons.person_outline_rounded
                      : Icons.card_giftcard_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: AppRadius.button,
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 16, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 200.ms).shakeX(hz: 3, amount: 4),
            ],
            if (_success) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: AppRadius.button,
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: AppColors.success),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Friend request sent!',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 200.ms),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.button),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Send request',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented toggle between Username and Referral-code modes.
class _ModeToggle extends StatelessWidget {
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _segment(label: 'Username', m: _Mode.username),
          _segment(label: 'Referral code', m: _Mode.referral),
        ],
      ),
    );
  }

  Widget _segment({required String label, required _Mode m}) {
    final selected = mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
