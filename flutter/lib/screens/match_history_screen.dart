import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../proto/quiz.pb.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class MatchHistoryScreen extends StatefulWidget {
  final String currentUserId;
  const MatchHistoryScreen({super.key, required this.currentUserId});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  List<MatchHistoryEntry> _matches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await QuizService().getMatchHistory(limit: 30);
      setState(() { _matches = resp.matches; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScaffoldGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Icon(Icons.history, color: AppColors.primary, size: 26),
                    const SizedBox(width: 10),
                    const Text('Match History', style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _error != null
                        ? EmptyState(
                            icon: Icons.cloud_off_rounded,
                            iconColor: AppColors.danger,
                            title: "Couldn't load matches",
                            body: _error,
                            actionLabel: 'Retry',
                            onActionTap: _loadHistory,
                          )
                        : _matches.isEmpty
                            ? const EmptyState(
                                icon: Icons.sports_esports_rounded,
                                iconColor: AppColors.accent,
                                title: 'No matches yet',
                                body: 'Play your first quiz battle and your match history will populate here.',
                              )
                            : RefreshIndicator(
                                onRefresh: _loadHistory,
                                color: AppColors.primary,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                  itemCount: _matches.length,
                                  itemBuilder: (context, index) => _MatchCard(
                                    match: _matches[index],
                                    currentUserId: widget.currentUserId,
                                  )
                                      .animate()
                                      .fadeIn(
                                        delay: Duration(milliseconds: 30 * (index % 8)),
                                        duration: 250.ms,
                                      )
                                      .slideY(
                                        begin: 0.05,
                                        end: 0,
                                        curve: Curves.easeOutCubic,
                                      ),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchHistoryEntry match;
  final String currentUserId;
  const _MatchCard({required this.match, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final isWinner = match.winner == currentUserId;
    final myResult = match.players.where((p) => p.userId == currentUserId).firstOrNull;
    final opponent = match.players.where((p) => p.userId != currentUserId).firstOrNull;
    final date = DateTime.fromMillisecondsSinceEpoch(match.createdAt.toInt() * 1000);
    final timeAgo = _timeAgo(date);

    final borderColor = isWinner ? AppColors.success : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withAlpha(100)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isWinner ? AppColors.emeraldBg : AppColors.roseBg,
          ),
          child: Icon(
            isWinner ? Icons.emoji_events : Icons.close,
            color: isWinner ? AppColors.success : AppColors.danger,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Text(
              isWinner ? 'Victory' : 'Defeat',
              style: TextStyle(
                color: isWinner ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (myResult != null)
              Text(
                '${myResult.finalScore.toInt()} pts',
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 15),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              'vs ${opponent?.username ?? opponent?.userId ?? "Unknown"}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const Spacer(),
            Text(timeAgo, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          ],
        ),
        iconColor: AppColors.textDim,
        collapsedIconColor: AppColors.textDim,
        children: [
          // Expanded details
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _DetailRow('Rounds', '${match.rounds}'),
                if (myResult != null) ...[
                  _DetailRow('Correct Answers', '${myResult.answersCorrect}'),
                  _DetailRow('Rank', '#${myResult.rank}'),
                ],
                const SizedBox(height: 10),
                // All players
                ...match.players.map((p) {
                  final isSelf = p.userId == currentUserId;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.rank == 1 ? AppColors.goldBg : AppColors.cardTint,
                          ),
                          child: Center(child: Text('#${p.rank}', style: TextStyle(
                            color: p.rank == 1 ? AppColors.gold : AppColors.textMuted,
                            fontSize: 11, fontWeight: FontWeight.bold,
                          ))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          p.username.isEmpty ? p.userId : p.username,
                          style: TextStyle(color: isSelf ? AppColors.text : AppColors.textSecondary, fontSize: 14, fontWeight: isSelf ? FontWeight.bold : FontWeight.normal),
                        )),
                        Text('${p.finalScore.toInt()}', style: TextStyle(
                          color: p.rank == 1 ? AppColors.success : AppColors.text,
                          fontWeight: FontWeight.bold,
                        )),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
