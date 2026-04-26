import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../proto/quiz.pb.dart';
import '../providers/coins_state.dart';
import '../theme/app_theme.dart';

/// AlertDialog that confirms a coin-shop purchase.
///
/// Behaviour notes that callers depend on:
///
///  * The idempotency key is generated **once** in [initState] and reused
///    on retries. The server keys its replay fast-path on this UUID, so a
///    double-tap or a network retry returns the original purchase result
///    without double-debiting the user.
///  * Pop value is `true` on a successful debit, `false`/`null` on cancel.
///    Callers (currently `ShopItemDetail`) show the "Purchased!" snackbar
///    on `true`.
///  * On success, both [coinBalanceProvider] and [shopInventoryProvider]
///    are invalidated so the chip and the shop grid refetch.
///  * Errors are split: gRPC-level failures (auth, deadline, network)
///    surface via the `catch` branch; business errors (`INSUFFICIENT`,
///    `INACTIVE`, `WEEKLY_CAP`, `UNKNOWN`) come back on the response with
///    `success: false` and an [PurchaseShopItemResponse.errorCode]. Both
///    paths populate `_error`.
class PurchaseConfirmModal extends ConsumerStatefulWidget {
  const PurchaseConfirmModal({super.key, required this.item});

  final ShopItem item;

  @override
  ConsumerState<PurchaseConfirmModal> createState() =>
      _PurchaseConfirmModalState();
}

class _PurchaseConfirmModalState extends ConsumerState<PurchaseConfirmModal> {
  late final String _idem;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _idem = const Uuid().v4();
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(coinsServiceProvider)
          .purchase(widget.item.id, _idem);
      if (!mounted) return;
      if (r.success) {
        // Single helper invalidates balance + inventory together so a
        // future call site can't accidentally refresh one and not the
        // other. The chip and shop grid both refetch.
        invalidateCoinState(ref);
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _busy = false;
        _error = _humanize(r.errorCode);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Couldn\'t complete the purchase. Please try again.';
      });
    }
  }

  /// Domain error codes from `PurchaseShopItemResponse.errorCode`. Codes
  /// not in this map render with a generic fallback so a future
  /// server-side code doesn't blank the dialog.
  String _humanize(String code) {
    switch (code) {
      case 'INSUFFICIENT':
        return 'Not enough coins. Earn more by playing matches or completing your daily streak.';
      case 'INACTIVE':
        return 'This item isn\'t available right now.';
      case 'WEEKLY_CAP':
        return 'You\'ve already grabbed a streak freeze this week.';
      case 'UNKNOWN':
        return 'We couldn\'t find that item.';
      default:
        return 'Purchase failed: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Buy ${widget.item.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.description,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.monetization_on, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '${widget.item.priceCoins.toInt()} coins',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Buy'),
        ),
      ],
    );
  }
}
