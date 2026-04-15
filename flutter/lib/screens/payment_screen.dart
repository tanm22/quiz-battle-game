import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/quiz_service.dart';
import '../proto/quiz.pbgrpc.dart';

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
          SnackBar(content: Text(e.message ?? 'Payment failed'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment successful! Activating Premium...'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
    );
    // Reload plan status — the webhook + RabbitMQ consumer will have upgraded the plan
    Future.delayed(const Duration(seconds: 2), _loadPlanStatus);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message ?? 'Unknown error'}'),
        backgroundColor: Colors.redAccent,
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
        backgroundColor: const Color(0xFF1A1145),
        foregroundColor: Colors.white,
        title: const Text('Premium'),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1145), Color(0xFF0F0E2E)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (isPremium) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.workspace_premium, size: 48, color: Colors.white),
                    const SizedBox(height: 8),
                    const Text('You are Premium!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    if (_expiresAt != null && _expiresAt! > Int64.ZERO)
                      Text(
                        'Expires: ${DateTime.fromMillisecondsSinceEpoch(_expiresAt!.toInt() * 1000).toString().split(' ')[0]}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                  ],
                ),
              ),
            ] else ...[
              const Text('Upgrade to Premium', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Upgrade Now', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
          Icon(icon, color: const Color(0xFFFFD700), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(premium, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFD700).withAlpha(20) : Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFFFD700) : Colors.white.withAlpha(20),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(plan[0].toUpperCase() + plan.substring(1), style: TextStyle(color: selected ? const Color(0xFFFFD700) : Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            Text(price, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 20, fontWeight: FontWeight.bold)),
            if (plan == 'yearly')
              Text('Save 17%', style: TextStyle(color: const Color(0xFF4CAF50).withAlpha(200), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
