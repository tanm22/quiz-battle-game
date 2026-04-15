import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grpc/grpc.dart';
import 'package:share_plus/share_plus.dart';
import '../services/quiz_service.dart';
import '../proto/quiz.pbgrpc.dart';
import '../widgets/animated_toast.dart';

/// Referral dashboard — shows total invites, conversions, coins earned,
/// the user's own code (copy/share), and an input to apply a friend's code.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  GetReferralDashboardResponse? _data;
  bool _loading = true;
  String? _error;

  final _codeController = TextEditingController();
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await QuizService().getReferralDashboard();
      if (mounted) setState(() { _data = resp; _loading = false; });
    } on GrpcError catch (e) {
      if (mounted) setState(() { _error = e.message ?? 'Failed to load'; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _shareCode() async {
    final code = _data?.referralCode;
    if (code == null || code.isEmpty) return;
    await Share.share(
      'Join me on Quiz Battle! Use my referral code $code when signing up — we both earn coins. https://quizbattle.app',
      subject: 'Join me on Quiz Battle',
    );
  }

  Future<void> _copyCode() async {
    final code = _data?.referralCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      showAnimatedToast(context, message: 'Code copied!');
    }
  }

  Future<void> _applyCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _applying = true);
    try {
      await QuizService().applyReferralCode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Referral applied! Play your first quiz to earn 50 coins.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _codeController.clear();
      await _load();
    } on GrpcError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to apply code'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1145),
        foregroundColor: Colors.white,
        title: const Text('Referrals'),
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
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white54),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFFFF6B35),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Stat cards
          Row(
            children: [
              Expanded(child: _statCard('Invites', d.totalInvites.toString(), Icons.people, const Color(0xFF00E5FF))),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Converted', d.conversions.toString(), Icons.check_circle, const Color(0xFF4CAF50))),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Coins', d.coinsEarned.toString(), Icons.monetization_on, const Color(0xFFFFD700))),
            ],
          ),
          const SizedBox(height: 24),

          // Your code
          const Text('Your referral code', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withAlpha(15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFF6B35).withAlpha(80)),
            ),
            child: Column(
              children: [
                Text(
                  d.referralCode.isEmpty ? 'Not generated yet' : d.referralCode,
                  style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 3),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: d.referralCode.isEmpty ? null : _copyCode,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withAlpha(60)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: d.referralCode.isEmpty ? null : _shareCode,
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Rewards explanation
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white54, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Friends get 50 coins, you get 100 coins — paid when they complete their first quiz. Cap: 20 conversions.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Apply someone else's code
          const Text('Have a friend\'s code?', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _codeController,
            style: const TextStyle(color: Colors.white, letterSpacing: 2),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'REFXXXXXXXX',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withAlpha(10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withAlpha(30)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _applying ? null : _applyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _applying
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Apply code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
