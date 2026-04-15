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
  String? _currentPlan;
  Int64? _expiresAt;
  late final Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadPlanStatus();
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

  Future<void> _createOrder() async {
    setState(() => _loading = true);
    try {
      final resp = await QuizService().payment.createOrder(
        CreateOrderRequest()..planDuration = _selectedPlan,
        options: QuizService().authCallOptions,
      );

      if (!mounted) return;

      // Open Razorpay checkout sheet
      _razorpay.open({
        'key': resp.keyId,
        'amount': resp.amount.toInt(),
        'order_id': resp.orderId,
        'currency': resp.currency,
        'name': 'Quiz Battle',
        'description': _selectedPlan == 'yearly' ? 'Premium Yearly' : 'Premium Monthly',
        'theme': {'color': '#1A1145'},
      });
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

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    // Show the celebratory dialog immediately. The webhook + RabbitMQ consumer
    // will asynchronously upgrade the plan; we reload plan status after the
    // dialog opens so the home state updates even if the user dismisses fast.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _PaymentSuccessDialog(),
    );
    Future.delayed(const Duration(seconds: 2), _loadPlanStatus);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message ?? 'Unknown error'}'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
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
        backgroundColor: AppColors.bgMid,
        foregroundColor: Colors.white,
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
                decoration: const BoxDecoration(
                  gradient: AppGradients.gold,
                  borderRadius: AppRadius.hero,
                ),
                child: Column(
                  children: [
                    const Icon(Icons.workspace_premium, size: 48, color: Colors.white),
                    const SizedBox(height: 8),
                    const Text('You are Premium!',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    if (_expiresAt != null && _expiresAt! > Int64.ZERO)
                      Text(
                        'Expires: ${DateTime.fromMillisecondsSinceEpoch(_expiresAt!.toInt() * 1000).toString().split(' ')[0]}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                  ],
                ),
              ),
            ] else ...[
              const Text('Upgrade to Premium',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
                child: ElevatedButton(
                  onPressed: _loading ? null : _createOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Upgrade Now',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String premium, String free) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(premium,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                Text(free, style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 12)),
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
          color: selected ? AppColors.gold.withAlpha(20) : Colors.white.withAlpha(6),
          borderRadius: AppRadius.card,
          border: Border.all(
            color: selected ? AppColors.gold : Colors.white.withAlpha(20),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(plan[0].toUpperCase() + plan.substring(1),
                style: TextStyle(color: selected ? AppColors.gold : Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            Text(price,
                style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 20, fontWeight: FontWeight.bold)),
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
      backgroundColor: AppColors.bgTop,
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
                            color: AppColors.gold.withValues(alpha: 1.0 - t),
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
                        gradient: AppGradients.gold,
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
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              "Your Premium perks are activating now.\nWe'll update your status in a moment.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                child: const Text('Awesome'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
