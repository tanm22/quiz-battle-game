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
  int _currentTab = 0;

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
      if (mounted) {
        setState(() { _homeData = resp; _loading = false; });
        _maybeShowStreakReward(resp);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e is GrpcError ? (e.message ?? 'Failed to load') : e.toString(); _loading = false; });
    }
  }

  void _maybeShowStreakReward(GetHomeScreenDataResponse data) {
    if (_rewardShown) return;
    final streak = data.profile.streak;
    if (streak.current <= 0) return;
    // Show reward dialog once per session if today's reward hasn't been claimed yet
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (streak.lastClaimedDate == today) return;
    _rewardShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showDailyRewardDialog(streak.current, streak.current * 10);
    });
  }

  void _showDailyRewardDialog(int streakDay, int coins) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DailyRewardDialog(streakDay: streakDay, coins: coins),
    );
  }

  // ---------------------------------------------------------------------------
  // Build — scaffold with bottom navigation
  // ---------------------------------------------------------------------------

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
          child: _buildTabContent(auth, gameState),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) {
          if (index == 1) {
            // Play — trigger matchmaking directly
            ref.read(gameStateProvider.notifier).navigateToMatchmaking();
          } else {
            setState(() => _currentTab = index);
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF150F35),
        selectedItemColor: const Color(0xFFFF6B35),
        unselectedItemColor: Colors.white38,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.play_circle_filled, size: 32), label: 'Play'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard_rounded), label: 'Leaderboard'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildTabContent(AuthService auth, GameState gs) {
    switch (_currentTab) {
      case 2:
        return _buildLeaderboardTab();
      case 3:
        return _buildProfileTab(auth, gs);
      default:
        return _buildHomeTab(auth, gs);
    }
  }

  // ---------------------------------------------------------------------------
  // Home tab
  // ---------------------------------------------------------------------------

  Widget _buildHomeTab(AuthService auth, GameState gameState) {
    final isPremium = (_homeData?.profile.plan ?? 'free') == 'premium';
    final remaining = _homeData?.quotaRemaining ?? 0;
    final quotaExhausted = !isPremium && _homeData != null && remaining <= 0;

    return RefreshIndicator(
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

          // Play button — disabled when quota exhausted
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: quotaExhausted
                    ? LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade600])
                    : const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8F5E)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: quotaExhausted
                    ? []
                    : [BoxShadow(color: const Color(0xFFFF6B35).withAlpha(100), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: ElevatedButton.icon(
                onPressed: quotaExhausted
                    ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()))
                    : () => ref.read(gameStateProvider.notifier).navigateToMatchmaking(),
                icon: Icon(quotaExhausted ? Icons.lock : Icons.bolt, size: 26),
                label: Text(
                  quotaExhausted ? 'UPGRADE TO PLAY' : 'START BATTLE',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
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
          const SizedBox(height: 16),

          // Premium upsell card (free users only)
          if (!isPremium && _homeData != null) ...[
            _buildUpsellCard(),
            const SizedBox(height: 16),
          ],

          // Leaderboard preview
          if (_homeData != null && _homeData!.leaderboardPreview.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.leaderboard, color: Color(0xFFFFD700), size: 20),
                const SizedBox(width: 8),
                const Text('Top Players', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _currentTab = 2),
                  child: Text('See all', style: TextStyle(color: const Color(0xFFFF6B35).withAlpha(200), fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._homeData!.leaderboardPreview.take(5).map((e) => _leaderboardRow(e)),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Leaderboard tab
  // ---------------------------------------------------------------------------

  Widget _buildLeaderboardTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              const Icon(Icons.leaderboard, color: Color(0xFFFFD700), size: 28),
              const SizedBox(width: 10),
              const Text('Leaderboard', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        if (_loading && _homeData == null)
          const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))),
        if (_homeData != null && _homeData!.leaderboardPreview.isNotEmpty)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _homeData!.leaderboardPreview.length,
              itemBuilder: (_, i) => _leaderboardRow(_homeData!.leaderboardPreview[i]),
            ),
          ),
        if (_homeData != null && _homeData!.leaderboardPreview.isEmpty)
          Expanded(child: Center(child: Text('No leaderboard data yet', style: TextStyle(color: Colors.white.withAlpha(100))))),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Profile tab
  // ---------------------------------------------------------------------------

  Widget _buildProfileTab(AuthService auth, GameState gameState) {
    final profile = _homeData?.profile;

    return RefreshIndicator(
      onRefresh: _loadHomeData,
      color: const Color(0xFFFF6B35),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          _buildProfileCard(auth, gameState),
          const SizedBox(height: 16),

          // Guest email-link prompt
          if (gameState.isGuest) ...[
            _buildLinkEmailPrompt(),
            const SizedBox(height: 16),
          ],

          // Info rows
          if (auth.email != null && auth.email!.isNotEmpty)
            _profileInfoRow(Icons.email, 'Email', auth.email!),
          if (profile?.referralCode.isNotEmpty == true)
            _profileInfoRow(Icons.card_giftcard, 'Referral Code', profile!.referralCode),

          const SizedBox(height: 16),

          // Actions
          _profileActionButton(Icons.history, 'Match History', () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => MatchHistoryScreen(currentUserId: gameState.userId ?? ''),
            ));
          }),
          const SizedBox(height: 8),
          _profileActionButton(Icons.workspace_premium, 'Premium', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()));
          }, color: const Color(0xFFFFD700)),
          const SizedBox(height: 8),
          _profileActionButton(Icons.share, 'Invite Friends', () {
            _showShareDialog(gameState);
          }),

          const SizedBox(height: 32),

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
    );
  }

  Widget _profileInfoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileActionButton(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? Colors.white70,
          side: BorderSide(color: (color ?? Colors.white).withAlpha(30)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Cards
  // ---------------------------------------------------------------------------

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
                      errorBuilder: (_, e, s) => const Icon(Icons.person, color: Colors.white, size: 26)))
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
                      Text('${profile.wins}W/${profile.matchesPlayed - profile.wins}L',
                        style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13, fontWeight: FontWeight.w600)),
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
              style: TextStyle(color: Colors.white, fontSize: isPremium ? 16 : 22, fontWeight: FontWeight.w900)),
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
    final streak = profile?.streak.current ?? 0;
    // Matches today = quotaUsed = quotaLimit - quotaRemaining
    final matchesToday = (_homeData?.quotaLimit ?? 0) - (_homeData?.quotaRemaining ?? 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white.withAlpha(6), borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat(Icons.emoji_events, '$wins', 'Wins', const Color(0xFF4CAF50)),
          _Stat(Icons.close, '$losses', 'Losses', const Color(0xFFFF5252)),
          _Stat(Icons.today, '$matchesToday', 'Today', Colors.white70),
          _Stat(Icons.local_fire_department, '$streak', 'Streak', const Color(0xFFFF6B35)),
        ],
      ),
    );
  }

  Widget _buildUpsellCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFFFD700).withAlpha(20), const Color(0xFFFF6B35).withAlpha(15)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD700).withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 24),
              const SizedBox(width: 10),
              const Text('Go Premium', style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          _upsellBenefit(Icons.all_inclusive, 'Unlimited quizzes every day'),
          _upsellBenefit(Icons.leaderboard, 'Full leaderboard access'),
          _upsellBenefit(Icons.bolt, 'Priority matchmaking'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _upsellBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
              builder: (context, child) => Transform.scale(
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
