import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import '../services/quiz_service.dart';
import '../proto/quiz.pbgrpc.dart';
import '../theme/app_theme.dart';
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
          SnackBar(content: Text('Joined "${t.name}"!'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
        );
        _load(); // refresh count
      }
    } on GrpcError catch (e) {
      if (mounted) {
        if (e.code == StatusCode.permissionDenied) {
          _showUpgradeDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Failed to join'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.hero),
        title: const Text('Premium Required', style: TextStyle(color: AppColors.text)),
        content: const Text('Upgrade to Premium to join tournaments and compete for prizes!', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
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
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        title: const Text('Tournaments'),
        elevation: 0,
      ),
      body: ScaffoldGradientBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.roseBg),
                        child: const Icon(Icons.error_outline, color: AppColors.danger, size: 24),
                      ),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: AppColors.primary))),
                    ],
                  ))
                : _tournaments == null || _tournaments!.isEmpty
                    ? Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.goldBg),
                            child: const Icon(Icons.emoji_events, color: AppColors.gold, size: 32),
                          ),
                          const SizedBox(height: 12),
                          const Text('No tournaments right now', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text('Check back soon!', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                        ],
                      ))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
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
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: isActive ? AppColors.success.withAlpha(80) : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x14000000), blurRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppColors.emeraldBg : AppColors.goldBg,
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: isActive ? AppColors.success : AppColors.gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t.name, style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.emeraldBg : AppColors.orangeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isActive ? 'LIVE' : 'UPCOMING',
                  style: TextStyle(
                    color: isActive ? AppColors.success : AppColors.primary,
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
              const Icon(Icons.schedule, color: AppColors.textDim, size: 14),
              const SizedBox(width: 4),
              Text(timeLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(width: 16),
              const Icon(Icons.people, color: AppColors.textDim, size: 14),
              const SizedBox(width: 4),
              Text('${t.participantCount} joined', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          if (t.prizeDescription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.card_giftcard, color: AppColors.gold, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(t.prizeDescription, style: const TextStyle(color: AppColors.gold, fontSize: 13))),
              ],
            ),
          ],
          if (isPremiumRequired) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.workspace_premium, color: AppColors.gold, size: 14),
                const SizedBox(width: 6),
                const Text('Premium only', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: canJoin ? AppGradients.primary : null,
                color: canJoin ? null : AppColors.border,
                borderRadius: AppRadius.button,
              ),
              child: ElevatedButton(
                onPressed: () => _join(t),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  canJoin ? 'Join Tournament' : 'Upgrade to Join',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
