import 'package:flutter/material.dart';
import '../proto/quiz.pb.dart';
import '../services/quiz_service.dart';

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1145), Color(0xFF0F0E2E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Icon(Icons.history, color: Color(0xFFFF6B35), size: 26),
                    const SizedBox(width: 10),
                    const Text('Match History', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                                const SizedBox(height: 12),
                                Text(_error!, style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                TextButton(onPressed: _loadHistory, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : _matches.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.sports_esports, color: Colors.white.withAlpha(60), size: 64),
                                    const SizedBox(height: 16),
                                    Text('No matches yet', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 18)),
                                    const SizedBox(height: 8),
                                    Text('Play a match to see your history here!', style: TextStyle(color: Colors.white.withAlpha(60), fontSize: 14)),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadHistory,
                                color: const Color(0xFFFF6B35),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: _matches.length,
                                  itemBuilder: (context, index) => _MatchCard(
                                    match: _matches[index],
                                    currentUserId: widget.currentUserId,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner ? const Color(0xFF4CAF50).withAlpha(50) : const Color(0xFFFF4444).withAlpha(50),
        ),
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
            color: isWinner ? const Color(0xFF4CAF50).withAlpha(30) : const Color(0xFFFF4444).withAlpha(30),
          ),
          child: Icon(
            isWinner ? Icons.emoji_events : Icons.close,
            color: isWinner ? const Color(0xFF4CAF50) : const Color(0xFFFF4444),
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Text(
              isWinner ? 'Victory' : 'Defeat',
              style: TextStyle(
                color: isWinner ? const Color(0xFF4CAF50) : const Color(0xFFFF4444),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (myResult != null)
              Text(
                '${myResult.finalScore.toInt()} pts',
                style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 15),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              'vs ${opponent?.username ?? opponent?.userId ?? "Unknown"}',
              style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 13),
            ),
            const Spacer(),
            Text(timeAgo, style: TextStyle(color: Colors.white.withAlpha(60), fontSize: 12)),
          ],
        ),
        iconColor: Colors.white38,
        collapsedIconColor: Colors.white38,
        children: [
          // Expanded details
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _DetailRow('Rounds', '${match.rounds}'),
                _DetailRow('Duration', '${match.duration}s'),
                if (myResult != null) ...[
                  _DetailRow('Correct Answers', '${myResult.answersCorrect}'),
                  _DetailRow('Avg Response', '${myResult.avgResponseTimeMs.toInt()} ms'),
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
                            color: p.rank == 1 ? const Color(0xFFFFD700).withAlpha(30) : Colors.white.withAlpha(10),
                          ),
                          child: Center(child: Text('#${p.rank}', style: TextStyle(
                            color: p.rank == 1 ? const Color(0xFFFFD700) : Colors.white54,
                            fontSize: 11, fontWeight: FontWeight.bold,
                          ))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          p.username.isEmpty ? p.userId : p.username,
                          style: TextStyle(color: isSelf ? Colors.white : Colors.white70, fontSize: 14, fontWeight: isSelf ? FontWeight.bold : FontWeight.normal),
                        )),
                        Text('${p.finalScore.toInt()}', style: TextStyle(
                          color: p.rank == 1 ? const Color(0xFFFFD700) : Colors.white,
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
          Text(label, style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
