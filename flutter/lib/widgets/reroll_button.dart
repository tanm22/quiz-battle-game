import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/coins_state.dart';
import '../theme/app_theme.dart';

/// Floating button that lets the player spend a reroll charge to skip
/// the current question's topic. Hidden when the user has 0 charges so
/// the gameplay surface stays uncluttered for users who haven't bought
/// any.
///
/// Tapping opens a confirmation dialog; on confirm, calls
/// [CoinsService.consumeReroll] with the [roomId] / [roundId]
/// (server persists these once the per-match audit-trail PR lands —
/// passing them now means we don't lose the context when it does).
///
/// Charges and balance refetch via [invalidateCoinState] on success.
class RerollButton extends ConsumerStatefulWidget {
  const RerollButton({super.key, required this.roomId, required this.roundId});

  final String roomId;
  final String roundId;

  @override
  ConsumerState<RerollButton> createState() => _RerollButtonState();
}

class _RerollButtonState extends ConsumerState<RerollButton> {
  bool _busy = false;

  /// Domain error codes from `ConsumeRerollResponse.errorCode`. Codes not
  /// in this map render with a generic fallback so a future server-side
  /// code doesn't leak raw enum names to the user.
  String _humanize(String code) {
    switch (code) {
      case 'NO_CHARGES':
        return 'You don\'t have any reroll charges left. Buy more in the Coin Shop.';
      default:
        return 'Couldn\'t reroll: $code';
    }
  }

  Future<void> _confirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Use a reroll?'),
        content: const Text(
            'Spend one reroll charge — your topic preference is recorded so '
            'future questions skew away from this round. '
            'You can buy more in the Coin Shop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Use'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      // Server records the reroll for the per-match audit trail; the
      // question-refetch / topic-rebias flow lands in a follow-up PR. Until
      // then, we surface the consume but don't promise an immediate swap.
      final r = await ref.read(coinsServiceProvider).consumeReroll(
            roomId: widget.roomId,
            roundId: widget.roundId,
          );
      if (!mounted) return;
      if (r.success) {
        invalidateCoinState(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reroll recorded.')),
        );
      } else {
        // Stale inventory cache is the most likely root cause of NO_CHARGES
        // when the badge said N — refresh it so the next tap reflects truth.
        invalidateCoinState(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_humanize(r.errorCode))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error — try again')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = ref.watch(shopInventoryProvider);
    final charges = inv.value?.rerollCharges ?? 0;
    if (charges <= 0) return const SizedBox.shrink();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: const Key('reroll-button'),
        onTap: _busy ? null : _confirm,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withAlpha(80)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text('Reroll',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$charges',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
              if (_busy) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
