// profile_screen.dart — revamped profile screen with hero + 5 sticky tabs.
//
// Structure (driven by the design brief):
//   • Top app-bar row (back / restore / logout)  — over the hero
//   • Profile hero — avatar + identity + chips, dark backdrop, coral glow
//   • Sticky tab bar — PROFIL · LAST M · BADGES · STREAK · REFERR
//   • Tab body
//
// PROFIL tab also preserves every "management" affordance the old
// _buildProfileTab in home_screen.dart used to render — Edit Profile,
// Match History, Stats & Recap, Coin Shop, Equip Cosmetics, Premium,
// Friends, Invite, Referrals, Logout, Delete Account. Nothing the user
// could do before is missing now; it's just placed under the new
// rating/stats/streaks block.
//
// Data wiring:
//   • Profile fields, rating, streak, plan, coins, referral code:
//       passed in via [homeData] from the host (home_screen.dart owns
//       this gRPC response).
//   • Friend pending-request badge: friendRequestsCountProvider.
//   • Match history: fetched on-tab-open via QuizService.getMatchHistory.
//   • Referral dashboard: fetched on-tab-open via getReferralDashboard.
//   • Apply referral code: QuizService.applyReferralCode (existing RPC).
//   • Claim daily reward: AuthService.claimDailyReward.
//   • Logout / delete: AuthService methods, with parent callbacks where
//     state cleanup belongs to the host (clearing GameStateNotifier etc.).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/friends_state.dart';
import '../proto/quiz.pbgrpc.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/google_style_avatar.dart';
import '../widgets/pill_chip.dart';
import '../widgets/progress_bar.dart';
import '../widgets/stat_cell.dart';
import 'coin_ledger_screen.dart';
import 'friends_screen.dart';
import 'link_email_screen.dart';
import 'match_history_screen.dart';
import 'profile/edit_profile_screen.dart';
import 'profile_analytics_screen.dart';
import 'referral_screen.dart';
import 'shop/equip_screen.dart';
import 'shop/shop_screen.dart';

// ─────────────────────────────────────────────────────────────────────
// Helper data classes (badges, tier mapping)
// ─────────────────────────────────────────────────────────────────────

class _Badge {
  final String id;
  final String name;
  final IconData icon;
  final Color accent;
  final String unlockCondition;
  final bool legendary;
  final bool comingSoon;
  const _Badge({
    required this.id,
    required this.name,
    required this.icon,
    required this.accent,
    required this.unlockCondition,
    this.legendary = false,
    this.comingSoon = false,
  });
  String get displayCondition => comingSoon ? 'Coming soon' : unlockCondition;
}

// Tier name → pill color. Lifted from the design brief's tier mapping.
Color _tierColor(String tier) {
  switch (tier.toUpperCase()) {
    case 'BEGINNER':
      return AppColors.textMuted;
    case 'INTERMEDIATE':
      return AppColors.success;
    case 'ADVANCED':
      return AppColors.info;
    case 'EXPERT':
      return AppColors.primary;
    case 'MASTER':
      return AppColors.gold;
    default:
      return AppColors.textMuted;
  }
}

// Rating → tier. Thresholds match what the home screen + leaderboard
// already use (1000 beginner / 1500 intermediate / 2000 advanced /
// 2500 expert / 3000+ master). If the actual product spec drifts,
// tweak here and everywhere else converges.
String _tierForRating(int rating) {
  if (rating >= 3000) return 'MASTER';
  if (rating >= 2500) return 'EXPERT';
  if (rating >= 2000) return 'ADVANCED';
  if (rating >= 1500) return 'INTERMEDIATE';
  return 'BEGINNER';
}

