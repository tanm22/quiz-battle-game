import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import '../services/quiz_service.dart';
import '../proto/quiz.pbgrpc.dart';
import 'payment_screen.dart';

class TournamentScreen extends StatefulWidget {
  final String currentPlan;
  const TournamentScreen({super.key, required this.currentPlan});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  List<TournamentInfo>? _tournaments;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await QuizService().getTournamentList();
      if (mounted) setState(() { _tournaments = resp.tournaments; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e is GrpcError ? (e.message ?? 'Failed to load') : e.toString(); _loading = false; });
    }
  }

  Future<void> _join(TournamentInfo t) async {
    if (t.requiredPlan == 'premium' && widget.currentPlan != 'premium') {
      _showUpgradeDialog();
      return;
    }
    try {
      await QuizService().joinTournament(t.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined "${t.name}"!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
        _load(); // refresh count
      }
    } on GrpcError catch (e) {
      if (mounted) {
        if (e.code == StatusCode.permissionDenied) {
          _showUpgradeDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Failed to join'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1F5E),
        title: const Text('Premium Required', style: TextStyle(color: Colors.white)),
        content: const Text('Upgrade to Premium to join tournaments and compete for prizes!', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1145),
        foregroundColor: Colors.white,
        title: const Text('Tournaments'),
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
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: Color(0xFFFF6B35)))),
                    ],
                  ))
                : _tournaments == null || _tournaments!.isEmpty
                    ? Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events, color: Colors.white.withAlpha(40), size: 64),
                          const SizedBox(height: 12),
                          Text('No tournaments right now', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('Check back soon!', style: TextStyle(color: Colors.white.withAlpha(60), fontSize: 13)),
                        ],
                      ))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: const Color(0xFFFF6B35),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _tournaments!.length,
                          itemBuilder: (_, i) => _tournamentCard(_tournaments![i]),
                        ),
                      ),
      ),
    );
  }

  Widget _tournamentCard(TournamentInfo t) {
    final isActive = t.status == 'active';
    final isPremiumRequired = t.requiredPlan == 'premium';
    final canJoin = !isPremiumRequired || widget.currentPlan == 'premium';

    final start = DateTime.fromMillisecondsSinceEpoch(t.startTime.toInt() * 1000);
    final end = DateTime.fromMillisecondsSinceEpoch(t.endTime.toInt() * 1000);
    final timeLabel = isActive
        ? 'Ends ${_formatTime(end)}'
        : 'Starts ${_formatTime(start)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF4CAF50).withAlpha(60) : Colors.white.withAlpha(15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: isActive ? const Color(0xFF4CAF50) : const Color(0xFFFFD700),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF4CAF50).withAlpha(25) : const Color(0xFFFF6B35).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isActive ? 'LIVE' : 'UPCOMING',
                  style: TextStyle(
                    color: isActive ? const Color(0xFF4CAF50) : const Color(0xFFFF6B35),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Info row
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.white.withAlpha(100), size: 14),
              const SizedBox(width: 4),
              Text(timeLabel, style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 12)),
              const SizedBox(width: 16),
              Icon(Icons.people, color: Colors.white.withAlpha(100), size: 14),
              const SizedBox(width: 4),
              Text('${t.participantCount} joined', style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 12)),
            ],
          ),
          if (t.prizeDescription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.card_giftcard, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(t.prizeDescription, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13))),
              ],
            ),
          ],
          if (isPremiumRequired) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 6),
                const Text('Premium only', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _join(t),
              style: ElevatedButton.styleFrom(
                backgroundColor: canJoin ? const Color(0xFFFF6B35) : Colors.grey.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                canJoin ? 'Join Tournament' : 'Upgrade to Join',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inDays > 0) return 'in ${diff.inDays}d';
    if (diff.inHours > 0) return 'in ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'in ${diff.inMinutes}m';
    if (diff.isNegative) {
      final ago = now.difference(dt);
      if (ago.inDays > 0) return '${ago.inDays}d ago';
      if (ago.inHours > 0) return '${ago.inHours}h ago';
      return '${ago.inMinutes}m ago';
    }
    return 'soon';
  }
}
