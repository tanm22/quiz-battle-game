import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import '../providers/game_state.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../proto/quiz.pbgrpc.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GetHomeScreenDataResponse? _homeData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await QuizService().scoring.getHomeScreenData(
        GetHomeScreenDataRequest(),
        options: QuizService().authCallOptions,
      );
      if (mounted) setState(() { _homeData = resp; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e is GrpcError ? (e.message ?? 'Failed to load') : e.toString(); _loading = false; });
    }
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
          child: RefreshIndicator(
            onRefresh: _loadHomeData,
            color: const Color(0xFFFF6B35),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFFD700)],
                  ).createShader(bounds),
                  child: const Text(
                    'QUIZ BATTLE',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                // Profile card
                _buildProfileCard(auth, gameState),
                const SizedBox(height: 16),

                // Streak + Quota row
                if (_homeData != null) ...[
                  Row(
                    children: [
                      Expanded(child: _buildStreakCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuotaCard()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                ],

                if (_loading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  )),

                if (_error != null)
                  Center(child: Column(
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _loadHomeData, child: const Text('Retry')),
                    ],
                  )),

                // Play button
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
                      onPressed: () {
                        ref.read(gameStateProvider.notifier).navigateToMatchmaking();
                      },
                      icon: const Icon(Icons.bolt, size: 26),
                      label: const Text('PLAY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Secondary actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ref.read(gameStateProvider.notifier).navigateToMatchHistory(),
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('History'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withAlpha(30)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await auth.logout();
                          if (context.mounted) ref.read(gameStateProvider.notifier).logout();
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Logout'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: BorderSide(color: Colors.white.withAlpha(20)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(AuthService auth, GameState gameState) {
    final profile = _homeData?.profile;
    final name = profile?.displayName.isNotEmpty == true ? profile!.displayName : (auth.username ?? gameState.userId ?? '');
    final plan = profile?.plan ?? 'free';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white.withAlpha(15), Colors.white.withAlpha(5)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFD700)]),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF1A1145),
              child: profile?.avatarUrl.isNotEmpty == true
                  ? ClipOval(child: Image.network(profile!.avatarUrl, width: 48, height: 48, fit: BoxFit.cover))
                  : const Icon(Icons.person, color: Colors.white, size: 26),
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
                      child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ),
                    if (plan == 'premium') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFD700).withAlpha(80)),
                        ),
                        child: const Text('PRO', style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 14, color: const Color(0xFFFFD700)),
                    const SizedBox(width: 3),
                    Text('${profile?.rating ?? gameState.rating}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    if (profile != null) ...[
                      const Icon(Icons.monetization_on, size: 14, color: Color(0xFFFF6B35)),
                      const SizedBox(width: 3),
                      Text('${profile.coins}', style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    final streak = _homeData?.profile.streak;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF6B35).withAlpha(50)),
      ),
      child: Column(
        children: [
          const Icon(Icons.local_fire_department, color: Color(0xFFFF6B35), size: 28),
          const SizedBox(height: 4),
          Text('${streak?.current ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          Text('day streak', style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQuotaCard() {
    final remaining = _homeData?.quotaRemaining ?? 0;
    final limit = _homeData?.quotaLimit ?? 1;
    final isPremium = (_homeData?.profile.plan ?? 'free') == 'premium';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00E5FF).withAlpha(50)),
      ),
      child: Column(
        children: [
          const Icon(Icons.play_circle_outline, color: Color(0xFF00E5FF), size: 28),
          const SizedBox(height: 4),
          Text(
            isPremium ? '\u221e' : '$remaining/$limit',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Text(isPremium ? 'unlimited' : 'quizzes left', style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final profile = _homeData?.profile;
    final wins = profile?.wins ?? 0;
    final played = profile?.matchesPlayed ?? 0;
    final losses = played - wins;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat(Icons.emoji_events, '$wins', 'Wins', const Color(0xFF4CAF50)),
          _Stat(Icons.close, '$losses', 'Losses', const Color(0xFFFF5252)),
          _Stat(Icons.sports_esports, '$played', 'Played', Colors.white70),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _Stat(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11)),
      ],
    );
  }
}
