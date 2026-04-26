import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/quiz_service.dart';
import '../proto/quiz.pbgrpc.dart';
import '../theme/app_theme.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedPlan = 'monthly';
  bool _loading = false;
  bool _verifying = false;
  String? _currentPlan;
  Int64? _expiresAt;
  List<PaymentRecord>? _paymentHistory;
  bool _historyLoading = false;
  late final Razorpay _razorpay;

  /// Last successful CreateOrder response, retained so the "Try again"
  /// path on a payment failure can reopen the SAME Razorpay order
  /// rather than creating a new one (no new debit attempt on the
  /// server, no duplicate payment row).
  CreateOrderResponse? _lastOrder;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadPlanStatus();
    _loadPaymentHistory();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadPlanStatus() async {
    try {
      final resp = await QuizService().payment.getPlanStatus(
        GetPlanStatusRequest(),
        options: QuizService().authCallOptions,
      );
      if (mounted) {
        setState(() {
          _currentPlan = resp.plan;
          _expiresAt = resp.expiresAt;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPaymentHistory() async {
    if (!mounted) return;
    setState(() => _historyLoading = true);
    try {
      final resp = await QuizService().payment.getPaymentHistory(
        GetPaymentHistoryRequest()..limit = 20,
        options: QuizService().authCallOptions,
      );
      if (mounted) {
        setState(() {
          _paymentHistory = resp.payments;
          _historyLoading = false;
        });
      }
    } catch (_) {
      // Non-fatal — upgrade flow still works without history.
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _createOrder() async {
    setState(() => _loading = true);
    try {
      final resp = await QuizService().payment.createOrder(
        CreateOrderRequest()..planDuration = _selectedPlan,
        options: QuizService().authCallOptions,
      );
      _lastOrder = resp;

      if (!mounted) return;
      _openCheckout(resp);
    } on GrpcError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Payment failed'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opens the Razorpay checkout sheet for [order]. Split out of
  /// `_createOrder` so the retry flow can reopen the same order without
  /// creating a new one — Razorpay accepts the same `order_id` for a
  /// fresh attempt as long as the order hasn't been captured yet.
  void _openCheckout(CreateOrderResponse order) {
    _razorpay.open({
      'key': order.keyId,
      'amount': order.amount.toInt(),
      'order_id': order.orderId,
      'currency': order.currency,
      'name': 'Quiz Battle',
      'description':
          _selectedPlan == 'yearly' ? 'Premium Yearly' : 'Premium Monthly',
      'theme': {'color': '#6D59C4'},
      // UPI-first ordering: GPay / PhonePe / Paytm sit at the top of
      // the method picker, then card / netbanking / wallet. Reflects
      // the actual usage mix in the target market.
      'config': {
        'display': {
          'blocks': {
            'banks': {
              'name': 'Pay using UPI',
              'instruments': [
                {'method': 'upi'},
              ],
            },
          },
          'sequence': ['block.banks'],
          'preferences': {'show_default_blocks': true},
        },
      },
    });
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    if (response.orderId == null ||
        response.paymentId == null ||
        response.signature == null) {
      // Razorpay should always include all three on success — but if a
      // future SDK version drops one of them, fall back to a dialog
      // that's at least honest about what happened.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment confirmation incomplete — check Premium status in a minute.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Verify with our backend BEFORE celebrating. The webhook is still
    // a defence-in-depth path (idempotent against this verify call),
    // but in dev the webhook isn't reachable, so without this synchronous
    // verify the user pays Razorpay successfully and the plan never
    // upgrades.
    setState(() => _verifying = true);
    try {
      final r = await QuizService().payment.verifyPayment(
            VerifyPaymentRequest()
              ..razorpayOrderId = response.orderId!
              ..razorpayPaymentId = response.paymentId!
              ..razorpaySignature = response.signature!,
            options: QuizService().authCallOptions,
          );
      if (!mounted) return;
      if (!r.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("We couldn't confirm your payment. Support has been notified."),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      // Optimistically reflect the new plan in state so the dialog and
      // subsequent reload don't briefly flash "free".
      setState(() {
        _currentPlan = r.plan;
        _expiresAt = r.expiresAt;
        _lastOrder = null; // order is now consumed; retries n/a
      });
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _PaymentSuccessDialog(),
      );
      // The scoring service's payment.captured consumer will
      // canonicalise users.plan in MongoDB; refresh after a beat so the
      // history pane and any cached state reflect the truth.
      Future.delayed(const Duration(milliseconds: 500), () {
        _loadPlanStatus();
        _loadPaymentHistory();
      });
    } on GrpcError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.message ?? 'unknown error'}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;

    // Razorpay error code 0 (or BAD_REQUEST_ERROR with `code: 0`) is
    // the user actively cancelling — don't bug them with a dialog.
    if (response.code == 0) return;

    final order = _lastOrder;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(response.message ?? 'Unknown error',
                style: const TextStyle(color: AppColors.text)),
            if (response.code != null) ...[
              const SizedBox(height: 8),
              Text('Code: ${response.code}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          if (order != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                // Reopen the SAME order — no new server-side debit
                // attempt, no duplicate payment row.
                _openCheckout(order);
              },
              child: const Text('Try again'),
            ),
        ],
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Redirecting to ${response.walletName}...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = _currentPlan == 'premium';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        title: const Text('Premium'),
        elevation: 0,
      ),
      body: ScaffoldGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (isPremium) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.emeraldBg,
                  borderRadius: AppRadius.hero,
                  border: Border.all(color: AppColors.success.withAlpha(60)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.workspace_premium, size: 48, color: AppColors.success),
                    const SizedBox(height: 8),
                    const Text('You are Premium!',
                        style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.bold)),
                    if (_expiresAt != null && _expiresAt! > Int64.ZERO)
                      Text(
                        'Expires: ${DateTime.fromMillisecondsSinceEpoch(_expiresAt!.toInt() * 1000).toString().split(' ')[0]}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                  ],
                ),
              ),
            ] else ...[
              const Text('Upgrade to Premium',
                  style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // Feature comparison
              _featureRow(Icons.play_circle, 'Unlimited quizzes', 'Free: 1/day'),
              _featureRow(Icons.emoji_events, 'Join tournaments', 'Free: view only'),
              _featureRow(Icons.history, 'Full match history', 'Free: last 3'),
              _featureRow(Icons.leaderboard, 'Full leaderboard', 'Free: top 3'),

              const SizedBox(height: 24),

              // Plan selection
              Row(
                children: [
                  Expanded(child: _planCard('monthly', '299/mo', _selectedPlan == 'monthly')),
                  const SizedBox(width: 12),
                  Expanded(child: _planCard('yearly', '2,999/yr', _selectedPlan == 'yearly')),
                ],
              ),
              const SizedBox(height: 24),

              // Pay button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: AppRadius.card,
                  ),
                  child: ElevatedButton(
                    // _verifying gates the button while the
                    // VerifyPayment RPC is mid-flight after Razorpay
                    // closes — prevents a second tap re-creating an
                    // order while the previous one is still being
                    // confirmed.
                    onPressed: (_loading || _verifying) ? null : _createOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                    ),
                    child: (_loading || _verifying)
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Upgrade Now',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
            // Payment history — shown regardless of current plan so users can
            // see past renewals/failures. GetPaymentHistory caps at 20 records.
            const SizedBox(height: 32),
            _buildPaymentHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory() {
    if (_historyLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
          ),
        ),
      );
    }
    if (_paymentHistory == null || _paymentHistory!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Icon(Icons.receipt_long, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 8),
            const Text(
              'No payments yet',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Your first upgrade will appear here.',
              style: TextStyle(color: AppColors.textMuted.withAlpha(200), fontSize: 12),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment history',
            style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._paymentHistory!.map(_paymentRow),
      ],
    );
  }

  Widget _paymentRow(PaymentRecord p) {
    final date = p.createdAt.toInt() > 0
        ? DateTime.fromMillisecondsSinceEpoch(p.createdAt.toInt() * 1000)
            .toLocal()
            .toString()
            .split(' ')[0]
        : '--';
    final amountRupees = (p.amount.toInt() / 100).toStringAsFixed(2);

    Color statusColor;
    IconData statusIcon;
    switch (p.status) {
      case 'captured':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = AppColors.danger;
        statusIcon = Icons.cancel;
        break;
      default: // "created" / "pending"
        statusColor = AppColors.textMuted;
        statusIcon = Icons.hourglass_bottom;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.planDuration.isEmpty ? 'Plan' : '${p.planDuration[0].toUpperCase()}${p.planDuration.substring(1)}'} — ₹$amountRupees',
                  style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(date, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Text(p.status,
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String premium, String free) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(premium,
                    style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w600)),
                Text(free, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(String plan, String price, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: AppDurations.medium,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentBg : AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          children: [
            Text(plan[0].toUpperCase() + plan.substring(1),
                style: TextStyle(color: selected ? AppColors.accent : AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 4),
            Text(price,
                style: TextStyle(color: selected ? AppColors.text : AppColors.textSecondary, fontSize: 20, fontWeight: FontWeight.bold)),
            if (plan == 'yearly')
              Text('Save 17%',
                  style: TextStyle(color: AppColors.success.withAlpha(200), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Celebration dialog shown after Razorpay reports a successful charge. It
/// isn't confirmation that the plan was upgraded — that happens asynchronously
/// via the webhook — but it gives the user a satisfying "your payment went
/// through" moment while we wait for the backend to catch up.
///
/// Motion is a cheap DIY confetti: a pulsing gold ring + a scale-in checkmark,
/// driven by a single AnimationController so we don't need a 3rd-party pkg.
class _PaymentSuccessDialog extends StatefulWidget {
  const _PaymentSuccessDialog();

  @override
  State<_PaymentSuccessDialog> createState() => _PaymentSuccessDialogState();
}

class _PaymentSuccessDialogState extends State<_PaymentSuccessDialog>
    with TickerProviderStateMixin {
  late final AnimationController _popController;
  late final Animation<double> _scale;
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(vsync: this, duration: AppDurations.slow);
    _scale = CurvedAnimation(parent: _popController, curve: Curves.elasticOut);
    _popController.forward();

    // Continuous ring pulse while the dialog is open.
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _popController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.hero),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing ring + checkmark
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _ringController,
                    builder: (context, _) {
                      final t = _ringController.value;
                      return Container(
                        width: 100 + t * 40,
                        height: 100 + t * 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 1.0 - t),
                            width: 3,
                          ),
                        ),
                      );
                    },
                  ),
                  ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.success, Color(0xFF10B981)],
                        ),
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment successful!',
              style: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your Premium perks are activating now.\nWe'll update your status in a moment.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: AppRadius.button,
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Awesome'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