// ─────────────────────────────────────────────────────────────────────
// ProfileScreen
// ─────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  /// Live home-screen response from the host; null while loading.
  final GetHomeScreenDataResponse? homeData;

  /// AuthService instance (a singleton, but we accept it to avoid a
  /// global lookup inside this screen).
  final AuthService auth;

  /// Triggered by RefreshIndicator / restore button — the host owns
  /// the gRPC home-data fetch.
  final Future<void> Function() onRefresh;

  /// Switches the host's bottom-nav to the Play tab. Used by the
  /// LAST M empty-state CTA and by hero quick-actions if relevant.
  final VoidCallback? onSwitchToPlayTab;

  /// Opens the payment / premium flow on the host.
  final VoidCallback? onOpenPayment;

  /// Triggers the host's share-invite dialog (uses the system share
  /// sheet via share_plus, which lives in the host already).
  final VoidCallback? onShareInvite;

  /// Final logout callback — the host clears its own state (game
  /// notifier, FCM listeners) before navigating to login.
  final Future<void> Function() onLogout;

  /// Delete-account callback — the host handles the danger dialog +
  /// the actual RPC because it also has to clear local app state.
  final VoidCallback onDeleteAccountRequested;

  /// Back-button callback. When provided, the top-bar back arrow fires
  /// this instead of `Navigator.maybePop`. Use this when ProfileScreen
  /// is rendered as a tab inside a host Scaffold (where there's no
  /// route to pop) — typically wired to "switch the host's bottom-nav
  /// back to Home". When null, the back arrow is hidden if there's no
  /// navigator route to pop, so the user never sees an inert affordance.
  final VoidCallback? onBack;

  const ProfileScreen({
    super.key,
    required this.homeData,
    required this.auth,
    required this.onRefresh,
    required this.onLogout,
    required this.onDeleteAccountRequested,
    this.onSwitchToPlayTab,
    this.onOpenPayment,
    this.onShareInvite,
    this.onBack,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Lazy-fetched per-tab data. Kept as state (not provider) so the
  // screen owns its lifecycle and the parent stays out of it.
  Future<GetMatchHistoryResponse>? _matchesFuture;
  Future<GetReferralDashboardResponse>? _referralFuture;

  // Apply-code form state.
  final TextEditingController _codeCtrl = TextEditingController();
  bool _applying = false;
  String? _applyError;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _tab.addListener(_onTabChanged);
    _codeCtrl.addListener(_onCodeCtrlChanged);
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    _codeCtrl.removeListener(_onCodeCtrlChanged);
    _codeCtrl.dispose();
    super.dispose();
  }

  // Rebuild on every keystroke so the Apply button's `onPressed`
  // gate re-evaluates when text crosses the 6-char threshold.
  void _onCodeCtrlChanged() {
    if (!mounted) return;
    setState(() => _applyError = null);
  }

  void _onTabChanged() {
    if (!_tab.indexIsChanging) return;
    HapticFeedback.selectionClick();
    // Kick off per-tab fetches the first time their tab is opened.
    final i = _tab.index;
    if (i == 1) _matchesFuture ??= QuizService().getMatchHistory(limit: 20);
    if (i == 4) _referralFuture ??= QuizService().getReferralDashboard();
  }

  Future<void> _handleRefresh() async {
    // Refresh BOTH the host's home data AND any tab-local futures so
    // a pull-to-refresh on any tab pulls fresh content everywhere.
    final tasks = <Future<void>>[widget.onRefresh()];
    if (_matchesFuture != null) {
      _matchesFuture = QuizService().getMatchHistory(limit: 20);
      tasks.add(_matchesFuture!.then((_) => null));
    }
    if (_referralFuture != null) {
      _referralFuture = QuizService().getReferralDashboard();
      tasks.add(_referralFuture!.then((_) => null));
    }
    if (mounted) setState(() {});
    await Future.wait(tasks);
  }

  // ───────────────────────────────────────────────────────────────
  // Top-level scaffold
  // ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profile = widget.homeData?.profile;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildHeaderSliver(profile),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(_tab),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: _handleRefresh,
              child: _buildProfilTab(profile),
            ),
            RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: _handleRefresh,
              child: _buildLastMatchesTab(),
            ),
            RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: _handleRefresh,
              child: _buildBadgesTab(profile),
            ),
            RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: _handleRefresh,
              child: _buildStreakTab(profile),
            ),
            RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: _handleRefresh,
              child: _buildReferrTab(profile),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Header sliver: app-bar row + hero
  // ───────────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildHeaderSliver(UserProfile? profile) {
    return SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative coral glow in the top-right corner.
          Positioned(
            top: -80,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              _buildTopBar(),
              _buildHero(profile),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    // Back-button visibility rules:
    //   • If the host supplied [onBack] (tab-content case), show the
    //     arrow and call onBack — the host switches its bottom-nav
    //     back to Home.
    //   • Else if there's a route to pop (standalone push case),
    //     show the arrow and call Navigator.pop.
    //   • Else (no host hook, no route): hide the arrow entirely.
    //     The previous implementation called Navigator.maybePop which
    //     silently does nothing — a visible button that doesn't
    //     respond is worse than no button.
    final canGoBack = widget.onBack != null || Navigator.canPop(context);
    final onBackPressed = widget.onBack ?? () => Navigator.pop(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xs, Spacing.xs, Spacing.xs, 0),
        child: Row(
          children: [
            if (canGoBack)
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: AppColors.text,
                onPressed: onBackPressed,
              )
            else
              // Preserve the row's vertical metrics when the back
              // button is hidden so the right-side icons don't jump
              // up into the safe area.
              const SizedBox(width: 48, height: 48),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh profile',
              icon: const Icon(Icons.restore, size: 22),
              color: AppColors.textMuted,
              onPressed: () async {
                await _handleRefresh();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile refreshed'),
                    duration: Duration(milliseconds: 1200),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout, size: 22),
              color: AppColors.textMuted,
              onPressed: _confirmLogout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(UserProfile? profile) {
    final username = profile?.username.isNotEmpty == true
        ? profile!.username
        : (widget.auth.username ?? '');
    final displayName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : username;
    final avatarUrl = profile?.avatarUrl ?? '';
    final rating = profile?.rating ?? 1200;
    final played = profile?.matchesPlayed ?? 0;
    final wins = profile?.wins ?? 0;
    final winRate = played == 0 ? 0 : ((wins / played) * 100).round();
    final isPro = (profile?.plan ?? 'free') == 'premium';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.lg,
        Spacing.xl,
        Spacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GoogleStyleAvatar(
            name: displayName,
            imageUrl: avatarUrl,
            size: 92,
            borderColor: isPro ? AppColors.gold : AppColors.primary,
            borderWidth: 2,
            glow: true,
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: AppText.h1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    // Online dot (this user is the local user, always
                    // considered "online" while they're in the app).
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                    ),
                    if (isPro) ...[
                      const SizedBox(width: Spacing.sm),
                      const PillChip(
                        label: 'PRO',
                        color: AppColors.gold,
                        variant: PillVariant.solid,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Spacing.xs),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 18, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Text(
                      '$rating Rating',
                      style: AppText.bodyLg.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.xs,
                  children: [
                    PillChip(
                      label: '$played played',
                      icon: Icons.sports_esports,
                      color: AppColors.primary,
                      variant: PillVariant.soft,
                    ),
                    PillChip(
                      label: '$winRate% win rate',
                      icon: Icons.emoji_events,
                      color: AppColors.gold,
                      variant: PillVariant.soft,
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

  // ───────────────────────────────────────────────────────────────
  // PROFIL tab
  // ───────────────────────────────────────────────────────────────

  Widget _buildProfilTab(UserProfile? profile) {
    final rating = profile?.rating ?? 1200;
    final played = profile?.matchesPlayed ?? 0;
    final wins = profile?.wins ?? 0;
    final losses = math.max(0, played - wins);
    final winRate = played == 0 ? 0.0 : wins / played;
    final tier = _tierForRating(rating);
    final tierColor = _tierColor(tier);

    final streak = profile?.streak;
    final dailyStreak = streak?.current ?? 0;
    final bestStreak = streak?.longest ?? 0;
    final winStreak = profile?.winStreak ?? 0;
    final email = profile?.email.isNotEmpty == true
        ? profile!.email
        : (widget.auth.email ?? '');

    return ListView(
      // AlwaysScrollableScrollPhysics so the parent RefreshIndicator
      // fires even when the tab content fits within the viewport —
      // standard NestedScrollView + RefreshIndicator pattern. Without
      // this, pull-to-refresh only works once the list overflows.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.lg,
        Spacing.xl,
        Spacing.xxxl,
      ),
      children: [
        // Current Rating card
        AppCard(
          gradientTint: tierColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: Spacing.md),
                child: Icon(Icons.star_rounded,
                    size: 44, color: AppColors.gold),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.toString(),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current Rating',
                      style: AppText.body
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              PillChip(
                label: tier,
                color: tierColor,
                variant: PillVariant.outlined,
              ),
            ],
          ),
        ),

        // ── Match Stats ───────────────────────────────────────────
        _sectionHeader('Match Stats'),
        Row(
          children: [
            Expanded(
              child: StatCell(
                icon: Icons.sports_esports,
                iconColor: AppColors.primary,
                value: played.toString(),
                label: 'Played',
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: StatCell(
                icon: Icons.emoji_events,
                iconColor: AppColors.success,
                value: wins.toString(),
                label: 'Won',
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: StatCell(
                icon: Icons.close,
                iconColor: AppColors.danger,
                value: losses.toString(),
                label: 'Lost',
              ),
            ),
          ],
        ),

        const SizedBox(height: Spacing.lg),

        // Win Rate
        Row(
          children: [
            Text('Win Rate',
                style: AppText.body.copyWith(color: AppColors.textMuted)),
            const Spacer(),
            Text(
              '${(winRate * 100).round()}%',
              style: AppText.body.copyWith(
                color: winRate >= 0.5 ? AppColors.success : AppColors.primary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        ProgressBar(
          value: winRate,
          color: winRate >= 0.5 ? AppColors.success : AppColors.primary,
        ),

        // ── Streaks ───────────────────────────────────────────────
        _sectionHeader('Streaks'),
        Row(
          children: [
            Expanded(
              child: StatCell(
                icon: Icons.local_fire_department,
                iconColor: AppColors.flame,
                value: dailyStreak.toString(),
                label: 'Daily Streak',
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: StatCell(
                icon: Icons.local_fire_department_outlined,
                iconColor: AppColors.gold,
                value: bestStreak.toString(),
                label: 'Best',
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: StatCell(
                icon: Icons.bolt,
                iconColor: AppColors.primary,
                value: winStreak.toString(),
                label: 'Win Streak',
              ),
            ),
          ],
        ),

        // ── Management sections (carried over from the previous
        //    home-screen profile tab — none of these affordances
        //    are mentioned in the brief but they're load-bearing
        //    for the product so they live here at the bottom of
        //    the PROFIL tab) ─────────────────────────────────────
        _sectionHeader('Account'),
        if (email.isNotEmpty) _infoRow(Icons.email_rounded, 'Email', email),
        if (email.isNotEmpty) const SizedBox(height: Spacing.sm),
        _tileGroup([
          _ManagementTile(
            icon: Icons.edit_rounded,
            label: 'Edit Profile',
            color: AppColors.accent,
            onTap: _openEditProfile,
          ),
          if (widget.homeData?.profile.isGuest ?? false)
            _ManagementTile(
              icon: Icons.email_rounded,
              label: 'Link Email to your account',
              color: AppColors.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LinkEmailScreen(),
                ),
              ),
            ),
        ]),

        _sectionHeader('Game'),
        _tileGroup([
          _ManagementTile(
            icon: Icons.history_rounded,
            label: 'Match History',
            color: AppColors.secondary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MatchHistoryScreen(
                  currentUserId: widget.auth.userId ?? '',
                ),
              ),
            ),
          ),
          _ManagementTile(
            icon: Icons.insights_rounded,
            label: 'Stats & Recap',
            color: AppColors.accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfileAnalyticsScreen(),
              ),
            ),
          ),
          _ManagementTile(
            icon: Icons.receipt_long_rounded,
            label: 'Coin History',
            color: AppColors.gold,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CoinLedgerScreen(),
              ),
            ),
          ),
        ]),

        _sectionHeader('Coins & Premium'),
        _tileGroup([
          _ManagementTile(
            icon: Icons.storefront_rounded,
            label: 'Coin Shop',
            color: AppColors.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShopScreen()),
            ),
          ),
          _ManagementTile(
            icon: Icons.checkroom_rounded,
            label: 'Equip Cosmetics',
            color: AppColors.accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EquipScreen()),
            ),
          ),
          _ManagementTile(
            icon: Icons.workspace_premium_rounded,
            label: 'Premium',
            color: AppColors.gold,
            trailingBadge:
                ((widget.homeData?.profile.plan ?? 'free') == 'premium')
                    ? 'PRO'
                    : null,
            onTap: () => widget.onOpenPayment?.call(),
          ),
        ]),

        _sectionHeader('Social'),
        Consumer(
          builder: (ctx, ref, _) {
            final pendingCount = ref.watch(friendRequestsCountProvider);
            return _tileGroup([
              _ManagementTile(
                icon: Icons.group_rounded,
                label: 'Friends',
                color: AppColors.primary,
                trailingBadge: pendingCount > 0 ? '$pendingCount' : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FriendsScreen(),
                  ),
                ),
              ),
              _ManagementTile(
                icon: Icons.share_rounded,
                label: 'Invite Friends',
                color: AppColors.success,
                onTap: () => widget.onShareInvite?.call(),
              ),
              _ManagementTile(
                icon: Icons.card_giftcard_rounded,
                label: 'Your Referrals',
                color: AppColors.gold,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReferralScreen(),
                  ),
                ),
              ),
            ]);
          },
        ),

        const SizedBox(height: Spacing.xxl),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Logout'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted),
            ),
            const SizedBox(width: Spacing.lg),
            TextButton.icon(
              onPressed: widget.onDeleteAccountRequested,
              icon: const Icon(Icons.delete_forever_rounded, size: 16),
              label: const Text('Delete Account'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────
  // LAST M tab — match history
  // ───────────────────────────────────────────────────────────────

  Widget _buildLastMatchesTab() {
    _matchesFuture ??= QuizService().getMatchHistory(limit: 20);
    return FutureBuilder<GetMatchHistoryResponse>(
      future: _matchesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _matchesSkeleton();
        }
        if (snapshot.hasError) {
          return _errorState(
            'Couldn\'t load match history',
            snapshot.error.toString(),
            () => setState(
                () => _matchesFuture = QuizService().getMatchHistory(limit: 20)),
          );
        }
        final matches = snapshot.data?.matches ?? <MatchHistoryEntry>[];
        if (matches.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(Spacing.xl),
            children: [
              EmptyState(
                icon: Icons.sports_esports,
                title: 'No matches yet',
                body: 'Play your first match to see history here.',
                actionLabel: 'Play Now',
                onActionTap: () => widget.onSwitchToPlayTab?.call(),
              ),
            ],
          );
        }
        final myUserId = widget.auth.userId ?? '';
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.lg,
            Spacing.xl,
            Spacing.xxxl,
          ),
          itemCount: matches.length,
          separatorBuilder: (_, _) => const SizedBox(height: Spacing.xl),
          itemBuilder: (context, i) => _MatchGroup(
            match: matches[i],
            indexFromTop: i,
            myUserId: myUserId,
          ),
        );
      },
    );
  }

  Widget _matchesSkeleton() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Spacing.xl),
      itemCount: 3,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBlock(width: 80, height: 12),
            SizedBox(height: Spacing.sm),
            SkeletonBlock(height: 76, borderRadius: AppRadius.card),
            SizedBox(height: Spacing.sm),
            SkeletonBlock(height: 92, borderRadius: AppRadius.card),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // BADGES tab
  // ───────────────────────────────────────────────────────────────

  // No backend badge state today — we render the catalog and treat
  // a handful of obvious-from-profile ones as unlocked.
  static const _allBadges = <_Badge>[
    _Badge(
        id: 'first_battle',
        name: 'First Battle',
        icon: Icons.sports_esports,
        accent: AppColors.primary,
        unlockCondition: 'Play 1 match'),
    _Badge(
        id: 'first_win',
        name: 'First Win',
        icon: Icons.emoji_events,
        accent: AppColors.gold,
        unlockCondition: 'Win 1 match'),
    _Badge(
        id: 'on_fire',
        name: 'On Fire',
        icon: Icons.local_fire_department,
        accent: AppColors.flame,
        unlockCondition: '3-day streak'),
    _Badge(
        id: 'quick_thinker',
        name: 'Quick Thinker',
        icon: Icons.bolt,
        accent: AppColors.gold,
        unlockCondition: '<3s avg in a match',
        comingSoon: true),
    _Badge(
        id: 'unstoppable',
        name: 'Unstoppable',
        icon: Icons.local_fire_department,
        accent: AppColors.flame,
        unlockCondition: '5 wins in a row'),
    _Badge(
        id: 'veteran',
        name: 'Veteran',
        icon: Icons.star,
        accent: AppColors.gold,
        unlockCondition: '50 matches played'),
    _Badge(
        id: 'champion',
        name: 'Champion',
        icon: Icons.workspace_premium,
        accent: AppColors.gold,
        unlockCondition: 'Reach Advanced tier'),
    _Badge(
        id: 'legend',
        name: 'Legend',
        icon: Icons.diamond,
        accent: AppColors.speed,
        unlockCondition: 'Reach Master tier',
        legendary: true),
    _Badge(
        id: 'dedicated',
        name: 'Dedicated',
        icon: Icons.calendar_today,
        accent: AppColors.primary,
        unlockCondition: '7-day reward streak'),
    _Badge(
        id: 'comeback_king',
        name: 'Comeback King',
        icon: Icons.trending_up,
        accent: AppColors.success,
        unlockCondition: 'Win after trailing by 100+',
        comingSoon: true),
    _Badge(
        id: 'sharpshooter',
        name: 'Sharpshooter',
        icon: Icons.gps_fixed,
        accent: AppColors.primary,
        unlockCondition: '100% accuracy in a match',
        comingSoon: true),
    _Badge(
        id: 'tournament_victor',
        name: 'Tournament Victor',
        icon: Icons.emoji_events,
        accent: AppColors.gold,
        unlockCondition: 'Win a tournament',
        comingSoon: true),
  ];

  bool _isUnlocked(_Badge b, UserProfile? profile) {
    if (profile == null) return false;
    switch (b.id) {
      case 'first_battle':
        return profile.matchesPlayed >= 1;
      case 'first_win':
        return profile.wins >= 1;
      case 'on_fire':
        return profile.streak.current >= 3;
      case 'unstoppable':
        return profile.winStreak >= 5;
      case 'veteran':
        return profile.matchesPlayed >= 50;
      case 'champion':
        return profile.rating >= 2000;
      case 'legend':
        return profile.rating >= 3000;
      case 'dedicated':
        return profile.streak.longest >= 7;
      // Without per-match telemetry on the client we conservatively
      // leave these locked; backend already tracks them and would
      // light them up when a real badges provider lands.
      case 'quick_thinker':
      case 'comeback_king':
      case 'sharpshooter':
      case 'tournament_victor':
      default:
        return false;
    }
  }

  Widget _buildBadgesTab(UserProfile? profile) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.lg,
        Spacing.xl,
        Spacing.xxxl,
      ),
      // Aspect 0.72 (taller than wide) gives each tile enough vertical
      // room for the icon circle + name + a 2-line unlock condition.
      // The previous 0.85 caused a 5–6px overflow on the longer-text
      // badges (e.g. "Win after trailing by 100+").
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: Spacing.md,
        crossAxisSpacing: Spacing.md,
        childAspectRatio: 0.72,
      ),
      itemCount: _allBadges.length,
      itemBuilder: (context, i) {
        final b = _allBadges[i];
        final unlocked = _isUnlocked(b, profile);
        return _BadgeTile(
          badge: b,
          unlocked: unlocked,
          onTap: () => _showBadgeSheet(b, unlocked),
        );
      },
    );
  }

  void _showBadgeSheet(_Badge b, bool unlocked) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked
                    ? b.accent.withValues(alpha: 0.18)
                    : AppColors.surfaceHi,
                border: Border.all(
                  color: unlocked
                      ? b.accent.withValues(alpha: 0.4)
                      : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Icon(
                b.icon,
                size: 44,
                color: unlocked ? b.accent : AppColors.textDim,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(b.name, style: AppText.h2),
            const SizedBox(height: Spacing.xs),
            Text(
              unlocked
                  ? 'Unlocked'
                  : b.displayCondition,
              style: AppText.body.copyWith(
                color: unlocked ? AppColors.success : AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.xl),
            PrimaryButton(
              label: 'Got it',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // STREAK tab
  // ───────────────────────────────────────────────────────────────

  Widget _buildStreakTab(UserProfile? profile) {
    final streak = profile?.streak;
    final current = streak?.current ?? 0;
    final longest = streak?.longest ?? 0;
    final lastClaimedDate = streak?.lastClaimedDate ?? '';
    final coins = profile?.coins ?? 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.lg,
        Spacing.xl,
        Spacing.xxxl,
      ),
      children: [
        // Current streak card
        AppCard(
          gradientTint: AppColors.primary,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.flame.withValues(alpha: 0.18),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.flameGlow,
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  size: 32,
                  color: AppColors.flame,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          current.toString(),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'day streak',
                          style: AppText.bodyLg
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Best: $longest days',
                      style: AppText.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        // Coins earned card
        AppCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.goldSoft,
                ),
                child: const Icon(Icons.monetization_on,
                    size: 26, color: AppColors.gold),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$coins coins',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total balance — earn more by playing & keeping your streak alive',
                      style: AppText.body
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.xxl),

        // LAST 30 DAYS calendar
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              'LAST 30 DAYS',
              style: AppText.caption.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        _Last30DaysCalendar(
          current: current,
          lastClaimedDate: lastClaimedDate,
        ),

        const SizedBox(height: Spacing.xxl),

        // Rewards roadmap
        Row(
          children: [
            const Icon(Icons.flag_outlined,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              'STREAK REWARDS',
              style: AppText.caption.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        SizedBox(
          height: 152,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              _MilestoneCard(day: 3, reward: '+30 coins'),
              SizedBox(width: Spacing.md),
              _MilestoneCard(day: 5, reward: '+50 coins + 1 quiz'),
              SizedBox(width: Spacing.md),
              _MilestoneCard(day: 7, reward: '+100 coins + badge'),
              SizedBox(width: Spacing.md),
              _MilestoneCard(day: 14, reward: '+200 coins + badge'),
              SizedBox(width: Spacing.md),
              _MilestoneCard(day: 30, reward: '+200 coins'),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────
  // REFERR tab
  // ───────────────────────────────────────────────────────────────

  Widget _buildReferrTab(UserProfile? profile) {
    final code = profile?.referralCode ?? '';
    _referralFuture ??= QuizService().getReferralDashboard();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.lg,
        Spacing.xl,
        Spacing.xxxl,
      ),
      children: [
        // Code card with coral glow
        AppCard(
          borderColor: AppColors.primary.withValues(alpha: 0.35),
          glowColor: AppColors.primary,
          gradientTint: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            vertical: Spacing.xl,
            horizontal: Spacing.lg,
          ),
          child: Row(
            children: [
              const Icon(Icons.card_giftcard,
                  size: 24, color: AppColors.primary),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  code.isEmpty ? '------' : code,
                  style: AppText.codeBig,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy_outlined,
                    size: 22, color: AppColors.primary),
                onPressed: code.isEmpty ? null : () => _copyCode(code),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'Share this code with friends. When they register and enter your code, you both earn rewards.',
          style: AppText.body.copyWith(color: AppColors.textMuted),
          maxLines: 3,
        ),

        // REFERRAL STATS
        _sectionLabel('REFERRAL STATS'),
        FutureBuilder<GetReferralDashboardResponse>(
          future: _referralFuture,
          builder: (context, snap) {
            final invited = snap.data?.totalInvites ?? 0;
            final earned = snap.data?.coinsEarned ?? 0;
            final conversions = snap.data?.conversions ?? 0;
            // Server caps at 20 CONVERTED referrals — see services/auth/main.go:1112-1118.
            final slotsLeft = math.max(0, 20 - conversions);
            final hasError = snap.hasError;
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCell(
                        icon: Icons.person_add_alt_1,
                        iconColor: AppColors.primary,
                        value: hasError ? '—' : invited.toString(),
                        label: 'Friends Invited',
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: StatCell(
                        icon: Icons.monetization_on,
                        iconColor: AppColors.gold,
                        value: hasError ? '—' : earned.toString(),
                        label: 'Coins Earned',
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: StatCell(
                        icon: Icons.people_alt_outlined,
                        iconColor: AppColors.textMuted,
                        value: hasError ? '—' : slotsLeft.toString(),
                        label: 'Slots Left',
                      ),
                    ),
                  ],
                ),
                if (hasError)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _referralFuture =
                              QuizService().getReferralDashboard();
                        });
                      },
                      child: Text(
                        'Couldn\'t load — Retry',
                        style: AppText.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // HAVE A REFERRAL CODE?
        _sectionLabel('HAVE A REFERRAL CODE?'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'If a friend gave you their code, enter it here to earn bonus rewards.',
                style: AppText.body.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      enabled: !_applying,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]')),
                        LengthLimitingTextInputFormatter(12),
                        TextInputFormatter.withFunction((oldVal, newVal) =>
                            newVal.copyWith(text: newVal.text.toUpperCase())),
                      ],
                      style: AppText.bodyLg.copyWith(letterSpacing: 4),
                      decoration: InputDecoration(
                        hintText: 'X X X X X X',
                        hintStyle: AppText.bodyLg.copyWith(
                          color: AppColors.textDim,
                          letterSpacing: 4,
                        ),
                        errorText: _applyError,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  PrimaryButton(
                    label: 'Apply',
                    expanded: false,
                    height: 52,
                    loading: _applying,
                    onPressed: _codeCtrl.text.length >= 6 ? _applyCode : null,
                  ),
                ],
              ),
            ],
          ),
        ),

        // HOW IT WORKS
        _sectionLabel('HOW IT WORKS'),
        const _HowItWorksCard(),

        // LIMITS
        _sectionLabel('LIMITS'),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceHi,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in const [
                '• Maximum 20 successful referrals per account.',
                '• Referral code must be applied during registration.',
                '• Rewards credit after the friend\'s first match.',
                '• Self-referrals and guest accounts are not eligible.',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    line,
                    style: AppText.caption.copyWith(color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Shared sub-builders
  // ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: Spacing.xxl, bottom: Spacing.sm),
        child: Text(
          title,
          style: AppText.bodyLg.copyWith(fontWeight: FontWeight.w700),
        ),
      );

  Widget _sectionLabel(String title) => Padding(
        padding: const EdgeInsets.only(top: Spacing.xxl, bottom: Spacing.sm),
        child: Text(
          title,
          style: AppText.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      );

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppText.caption
                        .copyWith(color: AppColors.textMuted)),
                Text(value,
                    style: AppText.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tileGroup(List<Widget> tiles) {
    final filtered = tiles.whereType<_ManagementTile>().toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    final children = <Widget>[];
    for (var i = 0; i < filtered.length; i++) {
      children.add(filtered[i]);
      if (i < filtered.length - 1) {
        children.add(const Divider(
          color: AppColors.border,
          height: 1,
          indent: 56,
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: children),
    );
  }

  Widget _errorState(String title, String body, VoidCallback retry) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.xl),
      children: [
        EmptyState(
          icon: Icons.error_outline,
          iconColor: AppColors.danger,
          title: title,
          body: body,
          actionLabel: 'Try again',
          onActionTap: retry,
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Actions
  // ───────────────────────────────────────────────────────────────

  Future<void> _openEditProfile() async {
    final profile = widget.homeData?.profile;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          displayName: profile?.displayName ?? (widget.auth.username ?? ''),
          avatarUrl: profile?.avatarUrl ?? '',
          preferredTopics: profile?.preferredTopics.toList() ?? <String>[],
        ),
      ),
    );
    if (saved == true && mounted) {
      await widget.onRefresh();
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard'),
        duration: Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _applyCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 6) return;
    setState(() {
      _applying = true;
      _applyError = null;
    });
    try {
      await QuizService().applyReferralCode(code);
      if (!mounted) return;
      _codeCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Referral code applied — rewards coming your way.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _referralFuture = QuizService().getReferralDashboard();
      await widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _applyError = _friendlyApplyError(e));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  String _friendlyApplyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('already')) return 'You\'ve already used a referral code.';
    if (msg.contains('not found') || msg.contains('invalid')) {
      return 'That code isn\'t valid.';
    }
    if (msg.contains('self')) return 'You can\'t refer yourself.';
    if (msg.contains('guest')) return 'Link an email first to apply a code.';
    return 'Couldn\'t apply that code. Please try again.';
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out of Quiz Battle?'),
        content: const Text(
            'You\'ll need to sign back in to play matches and access your rewards.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onLogout();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sticky TabBar delegate
// ─────────────────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;
  _TabBarDelegate(this.controller);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.bg,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: AppText.caption.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: AppText.caption.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Profile'),
          Tab(text: 'Matches'),
          Tab(text: 'Badges'),
          Tab(text: 'Streak'),
          Tab(text: 'Referrals'),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _TabBarDelegate old) =>
      old.controller != controller;
}

// ─────────────────────────────────────────────────────────────────────
// Management-tile row used in PROFIL "Account / Game / …" sections
// ─────────────────────────────────────────────────────────────────────

class _ManagementTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? trailingBadge;
  final VoidCallback onTap;

  const _ManagementTile({
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
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.md),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (trailingBadge != null) ...[
                PillChip(
                  label: trailingBadge!,
                  color: AppColors.primary,
                  variant: PillVariant.solid,
                ),
                const SizedBox(width: Spacing.sm),
              ],
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// _MatchGroup — one entry in the LAST M tab
// ─────────────────────────────────────────────────────────────────────

class _MatchGroup extends StatelessWidget {
  final MatchHistoryEntry match;
  final int indexFromTop;
  final String myUserId;
  const _MatchGroup({
    required this.match,
    required this.indexFromTop,
    required this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    // Pull this user's PlayerResult out of the entry. May be absent
    // if the user wasn't in this match for some reason — fall back
    // to neutral defaults.
    PlayerResult? me;
    for (final p in match.players) {
      if (p.userId == myUserId) {
        me = p;
        break;
      }
    }
    final rank = me?.rank ?? 0;
    final score = (me?.finalScore ?? 0).toInt();
    final correct = me?.answersCorrect ?? 0;
    final total = match.rounds;
    final hasRounds = total > 0;
    // coinsAwarded is Int64 on the proto — convert to int.
    final coinsAwarded = me?.coinsAwarded.toInt() ?? 0;
    final avgMs = (me?.avgResponseTimeMs ?? 0).toDouble();
    final duration = match.duration.toInt();
    final accuracy = hasRounds ? correct / total : 0.0;

    // Result classification:
    //   • rank 1 == win
    //   • winner field empty + nobody scored == no winner
    //   • else == defeat (rank > 1 or rank 0)
    final isVictory = rank == 1;
    final noWinner = match.winner.isEmpty;

    Color bannerBg;
    Color bannerBorder;
    Color iconColor;
    IconData icon;
    String title;
    Color titleColor;
    String subtitle;

    if (isVictory) {
      bannerBg = AppColors.goldSoft;
      bannerBorder = AppColors.gold.withValues(alpha: 0.3);
      iconColor = AppColors.gold;
      icon = Icons.emoji_events;
      title = 'Victory';
      titleColor = AppColors.gold;
      subtitle = 'You won this match!';
    } else if (noWinner) {
      bannerBg = AppColors.surfaceHi;
      bannerBorder = AppColors.border;
      iconColor = AppColors.textMuted;
      icon = Icons.do_not_disturb_on_outlined;
      title = 'No winner';
      titleColor = AppColors.text;
      subtitle = 'Nobody answered correctly';
    } else {
      bannerBg = AppColors.dangerSoft;
      bannerBorder = AppColors.danger.withValues(alpha: 0.3);
      iconColor = AppColors.danger;
      icon = Icons.outlined_flag;
      title = 'Defeat';
      titleColor = AppColors.danger;
      subtitle = 'Better luck next time';
    }

    Color accuracyFill;
    if (!hasRounds) {
      accuracyFill = AppColors.textDim;
    } else if (accuracy >= 0.7) {
      accuracyFill = AppColors.success;
    } else if (accuracy >= 0.3) {
      accuracyFill = AppColors.primary;
    } else {
      accuracyFill = AppColors.danger;
    }

    final rankColor = rank == 1
        ? AppColors.tierGold
        : rank == 2
            ? AppColors.tierSilver
            : rank == 3
                ? AppColors.tierBronze
                : AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: Text(
            'MATCH ${indexFromTop + 1}',
            style: AppText.caption.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: bannerBorder),
          ),
          padding: const EdgeInsets.all(Spacing.lg),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.h3.copyWith(color: titleColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.body
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (rank > 0)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: rankColor, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#$rank',
                    style: AppText.body.copyWith(
                      color: rankColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            Expanded(
              child: StatCell(
                icon: Icons.bolt,
                iconColor: AppColors.gold,
                value: score.toString(),
                label: 'Score',
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: StatCell(
                icon: Icons.check_circle,
                iconColor: AppColors.success,
                value: hasRounds ? '$correct/$total' : '—',
                label: 'Correct',
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: StatCell(
                icon: Icons.monetization_on,
                iconColor: AppColors.gold,
                value: coinsAwarded > 0 ? '+$coinsAwarded' : '0',
                label: 'Earned',
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        AppCard(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  Text('Accuracy',
                      style: AppText.body
                          .copyWith(color: AppColors.textMuted)),
                  const Spacer(),
                  Text(
                    hasRounds ? '${(accuracy * 100).round()}%' : '—',
                    style: AppText.body.copyWith(
                      color: accuracyFill,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              ProgressBar(value: accuracy, color: accuracyFill),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(
              child: StatCell(
                icon: Icons.speed,
                iconColor: AppColors.gold,
                value: '${(avgMs / 1000).toStringAsFixed(1)}s',
                label: 'Avg Response',
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: StatCell(
                icon: Icons.timer_outlined,
                iconColor: AppColors.textMuted,
                value: '${duration}s',
                label: 'Duration',
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: StatCell(
                icon: Icons.help_outline,
                iconColor: AppColors.primary,
                value: hasRounds ? total.toString() : '—',
                label: 'Rounds',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// _BadgeTile + _LegendaryGlow wrapper
// ─────────────────────────────────────────────────────────────────────

class _BadgeTile extends StatelessWidget {
  final _Badge badge;
  final bool unlocked;
  final VoidCallback onTap;
  const _BadgeTile({
    required this.badge,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = AppCard(
      padding: const EdgeInsets.all(Spacing.md),
      borderColor: (unlocked && badge.legendary)
          ? AppColors.speed.withValues(alpha: 0.5)
          : null,
      onTap: onTap,
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.85,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked
                    ? badge.accent.withValues(alpha: 0.18)
                    : AppColors.surfaceHi,
              ),
              child: Icon(
                badge.icon,
                size: 26,
                color: unlocked ? badge.accent : AppColors.textDim,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              badge.name,
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: unlocked ? AppColors.text : AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (unlocked)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Unlocked',
                    style: AppText.caption.copyWith(color: AppColors.success),
                  ),
                ],
              )
            else
              Text(
                badge.displayCondition,
                style: AppText.caption.copyWith(color: AppColors.textDim),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );

    if (unlocked && badge.legendary) {
      return _LegendaryGlow(child: card);
    }
    return card;
  }
}

class _LegendaryGlow extends StatefulWidget {
  final Widget child;
  const _LegendaryGlow({required this.child});

  @override
  State<_LegendaryGlow> createState() => _LegendaryGlowState();
}

class _LegendaryGlowState extends State<_LegendaryGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final blur = 8.0 + _c.value * 10.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow: [
              BoxShadow(
                color: AppColors.speedGlow,
                blurRadius: blur,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// _Last30DaysCalendar
// ─────────────────────────────────────────────────────────────────────

class _Last30DaysCalendar extends StatelessWidget {
  final int current;
  final String lastClaimedDate; // "yyyy-MM-dd" in IST per the proto, or ""
  const _Last30DaysCalendar({
    required this.current,
    required this.lastClaimedDate,
  });

  // IST is UTC+5:30 — hardcoded because the proto's StreakInfo.last_claimed_date
  // is explicitly "YYYY-MM-DD in IST" (no DST). Per-device local time would
  // disagree at the day boundary for anyone outside IST.
  static const _istOffset = Duration(hours: 5, minutes: 30);

  /// "Today" in IST as a `DateTime` whose Y-M-D values represent the IST
  /// calendar date. The time component is dropped — we compare dates only.
  static DateTime _istToday() {
    final ist = DateTime.now().toUtc().add(_istOffset);
    return DateTime.utc(ist.year, ist.month, ist.day);
  }

  bool _isToday(DateTime d, DateTime today) =>
      d.year == today.year && d.month == today.month && d.day == today.day;

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final today = _istToday();
    // Build a 30-day window ending today-in-IST (oldest at index 0).
    final days = List<DateTime>.generate(
      30,
      (i) => DateTime.utc(today.year, today.month, today.day - (29 - i)),
    );

    // Parse the server's IST-formatted YYYY-MM-DD as a UTC-midnight
    // DateTime so date arithmetic against `today` (also UTC-midnight)
    // produces correct day differences regardless of device timezone.
    DateTime? lastClaim;
    if (lastClaimedDate.isNotEmpty) {
      final parts = lastClaimedDate.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          lastClaim = DateTime.utc(y, m, d);
        }
      }
    }

    bool isClaimed(DateTime d) {
      final claim = lastClaim;
      if (claim == null || current <= 0) return false;
      final diff = claim.difference(d).inDays;
      return diff >= 0 && diff < current;
    }

    // Today is unclaimed when either we have no claim record at all OR
    // the latest claim is for a previous IST day.
    final todayUnclaimed =
        lastClaim == null || _ymd(lastClaim) != _ymd(today);

    return GridView.count(
      crossAxisCount: 7,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final d in days)
          _Last30Cell(
            day: d.day,
            isToday: _isToday(d, today),
            isClaimed: isClaimed(d),
            todayUnclaimed: _isToday(d, today) && todayUnclaimed,
          ),
      ],
    );
  }
}

class _Last30Cell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isClaimed;
  final bool todayUnclaimed;
  const _Last30Cell({
    required this.day,
    required this.isToday,
    required this.isClaimed,
    required this.todayUnclaimed,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color borderColor;
    final double borderWidth;
    final Color textColor;

    if (todayUnclaimed) {
      bg = Colors.transparent;
      borderColor = AppColors.primary;
      borderWidth = 1.5;
      textColor = AppColors.primary;
    } else if (isToday && isClaimed) {
      bg = AppColors.success.withValues(alpha: 0.18);
      borderColor = AppColors.gold;
      borderWidth = 1.5;
      textColor = AppColors.text;
    } else if (isClaimed) {
      bg = AppColors.success.withValues(alpha: 0.18);
      borderColor = AppColors.success.withValues(alpha: 0.6);
      borderWidth = 1;
      textColor = AppColors.text;
    } else {
      bg = Colors.transparent;
      borderColor = AppColors.border;
      borderWidth = 1;
      textColor = AppColors.textDim;
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: AppText.body.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// _MilestoneCard — used in the streak rewards roadmap
// ─────────────────────────────────────────────────────────────────────

class _MilestoneCard extends StatelessWidget {
  final int day;
  final String reward;
  const _MilestoneCard({required this.day, required this.reward});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: AppCard(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Day $day',
              style:
                  AppText.caption.copyWith(color: AppColors.textMuted),
            ),
            const Spacer(),
            const Icon(Icons.monetization_on,
                size: 28, color: AppColors.gold),
            const SizedBox(height: Spacing.sm),
            Text(
              reward,
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// _HowItWorksCard — 3 step rows in a divided AppCard
// ─────────────────────────────────────────────────────────────────────

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: const [
          _HowItWorksStep(
            icon: Icons.share,
            title: 'Share your code',
            description:
                'Send your 6-digit code to a friend who doesn\'t have the app yet.',
          ),
          Divider(
            color: AppColors.divider,
            height: 1,
            indent: Spacing.lg,
            endIndent: Spacing.lg,
          ),
          _HowItWorksStep(
            icon: Icons.person_add_alt_1,
            title: 'Friend registers',
            description:
                'They enter your code during registration to link with you.',
          ),
          Divider(
            color: AppColors.divider,
            height: 1,
            indent: Spacing.lg,
            endIndent: Spacing.lg,
          ),
          _HowItWorksStep(
            icon: Icons.card_giftcard,
            title: 'Both earn rewards',
            description:
                'Coins land in both accounts after your friend\'s first match.',
          ),
        ],
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _HowItWorksStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.bodyLg.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppText.body.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
