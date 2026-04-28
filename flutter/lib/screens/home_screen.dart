import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/game_state.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_counter.dart';
import '../widgets/animated_toast.dart';
import '../widgets/coin_balance_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/google_style_avatar.dart';
import '../widgets/local_avatar.dart';
import '../widgets/section_header.dart';
import '../widgets/streak_calendar.dart';
import '../proto/quiz.pbgrpc.dart';
import 'coin_ledger_screen.dart';
import 'shop/equip_screen.dart';
import 'shop/shop_screen.dart';
import 'profile_analytics_screen.dart';
import 'match_history_screen.dart';
import 'payment_screen.dart';
import 'profile/edit_profile_screen.dart';
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

  /// Pushes [PaymentScreen] and refreshes the home payload after it
  /// pops. Without this, a successful Razorpay purchase activates
  /// premium server-side (users.plan flips via the scoring consumer)
  /// but the home tab keeps rendering the stale `_homeData` it loaded
  /// at init — so the upsell card + `0W/0L` ribbon stay visible until
  /// the user manually pulls-to-refresh or restarts the app.
  Future<void> _openPaymentScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentScreen()),
    );
    if (mounted) await _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    // Upfront mounted guard: callers may invoke this after a
    // Navigator.push completes, by which point this screen could have
    // been disposed (e.g. logout fired during the push). Without the
    // guard, the synchronous setState below crashes with "setState
    // called after dispose."
    if (!mounted) return;
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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: _buildTabContent(auth, gameState),
      ),
      bottomNavigationBar: _SpeakXBottomNav(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
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
      _openPaymentScreen();
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
          // Personalised top bar (greeting + coin capsule + settings).
          // Mirrors the reference's "Good morning, Name" pattern instead
          // of the prior gradient-shader brand title — friendlier
          // session-start framing.
          _buildTopBar(auth, gameState).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 20),

          // Profile card
          _buildProfileCard(auth, gameState)
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 16),

          // Guest email-link prompt
          if (gameState.isGuest)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildLinkEmailPrompt(),
            ),

          // Streak + Quota row — either loaded cards or skeletons while fetching.
          if (_homeData != null) ...[
            const SectionHeader(
              title: 'Today',
              icon: Icons.today_rounded,
              iconColor: AppColors.primary,
            )
                .animate()
                .fadeIn(delay: 150.ms, duration: 300.ms),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildStreakCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildQuotaCard()),
              ],
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Your stats',
              icon: Icons.insights_rounded,
              iconColor: AppColors.accent,
            )
                .animate()
                .fadeIn(delay: 250.ms, duration: 300.ms),
            const SizedBox(height: 8),
            _buildStatsRow().animate().fadeIn(delay: 300.ms, duration: 400.ms),
            const SizedBox(height: 24),
            // Day-0 nudge: only fires when the user has never played a match.
            // Once they have at least one match the existing stats card and
            // history surfaces are informative enough — no need for a CTA.
            if ((_homeData?.profile.matchesPlayed ?? 0) == 0) ...[
              _buildDayZeroCard().animate().fadeIn(delay: 350.ms, duration: 400.ms),
              const SizedBox(height: 24),
            ],
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

          // Play button — disabled (and CTA flips) when daily quota is exhausted.
          // Coral gradient pill matching the reference's primary action style;
          // soft shadow grounds it against the dark scaffold.
          SizedBox(
            width: double.infinity,
            height: 60,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: quotaExhausted
                    ? const LinearGradient(
                        // Muted dark surface gradient via tokens —
                        // signals "disabled" without competing with
                        // the live coral gradient on the active path.
                        colors: [AppColors.border, AppColors.cardTint],
                      )
                    : AppGradients.primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: quotaExhausted
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: ElevatedButton.icon(
                onPressed: quotaExhausted
                    ? () {
                        HapticFeedback.lightImpact();
                        _openPaymentScreen();
                      }
                    : () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(gameStateProvider.notifier)
                            .navigateToMatchmaking();
                      },
                icon: Icon(
                  quotaExhausted
                      ? Icons.lock_rounded
                      : Icons.bolt_rounded,
                  size: 26,
                ),
                label: Text(
                  quotaExhausted ? 'UPGRADE TO PLAY' : 'START BATTLE',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 400.ms)
              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
          const SizedBox(height: 16),

          const SectionHeader(
            title: 'Quick actions',
            icon: Icons.bolt_rounded,
            iconColor: AppColors.gold,
          )
              .animate()
              .fadeIn(delay: 480.ms, duration: 300.ms),
          const SizedBox(height: 8),
          // Action row: History, Tournaments, Premium
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
                _openPaymentScreen();
              })),
            ],
          ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
          const SizedBox(height: 16),

          // Premium upsell card (free users only)
          if (!isPremium && _homeData != null) ...[
            _buildUpsellCard()
                .animate()
                .fadeIn(delay: 600.ms, duration: 400.ms)
                .slideY(begin: 0.1, end: 0),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Personalised top bar shown above the profile card on the Home tab.
  /// Greets the user by first-name, surfaces the coin balance as a
  /// tappable gold pill, and exposes a settings/profile gear that
  /// jumps to the Profile tab. Mirrors the reference's `_TopBar`.
  Widget _buildTopBar(AuthService auth, GameState gameState) {
    final profile = _homeData?.profile;
    final username = profile?.username.isNotEmpty == true
        ? profile!.username
        : (auth.username ?? 'Player');
    final firstName = username.split(' ').first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                firstName,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        // Coin capsule — gold pill, tappable to open the lifetime ledger.
        if (profile != null)
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: CoinBalanceChip(
              initialBalance: profile.coins.toInt(),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CoinLedgerScreen()),
              ),
            ),
          ),
        // Settings gear → Profile tab.
        IconButton(
          tooltip: 'Profile',
          onPressed: () => setState(() => _currentTab = 3),
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.settings_rounded,
                color: AppColors.textSecondary, size: 20),
          ),
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
        // Big header with gold trophy + title — entrance animated.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.gold, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leaderboard',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Top players, ranked by score',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),
        // Time filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              _filterChip('Daily', 'daily'),
              const SizedBox(width: 8),
              _filterChip('Weekly', 'weekly'),
              const SizedBox(width: 8),
              _filterChip('All Time', 'alltime'),
            ],
          ),
        ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
        if (_lbLoading)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (int i = 0; i < 8; i++)
                  _skeletonTile(height: 56, margin: const EdgeInsets.only(bottom: 10)),
              ],
            ),
          ),
        if (!_lbLoading && _lbEntries != null && _lbEntries!.isNotEmpty)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              itemCount: _lbEntries!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => Container(
                decoration: appCardDecoration(),
                child: _leaderboardRow(_lbEntries![i], showBorder: false),
              )
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: 30 * (i % 8)),
                    duration: 250.ms,
                  )
                  .slideY(
                    begin: 0.05,
                    end: 0,
                    curve: Curves.easeOutCubic,
                  ),
            ),
          ),
        if (!_lbLoading && (_lbEntries == null || _lbEntries!.isEmpty))
          const Expanded(
            child: EmptyState(
              icon: Icons.emoji_events_rounded,
              iconColor: AppColors.gold,
              title: 'No scores yet',
              body: "Be the first to claim the top spot — play a match and your name will appear here.",
            ),
          ),
        // Upsell for free users
        if ((_homeData?.profile.plan ?? 'free') != 'premium' && !_lbLoading && _lbEntries != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: GestureDetector(
              onTap: () => _openPaymentScreen(),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _loadLeaderboard(value),
        borderRadius: BorderRadius.circular(999),
        splashColor: AppColors.primary.withValues(alpha: 0.15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.textMuted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
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
          const Text(
            'Profile',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          _buildProfileCard(auth, gameState),
          const SizedBox(height: 18),

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
            const SizedBox(height: 18),
          ],

          // Guest email-link prompt
          if (gameState.isGuest) ...[
            _buildLinkEmailPrompt(),
            const SizedBox(height: 18),
          ],

          // ── Account section ─────────────────────────────────────
          const SectionHeader(
            title: 'Account',
            icon: Icons.person_rounded,
            iconColor: AppColors.accent,
          ),
          const SizedBox(height: 8),
          if (auth.email != null && auth.email!.isNotEmpty) ...[
            _profileInfoRow(Icons.email_rounded, 'Email', auth.email!),
            const SizedBox(height: 8),
          ],
          _profileTileGroup([
            _ProfileTile(
              icon: Icons.edit_rounded,
              label: 'Edit Profile',
              color: AppColors.accent,
              onTap: () async {
                final profile = _homeData?.profile;
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                      displayName:
                          profile?.displayName ?? auth.username ?? '',
                      avatarUrl: profile?.avatarUrl ?? '',
                      preferredTopics:
                          profile?.preferredTopics.toList() ?? <String>[],
                    ),
                  ),
                );
                // Mounted guard mirrors the pattern in
                // _openPaymentScreen (line 56): the screen could have
                // been disposed during the EditProfile push (logout
                // race). _loadHomeData itself also guards, but
                // checking here keeps the await chain explicit.
                if (saved == true && context.mounted) {
                  await _loadHomeData();
                }
              },
            ),
          ]),
          const SizedBox(height: 18),

          // ── Game section ──────────────────────────────────────
          const SectionHeader(
            title: 'Game',
            icon: Icons.bolt_rounded,
            iconColor: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _profileTileGroup([
            _ProfileTile(
              icon: Icons.history_rounded,
              label: 'Match History',
              color: AppColors.secondary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MatchHistoryScreen(
                      currentUserId: gameState.userId ?? ''),
                ),
              ),
            ),
            _ProfileTile(
              icon: Icons.insights_rounded,
              label: 'Stats & Recap',
              color: AppColors.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfileAnalyticsScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 18),

          // ── Premium / Shop section ────────────────────────────
          const SectionHeader(
            title: 'Coins & Premium',
            icon: Icons.workspace_premium_rounded,
            iconColor: AppColors.gold,
          ),
          const SizedBox(height: 8),
          _profileTileGroup([
            _ProfileTile(
              icon: Icons.storefront_rounded,
              label: 'Coin Shop',
              color: AppColors.primary,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ShopScreen())),
            ),
            _ProfileTile(
              icon: Icons.checkroom_rounded,
              label: 'Equip Cosmetics',
              color: AppColors.accent,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EquipScreen())),
            ),
            _ProfileTile(
              icon: Icons.workspace_premium_rounded,
              label: 'Premium',
              color: AppColors.gold,
              trailingBadge: ((_homeData?.profile.plan ?? 'free') == 'premium')
                  ? 'PRO'
                  : null,
              onTap: () => _openPaymentScreen(),
            ),
          ]),
          const SizedBox(height: 18),

          // ── Social section ────────────────────────────────────
          const SectionHeader(
            title: 'Social',
            icon: Icons.group_rounded,
            iconColor: AppColors.success,
          ),
          const SizedBox(height: 8),
          _profileTileGroup([
            _ProfileTile(
              icon: Icons.share_rounded,
              label: 'Invite Friends',
              color: AppColors.success,
              onTap: () => _showShareDialog(gameState),
            ),
            _ProfileTile(
              icon: Icons.card_giftcard_rounded,
              label: 'Your Referrals',
              color: AppColors.gold,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReferralScreen())),
            ),
          ]),
          const SizedBox(height: 32),

          // ── Logout + Delete (low-emphasis) ────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    ref.read(gameStateProvider.notifier).logout();
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Logout'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () => _confirmDeleteAccount(auth),
                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                label: const Text('Delete Account'),
                style: TextButton.styleFrom(
                    foregroundColor:
                        AppColors.danger.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Wraps a list of [_ProfileTile]s in a single rounded card with
  /// inner dividers — the SpeakX "settings group" pattern.
  Widget _profileTileGroup(List<_ProfileTile> tiles) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      children.add(tiles[i]);
      if (i < tiles.length - 1) {
        children.add(const Divider(
          color: AppColors.border,
          height: 1,
          indent: 56,
        ));
      }
    }
    return Container(
      decoration: appCardDecoration(),
      child: Column(children: children),
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

  // _profileActionButton was removed — superseded by the grouped
  // _ProfileTile pattern below, which folds tiles into a single
  // rounded card with inner dividers (SpeakX "settings group" style).

  // ---------------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------------

  Widget _actionButton(String emoji, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        splashColor: AppColors.primary.withValues(alpha: 0.15),
        highlightColor: AppColors.primary.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: appCardDecoration(),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cardTint,
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
    // Resolve to a local emoji preset when the saved URL matches one
    // of the onboarding presets — gives consistent visuals across the
    // setup picker and the home card without depending on network.
    final preset = profile?.avatarUrl.isNotEmpty == true
        ? presetFromAvatarUrl(profile!.avatarUrl)
        : null;

    final losses = profile != null
        ? (profile.matchesPlayed - profile.wins).toInt()
        : 0;
    final rating = profile?.rating ?? gameState.rating;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, Color(0xFF22223C)],
        ),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with a coral→gold conic ring — strong personalisation
          // anchor matching the reference's profile-card avatar.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.gold],
              ),
            ),
            // Three render paths, in priority order:
            //   1. Onboarding-preset emoji glyph → LocalAvatar
            //   2. Network photo (Google sign-in, future bucket
            //      uploads) — GoogleStyleAvatar shows the photo when
            //      it loads, and an initial-on-color fallback while
            //      it loads or if it errors out.
            //   3. No URL at all → GoogleStyleAvatar's deterministic
            //      colored-initial circle. Looks intentional — same
            //      affordance Gmail / Calendar / GitHub use for
            //      photo-less users.
            child: preset != null
                ? LocalAvatar(
                    glyph: preset.glyph,
                    background: preset.color,
                    size: 56,
                  )
                : GoogleStyleAvatar(
                    name: name,
                    imageUrl: profile?.avatarUrl,
                    size: 56,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                const SizedBox(height: 8),
                // Rating + W/L record chip cluster.
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _recordPill(
                      icon: Icons.star_rounded,
                      iconColor: AppColors.gold,
                      label: '$rating',
                      tint: AppColors.goldBg,
                    ),
                    if (profile != null)
                      _recordPill(
                        icon: Icons.emoji_events_rounded,
                        iconColor: AppColors.primary,
                        label: '${profile.wins}W / ${losses}L',
                        tint: AppColors.orangeBg,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact pill rendering an icon + value, used by the profile card's
  /// rating and record indicators. Tinted bg + border keeps it visually
  /// distinct without competing with the main accent.
  Widget _recordPill({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: iconColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
      onTap: isPremium ? null : () => _openPaymentScreen(),
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
          _Stat(Icons.today_rounded, matchesToday, 'Today', AppColors.accent, AppColors.accentBg),
          _Stat(Icons.local_fire_department_rounded, winStreak, 'Win Streak', AppColors.primary, AppColors.orangeBg),
          _Stat(Icons.track_changes_rounded, accuracy.round(), 'Accuracy', AppColors.success, AppColors.emeraldBg, suffix: '%'),
        ],
      ),
    );
  }

  /// Day-0 empty state — shown to users who haven't played their first
  /// match yet. Friendly nudge with a primary CTA that drops them straight
  /// into matchmaking, since there's no win-rate / streak / history to
  /// surface yet.
  Widget _buildDayZeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.orangeBg, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orangeBg,
                ),
                child: const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ready for your first match?',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Best-of-5 quiz battles, ~2 minutes per match. Win to climb the rating ladder.",
            style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: AppRadius.button,
              ),
              child: ElevatedButton.icon(
                onPressed: () => ref.read(gameStateProvider.notifier).navigateToMatchmaking(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text(
                  'Play your first match',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
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
              onPressed: () => _openPaymentScreen(),
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

/// Single stat tile — circular tinted icon + animated numeric value
/// + label. Uses [AnimatedCounter] so when [value] changes (e.g. on
/// pull-to-refresh after a match) the number rolls up rather than
/// snapping. The optional [suffix] keeps "%" attached for the
/// accuracy variant.
class _Stat extends StatelessWidget {
  final IconData icon;
  final num value;
  final String label;
  final Color color;
  final Color bgColor;
  final String suffix;
  const _Stat(
    this.icon,
    this.value,
    this.label,
    this.color,
    this.bgColor, {
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 6),
        AnimatedCounter(
          value: value,
          suffix: suffix,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// _ProfileTile — single row inside a [_profileTileGroup] card.
/// Tinted-icon badge on the left, label + optional badge in the
/// middle, chevron on the right. InkWell ripple gives the tactile
/// "tap landed" feedback that bare GestureDetector lacks.
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? trailingBadge;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailingBadge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trailingBadge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
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


// ═══════════════════════════════════════════════════════════════════════════
// SpeakX-style bottom navigation
// ═══════════════════════════════════════════════════════════════════════════
//
// Custom over Material's BottomNavigationBar because we want:
//  - A coral pill INDICATOR sliding under the active tab (SpeakX pattern)
//  - Larger touch targets (56px vs Material's default ~52px)
//  - Soft elevation rather than the default 8-elevation drop-shadow line
//  - Animated scale on the active icon for tactile feedback

class _SpeakXBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _SpeakXBottomNav({required this.currentIndex, required this.onTap});

  static const _items = <_NavSpec>[
    _NavSpec(icon: Icons.home_rounded, label: 'Home'),
    _NavSpec(icon: Icons.bolt_rounded, label: 'Play'),
    _NavSpec(icon: Icons.leaderboard_rounded, label: 'Ranks'),
    _NavSpec(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgNav,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + (bottomInset > 0 ? 0 : 4)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final spec = _items[i];
              final selected = i == currentIndex;
              return Expanded(
                child: _NavItem(
                  spec: spec,
                  selected: selected,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  final IconData icon;
  final String label;
  const _NavSpec({required this.icon, required this.label});
}

class _NavItem extends StatelessWidget {
  final _NavSpec spec;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              scale: selected ? 1.1 : 1.0,
              child: Icon(
                spec.icon,
                color: selected ? AppColors.primary : AppColors.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textMuted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              child: Text(spec.label),
            ),
          ],
        ),
      ),
    );
  }
}
