import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/game_state.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_toast.dart';
import '../widgets/coin_balance_chip.dart';
import '../widgets/streak_calendar.dart';
import '../proto/quiz.pbgrpc.dart';
import 'shop/shop_screen.dart';
import 'match_history_screen.dart';
import 'payment_screen.dart';
import 'link_email_screen.dart';
import 'tournament_screen.dart';
import 'referral_screen.dart';

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
  // Leaderboard tab state
  String _lbFilter = 'alltime';
  List<LeaderboardEntry>? _lbEntries;
  bool _lbLoading = false;

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

  Future<void> _loadLeaderboard([String? filter]) async {
    final f = filter ?? _lbFilter;
    setState(() { _lbLoading = true; _lbFilter = f; });
    try {
      final resp = await QuizService().getGlobalLeaderboard(timeFilter: f);
      if (mounted) setState(() { _lbEntries = resp.entries; _lbLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _lbLoading = false);
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
      body: ScaffoldGradientBackground(
        child: SafeArea(
          child: _buildTabContent(auth, gameState),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.bgNav,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textDim,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bolt_rounded), label: 'Play'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard_rounded), label: 'Leaderboard'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildTabContent(AuthService auth, GameState gs) {
    switch (_currentTab) {
      case 1:
        // "Play" is a stateless action tab — we don't render a page, we fire
        // the Play action and snap back to Home so the user sees the match
        // in progress (or the upgrade prompt if their quota is exhausted).
        WidgetsBinding.instance.addPostFrameCallback((_) => _handlePlayTab());
        return _buildHomeTab(auth, gs);
      case 2:
        return _buildLeaderboardTab();
      case 3:
        return _buildProfileTab(auth, gs);
      default:
        return _buildHomeTab(auth, gs);
    }
  }

  /// Called when the user taps the Play tab. If they have quota, route to
  /// matchmaking. If not, push the upgrade screen. Always reset the tab index
  /// back to Home so the Play tab acts like an action, not a destination.
  void _handlePlayTab() {
    setState(() => _currentTab = 0); // snap back to Home

    // Don't route anywhere if the home data hasn't loaded — the quota gate
    // depends on it. A brief snackbar is less confusing than silently
    // sending the user into matchmaking with stale defaults.
    if (_homeData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading your stats… try again in a moment.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isPremium = _homeData!.profile.plan == 'premium';
    final remaining = _homeData!.quotaRemaining;
    final quotaExhausted = !isPremium && remaining <= 0;

    if (quotaExhausted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()));
    } else {
      ref.read(gameStateProvider.notifier).navigateToMatchmaking();
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
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Title
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.primary, AppColors.gold],
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

          // Streak + Quota row — either loaded cards or skeletons while fetching.
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
          ] else if (_loading && _error == null) ...[
            Row(
              children: [
                Expanded(child: _skeletonTile(height: 96)),
                const SizedBox(width: 12),
                Expanded(child: _skeletonTile(height: 96)),
              ],
            ),
            const SizedBox(height: 16),
            _skeletonTile(height: 62),
            const SizedBox(height: 24),
          ],

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.roseBg,
                borderRadius: AppRadius.card,
                border: Border.all(color: AppColors.danger.withAlpha(80)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off, color: AppColors.danger, size: 32),
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loadHomeData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                    ),
                  ),
                ],
              ),
            ),

          // Play button — disabled when quota exhausted
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: quotaExhausted
                    ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade300])
                    : const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: quotaExhausted
                    ? []
                    : [BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 20, offset: const Offset(0, 6))],
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

          // Action row: History, Tournaments, Premium, Invite
          Row(
            children: [
              Expanded(child: _actionButton('📜', 'History', () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => MatchHistoryScreen(currentUserId: gameState.userId ?? ''),
                ));
              })),
              const SizedBox(width: 8),
              Expanded(child: _actionButton('🏆', 'Tourneys', () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => TournamentScreen(currentPlan: _homeData?.profile.plan ?? 'free'),
                ));
              })),
              const SizedBox(width: 8),
              Expanded(child: _actionButton('👑', 'Premium', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()));
              })),
            ],
          ),
          const SizedBox(height: 16),

          // Premium upsell card (free users only)
          if (!isPremium && _homeData != null) ...[
            _buildUpsellCard(),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLeaderboardHeader() {
    return Row(
      children: [
        const Icon(Icons.leaderboard, color: AppColors.gold, size: 20),
        const SizedBox(width: 8),
        const Text('Top Players', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _currentTab = 1),
          child: Text('See all', style: TextStyle(color: AppColors.accent.withAlpha(200), fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  /// Standard-sized shimmer block used for home/leaderboard card skeletons.
  Widget _skeletonTile({required double height, EdgeInsets? margin}) {
    return SkeletonBlock(
      height: height,
      borderRadius: AppRadius.card,
      margin: margin ?? EdgeInsets.zero,
    );
  }

  /// Illustrated empty state for when the leaderboard has no entries.
  /// Shared by the home preview and the full leaderboard tab.
  Widget _buildLeaderboardEmpty() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.goldBg,
            border: Border.all(color: AppColors.gold.withAlpha(60)),
          ),
          child: const Icon(Icons.emoji_events, size: 40, color: AppColors.gold),
        ),
        const SizedBox(height: 14),
        const Text(
          'No scores yet',
          style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Play your first match to claim the top spot.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: () => ref.read(gameStateProvider.notifier).navigateToMatchmaking(),
          icon: const Icon(Icons.bolt, size: 18),
          label: const Text('Start battle'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Leaderboard tab
  // ---------------------------------------------------------------------------

  Widget _buildLeaderboardTab() {
    // Load leaderboard on first visit
    if (_lbEntries == null && !_lbLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLeaderboard());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              const Icon(Icons.leaderboard, color: AppColors.gold, size: 28),
              const SizedBox(width: 10),
              const Text('Leaderboard', style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        // Time filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              _filterChip('Daily', 'daily'),
              const SizedBox(width: 8),
              _filterChip('Weekly', 'weekly'),
              const SizedBox(width: 8),
              _filterChip('All Time', 'alltime'),
            ],
          ),
        ),
        if (_lbLoading)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (int i = 0; i < 8; i++)
                  _skeletonTile(height: 52, margin: const EdgeInsets.only(bottom: 8)),
              ],
            ),
          ),
        if (!_lbLoading && _lbEntries != null && _lbEntries!.isNotEmpty)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: appCardDecoration(),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _lbEntries!.length,
                  itemBuilder: (_, i) => _leaderboardRow(_lbEntries![i], showBorder: i < _lbEntries!.length - 1),
                ),
              ),
            ),
          ),
        if (!_lbLoading && (_lbEntries == null || _lbEntries!.isEmpty))
          Expanded(
            child: Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: _buildLeaderboardEmpty(),
            )),
          ),
        // Upsell for free users
        if ((_homeData?.profile.plan ?? 'free') != 'premium' && !_lbLoading && _lbEntries != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.goldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withAlpha(60)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_open, color: AppColors.gold, size: 16),
                    SizedBox(width: 8),
                    Text('Upgrade to see the full leaderboard', style: TextStyle(color: AppColors.goldDeep, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _lbFilter == value;
    return GestureDetector(
      onTap: () => _loadLeaderboard(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentBg : AppColors.cardTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? AppColors.accent : AppColors.textMuted,
          fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile tab
  // ---------------------------------------------------------------------------

  Widget _buildProfileTab(AuthService auth, GameState gameState) {
    return RefreshIndicator(
      onRefresh: _loadHomeData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Profile', style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          _buildProfileCard(auth, gameState),
          const SizedBox(height: 24),

          // Streak calendar (30-day history, derived from StreakInfo).
          if (_homeData != null && _homeData!.profile.streak.current > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: appCardDecoration(),
              child: StreakCalendar(
                currentStreak: _homeData!.profile.streak.current,
                lastClaimedDate: _homeData!.profile.streak.lastClaimedDate,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Guest email-link prompt
          if (gameState.isGuest) ...[
            _buildLinkEmailPrompt(),
            const SizedBox(height: 16),
          ],

          // Info rows
          if (auth.email != null && auth.email!.isNotEmpty)
            _profileInfoRow(Icons.email, 'Email', auth.email!),
          const SizedBox(height: 16),

          // Actions
          _profileActionButton(Icons.history, 'Match History', () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => MatchHistoryScreen(currentUserId: gameState.userId ?? ''),
            ));
          }),
          const SizedBox(height: 8),
          _profileActionButton(Icons.storefront, 'Coin Shop', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
          }, color: AppColors.primary),
          const SizedBox(height: 8),
          _profileActionButton(Icons.workspace_premium, 'Premium', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()));
          }, color: AppColors.gold),
          const SizedBox(height: 8),
          _profileActionButton(Icons.share, 'Invite Friends', () {
            _showShareDialog(gameState);
          }),
          const SizedBox(height: 8),
          _profileActionButton(Icons.card_giftcard, 'Your Referrals', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralScreen()));
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
                style: TextButton.styleFrom(foregroundColor: AppColors.textDim),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () => _confirmDeleteAccount(auth),
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text('Delete Account'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger.withAlpha(180)),
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
      decoration: appCardDecoration(),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Text(value, style: const TextStyle(color: AppColors.text, fontSize: 14)),
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
          foregroundColor: color ?? AppColors.textSecondary,
          side: BorderSide(color: AppColors.border),
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

  Widget _actionButton(String emoji, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: appCardDecoration(),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkEmailPrompt() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.secondary.withAlpha(60)),
        color: AppColors.cyanBg,
      ),
      child: Row(
        children: [
          const Icon(Icons.email_outlined, color: AppColors.secondary, size: 26),
          const SizedBox(width: 12),
          const Expanded(child: Text('Link your email to save progress', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          ElevatedButton(
            onPressed: () => showModalBottomSheet(
              context: context, isScrollControlled: true,
              backgroundColor: Colors.transparent, builder: (_) => const LinkEmailScreen(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary, foregroundColor: Colors.white,
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
    final shareText = 'Join me on Quiz Battle! Use my referral code $code when signing up — we both earn coins. https://quizbattle.app';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Invite Friends',
              style: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.orangeBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(80)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(code, style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppColors.textMuted, size: 20),
                    tooltip: 'Copy code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      showAnimatedToast(context, message: 'Code copied!');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Friends get 50 coins, you get 100 coins when they complete their first quiz!',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Share.share(shareText, subject: 'Join me on Quiz Battle');
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount(AuthService auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Account?', style: TextStyle(color: AppColors.text)),
        content: const Text('This will permanently delete your account and all progress.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.deleteAccount();
              if (mounted) ref.read(gameStateProvider.notifier).logout();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
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
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.primarySoft, AppColors.gold]),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.surface,
              child: profile?.avatarUrl.isNotEmpty == true
                  ? ClipOval(child: Image.network(profile!.avatarUrl, width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => Text(initial, style: const TextStyle(color: AppColors.accent, fontSize: 22, fontWeight: FontWeight.bold))))
                  : Text(initial, style: const TextStyle(color: AppColors.accent, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(name, style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    if (gameState.isGuest) ...[
                      const SizedBox(width: 8),
                      _badge('Guest', AppColors.secondary),
                    ],
                    if (plan == 'premium') ...[
                      const SizedBox(width: 8),
                      _badge('PRO', AppColors.gold),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppColors.gold),
                    const SizedBox(width: 3),
                    Text('${profile?.rating ?? gameState.rating}', style: const TextStyle(color: AppColors.goldDeep, fontSize: 13, fontWeight: FontWeight.w600)),
                    if (profile != null) ...[
                      const SizedBox(width: 12),
                      Text('${profile.wins}W/${profile.matchesPlayed - profile.wins}L',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      // Seed from profile.coins so we render the cached
                      // value instantly without firing a redundant
                      // GetCoinBalance — the home payload already has it.
                      // The provider is still watched, so any later
                      // invalidation (e.g. after a purchase) refreshes
                      // the chip.
                      CoinBalanceChip(initialBalance: profile.coins.toInt()),
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
        color: color.withAlpha(25), borderRadius: BorderRadius.circular(8),
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
        color: AppColors.orangeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        children: [
          const Icon(Icons.local_fire_department, color: AppColors.primary, size: 28),
          const SizedBox(height: 4),
          Text('${streak?.current ?? 0}', style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w900)),
          const Text('day streak', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
          color: AppColors.cyanBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.secondary.withAlpha(50)),
        ),
        child: Column(
          children: [
            Icon(isPremium ? Icons.all_inclusive : Icons.play_circle_outline, color: AppColors.secondary, size: 28),
            const SizedBox(height: 4),
            Text(isPremium ? 'Unlimited' : '$remaining/$limit',
              style: TextStyle(color: AppColors.text, fontSize: isPremium ? 16 : 22, fontWeight: FontWeight.w900)),
            Text(isPremium ? 'premium' : 'quizzes left', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final profile = _homeData?.profile;
    final winStreak = profile?.winStreak ?? 0;
    final accuracy = profile?.accuracyPercent ?? 0.0;
    // Matches today = quotaUsed = quotaLimit - quotaRemaining
    final matchesToday = (_homeData?.quotaLimit ?? 0) - (_homeData?.quotaRemaining ?? 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: appCardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat(Icons.today, '$matchesToday', 'Today', AppColors.accent, AppColors.accentBg),
          _Stat(Icons.local_fire_department, '$winStreak', 'Win Streak', AppColors.primary, AppColors.orangeBg),
          _Stat(Icons.track_changes, '${accuracy.toStringAsFixed(0)}%', 'Accuracy', AppColors.success, AppColors.emeraldBg),
        ],
      ),
    );
  }

  Widget _buildUpsellCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium, color: AppColors.gold, size: 24),
              SizedBox(width: 10),
              Text('Go Premium', style: TextStyle(color: AppColors.goldDeep, fontSize: 16, fontWeight: FontWeight.bold)),
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
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
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
          Icon(icon, color: AppColors.goldDeep.withAlpha(180), size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _leaderboardRow(LeaderboardEntry e, {bool showBorder = true}) {
    final isMedal = e.rank <= 3;
    const medalColors = [AppColors.medalGold, AppColors.medalSilver, AppColors.medalBronze];
    final color = isMedal ? medalColors[e.rank - 1] : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: showBorder ? const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)) : null,
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('#${e.rank}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14))),
          const SizedBox(width: 8),
          Expanded(child: Row(
            children: [
              Flexible(child: Text(e.username.isEmpty ? e.userId : e.username, style: const TextStyle(color: AppColors.text, fontSize: 14), overflow: TextOverflow.ellipsis)),
              if (e.plan == 'premium') ...[
                const SizedBox(width: 6),
                _badge('PRO', AppColors.gold),
              ],
            ],
          )),
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
  final Color bgColor;
  const _Stat(this.icon, this.value, this.label, this.color, this.bgColor);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
      backgroundColor: AppColors.surface,
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
                    gradient: const LinearGradient(colors: [Color(0xFFF59E0B), AppColors.primary]),
                    boxShadow: [BoxShadow(color: AppColors.gold.withAlpha(60), blurRadius: 30)],
                  ),
                  child: const Icon(Icons.local_fire_department, size: 44, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Day ${widget.streakDay}!', style: const TextStyle(color: AppColors.goldDeep, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('+${widget.coins} coins', style: const TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Keep your streak alive!', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
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
                  backgroundColor: AppColors.gold, foregroundColor: Colors.white,
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
