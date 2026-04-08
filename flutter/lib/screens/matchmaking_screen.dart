import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state.dart';
import '../services/auth_service.dart';
import 'link_email_screen.dart';
import 'match_history_screen.dart';

class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startBattle() {
    final gameState = ref.read(gameStateProvider);
    final userId = gameState.userId;
    if (userId == null) return;
    setState(() => _isSearching = true);
    _pulseController.repeat();
    ref.read(gameStateProvider.notifier).joinMatchmaking(userId, gameState.rating);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final auth = AuthService();

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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFFD700)],
                    ).createShader(bounds),
                    child: const Text(
                      'QUIZ BATTLE',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white.withAlpha(15), Colors.white.withAlpha(5)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withAlpha(25)),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFD700)]),
                          ),
                          child: const CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(0xFF1A1145),
                            child: Icon(Icons.person, color: Colors.white, size: 24),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      auth.username ?? gameState.userId ?? '',
                                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (gameState.isGuest) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E5FF).withAlpha(30),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF00E5FF).withAlpha(80)),
                                      ),
                                      child: const Text('Guest', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Rating + stats row
                              Row(
                                children: [
                                  _StatChip(icon: Icons.star, label: '${gameState.rating}', color: const Color(0xFFFFD700)),
                                  const SizedBox(width: 12),
                                  _StatChip(icon: Icons.emoji_events, label: '${auth.wins}W', color: const Color(0xFF4CAF50)),
                                  const SizedBox(width: 12),
                                  _StatChip(icon: Icons.close, label: '${auth.matchesPlayed - auth.wins}L', color: const Color(0xFFFF5252)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white54),
                          color: const Color(0xFF2A1F5E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (value) async {
                            if (value == 'logout') {
                              await auth.logout();
                              ref.read(gameStateProvider.notifier).logout();
                            } else if (value == 'delete') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF2A1F5E),
                                  title: const Text('Delete Account?', style: TextStyle(color: Colors.white)),
                                  content: const Text('This will permanently delete your account and all progress.', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await auth.deleteAccount();
                                if (context.mounted) ref.read(gameStateProvider.notifier).logout();
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'logout', child: Row(children: [
                              Icon(Icons.logout, color: Colors.white70, size: 20), SizedBox(width: 8),
                              Text('Logout', style: TextStyle(color: Colors.white70)),
                            ])),
                            const PopupMenuItem(value: 'delete', child: Row(children: [
                              Icon(Icons.delete_forever, color: Colors.redAccent, size: 20), SizedBox(width: 8),
                              Text('Delete Account', style: TextStyle(color: Colors.redAccent)),
                            ])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Guest email-link prompt
                  if (gameState.isGuest)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00E5FF).withAlpha(60)),
                        color: const Color(0xFF00E5FF).withAlpha(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, color: Color(0xFF00E5FF), size: 26),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Link your email to save progress', style: TextStyle(color: Colors.white70, fontSize: 13))),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context, isScrollControlled: true,
                                backgroundColor: Colors.transparent, builder: (_) => const LinkEmailScreen(),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Link', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 36),

                  if (_isSearching) ...[
                    // Pulsing search animation
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 130 + (_pulseController.value * 30),
                          height: 130 + (_pulseController.value * 30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withValues(alpha: 1.0 - _pulseController.value),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF00E5FF).withAlpha(20),
                              ),
                              child: const Icon(Icons.search, color: Color(0xFF00E5FF), size: 44),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text('Finding opponent...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Searching for a worthy challenger', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 14)),
                    const SizedBox(height: 28),
                    TextButton(
                      onPressed: () {
                        setState(() => _isSearching = false);
                        _pulseController.stop();
                        _pulseController.reset();
                        ref.read(gameStateProvider.notifier).leaveMatch();
                      },
                      child: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
                    ),
                  ] else ...[
                    // Match History button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final userId = gameState.userId;
                          if (userId == null) return;
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => MatchHistoryScreen(currentUserId: userId),
                          ));
                        },
                        icon: const Icon(Icons.history, size: 20),
                        label: const Text('Match History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withAlpha(30)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Start Battle button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8F5E)]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withAlpha(100), blurRadius: 20, offset: const Offset(0, 6))],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _startBattle,
                          icon: const Icon(Icons.bolt, size: 26),
                          label: const Text('START BATTLE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
