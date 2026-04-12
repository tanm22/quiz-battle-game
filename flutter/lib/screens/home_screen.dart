import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import '../providers/game_state.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../proto/quiz.pbgrpc.dart';
import 'match_history_screen.dart';
import 'payment_screen.dart';
import 'link_email_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GetHomeScreenDataResponse? _homeData;
  bool _loading = true;
  String? _error;
  bool _rewardShown = false;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
    _checkStreakReward();
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

  void _checkStreakReward() {
    // Show daily reward popup if streak was updated on login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gs = ref.read(gameStateProvider);
      // The AuthResponse carries streakUpdated/reward — check via the login flow
      // For now we rely on the home data streak info
      if (!_rewardShown && gs.currentScreen == GameScreen.home) {
        _rewardShown = true;
        // Popup will be shown after home data loads if streak > 0
      }
    });
  }

  void _showDailyRewardDialog(int streakDay, int coins) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DailyRewardDialog(streakDay: streakDay, coins: coins),
    );
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

                // Guest email-link prompt
                if (gameState.isGuest)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildLinkEmailPrompt(),
                  ),

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
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                ],

                if (_loading && _homeData == null)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  )),

                if (_error != null)
                  Center(child: Column(
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _loadHomeData, child: const Text('Retry', style: TextStyle(color: Color(0xFFFF6B35)))),
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
                      onPressed: () => ref.read(gameStateProvider.notifier).navigateToMatchmaking(),
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
                const SizedBox(height: 16),

                // Action row: History, Premium, Referral
                Row(
                  children: [
                    Expanded(child: _actionButton(Icons.history, 'History', () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MatchHistoryScreen(currentUserId: gameState.userId ?? ''),
                      ));
                    })),
                    const SizedBox(width: 10),
                    Expanded(child: _actionButton(Icons.workspace_premium, 'Premium', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()));
                    }, color: const Color(0xFFFFD700))),
                    const SizedBox(width: 10),
                    Expanded(child: _actionButton(Icons.share, 'Invite', () {
                      _showShareDialog(gameState);
                    })),
                  ],
                ),
                const SizedBox(height: 12),

                // Leaderboard preview
                if (_homeData != null && _homeData!.leaderboardPreview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.leaderboard, color: Color(0xFFFFD700), size: 20),
                      const SizedBox(width: 8),
                      const Text('Top Players', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._homeData!.leaderboardPreview.map((e) => _leaderboardRow(e)),
                ],

                const SizedBox(height: 24),

                // Logout + Delete
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await auth.logout();
                        if (context.mounted) ref.read(gameStateProvider.notifier).logout();
                      },
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('Logout'),
                      style: TextButton.styleFrom(foregroundColor: Colors.white38),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () => _confirmDeleteAccount(auth),
                      icon: const Icon(Icons.delete_forever, size: 16),
                      label: const Text('Delete Account'),
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent.withAlpha(150)),
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

  Widget _actionButton(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? Colors.white70,
        side: BorderSide(color: (color ?? Colors.white).withAlpha(30)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLinkEmailPrompt() {
    return Container(
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
          ElevatedButton(
            onPressed: () => showModalBottomSheet(
              context: context, isScrollControlled: true,
              backgroundColor: Colors.transparent, builder: (_) => const LinkEmailScreen(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Link', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(GameState gs) {
    final code = _homeData?.profile.referralCode ?? '';
    if (code.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1F5E),
        title: const Text('Invite Friends', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share your referral code:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF6B35).withAlpha(80)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(code, style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Friends get 50 coins, you get 100 coins when they complete their first quiz!',
              style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(AuthService auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1F5E),
        title: const Text('Delete Account?', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently delete your account and all progress.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.deleteAccount();
              if (mounted) ref.read(gameStateProvider.notifier).logout();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(AuthService auth, GameState gameState) {
    final profile = _homeData?.profile;
    final name = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : (profile?.username.isNotEmpty == true ? profile!.username : (auth.username ?? ''));
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
                  ? ClipOval(child: Image.network(profile!.avatarUrl, width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 26)))
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
                    Flexible(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    if (gameState.isGuest) ...[
                      const SizedBox(width: 8),
                      _badge('Guest', const Color(0xFF00E5FF)),
                    ],
                    if (plan == 'premium') ...[
                      const SizedBox(width: 8),
                      _badge('PRO', const Color(0xFFFFD700)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Color(0xFFFFD700)),
                    const SizedBox(width: 3),
                    Text('${profile?.rating ?? gameState.rating}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w600)),
                    if (profile != null) ...[
                      const SizedBox(width: 12),
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

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
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

    return GestureDetector(
      onTap: isPremium ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen())),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5FF).withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF00E5FF).withAlpha(50)),
        ),
        child: Column(
          children: [
            Icon(isPremium ? Icons.all_inclusive : Icons.play_circle_outline, color: const Color(0xFF00E5FF), size: 28),
            const SizedBox(height: 4),
            Text(isPremium ? 'Unlimited' : '$remaining/$limit',
              style: const TextStyle(color: Colors.white, fontSize: isPremium ? 16 : 22, fontWeight: FontWeight.w900)),
            Text(isPremium ? 'premium' : 'quizzes left', style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 12)),
          ],
        ),
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
      decoration: BoxDecoration(color: Colors.white.withAlpha(6), borderRadius: BorderRadius.circular(14)),
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

  Widget _leaderboardRow(LeaderboardEntry e) {
    final isMedal = e.rank <= 3;
    const medalColors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
    final color = isMedal ? medalColors[e.rank - 1] : Colors.white54;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5), borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('#${e.rank}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14))),
          const SizedBox(width: 8),
          Expanded(child: Text(e.username.isEmpty ? e.userId : e.username, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          Text('${e.score.toInt()}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
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

class _DailyRewardDialog extends StatefulWidget {
  final int streakDay;
  final int coins;
  const _DailyRewardDialog({required this.streakDay, required this.coins});

  @override
  State<_DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<_DailyRewardDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A1F5E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Transform.scale(
                scale: _scale.value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                    boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withAlpha(80), blurRadius: 30)],
                  ),
                  child: const Icon(Icons.local_fire_department, size: 44, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Day ${widget.streakDay}!', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('+${widget.coins} coins', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Keep your streak alive!', style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await AuthService().claimDailyReward();
                  } catch (_) {}
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Claim!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
