import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';

import '../proto/quiz.pb.dart';
import '../providers/friends_state.dart';
import '../providers/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/google_style_avatar.dart';
import '../widgets/section_header.dart';
import 'add_friend_modal.dart';

/// FriendsScreen — two-tab UX: a Friends list with online/offline pill
/// + a Challenge action per row, and an incoming-Requests list with
/// Accept / Reject buttons. Add-friend is a FAB that opens a modal
/// bottom sheet for username or referral-code entry.
///
/// Wires every backend RPC: GetFriendsList, GetFriendRequests,
/// SendFriendRequest (via the modal), RespondToFriendRequest (per row),
/// ChallengeFriend (per row). Heartbeat is fired separately by
/// AppShell so presence stays fresh while the app is foregrounded.
class FriendsScreen extends ConsumerStatefulWidget {
  /// Tab to show when the screen opens. 0 = Friends list (default),
  /// 1 = Incoming Requests. The `notif.friend.request_received` FCM
  /// tap routes here with index 1 so the user lands on the new request
  /// directly instead of having to swipe over.
  const FriendsScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(friendsListProvider);
    ref.invalidate(friendRequestsProvider);
    await Future.wait([
      ref.read(friendsListProvider.future),
      ref.read(friendRequestsProvider.future),
    ]);
  }

  Future<void> _openAddFriendSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddFriendModal(),
    );
    if (added == true) ref.invalidate(friendsListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(friendRequestsCountProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          unselectedLabelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'Friends'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: TabBarView(
          controller: _tab,
          children: [
            _FriendsTab(onAddTap: _openAddFriendSheet),
            const _RequestsTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddFriendSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Add friend',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Friends tab
// ─────────────────────────────────────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  final VoidCallback onAddTap;
  const _FriendsTab({required this.onAddTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsListProvider);

    return friends.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        iconColor: AppColors.danger,
        title: "Couldn't load friends",
        body: e.toString(),
        actionLabel: 'Retry',
        onActionTap: () => ref.invalidate(friendsListProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.group_add_rounded,
            iconColor: AppColors.primary,
            title: 'No friends yet',
            body: "Add a friend by their username or referral code, then challenge them to a head-to-head quiz.",
            actionLabel: 'Add your first friend',
            onActionTap: onAddTap,
          );
        }
        // Sort: online users first, then alphabetical by username.
        final sorted = [...list]..sort((a, b) {
          if (a.online != b.online) return a.online ? -1 : 1;
          return a.username.toLowerCase().compareTo(b.username.toLowerCase());
        });
        final onlineCount = sorted.where((f) => f.online).length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            SectionHeader(
              title: 'Online · $onlineCount',
              icon: Icons.circle_rounded,
              iconColor: AppColors.success,
            ),
            const SizedBox(height: 8),
            ...sorted.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _FriendRow(friend: e.value)
                        .animate()
                        .fadeIn(
                          delay: Duration(milliseconds: 30 * (e.key % 8)),
                          duration: 250.ms,
                        )
                        .slideY(
                          begin: 0.05,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _FriendRow extends ConsumerStatefulWidget {
  final Friend friend;
  const _FriendRow({required this.friend});

  @override
  ConsumerState<_FriendRow> createState() => _FriendRowState();
}

class _FriendRowState extends ConsumerState<_FriendRow> {
  bool _challenging = false;

  Future<void> _onChallenge() async {
    setState(() => _challenging = true);
    try {
      final r = await ref
          .read(friendsServiceProvider)
          .challenge(widget.friend.userId);
      if (!mounted) return;
      if (r.success && r.roomId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.friend.username} has been notified.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Skip the matchmaking pool — ChallengeFriend already created
        // the room with both players. Jump straight to gameplay; the
        // recipient lands on the same roomId via their FCM tap handler.
        ref.read(gameStateProvider.notifier).joinChallengeRoom(r.roomId!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_challengeErrorCopy(r.errorCode)),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on GrpcError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Challenge failed'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _challenging = false);
    }
  }

  String _challengeErrorCopy(String? code) {
    switch (code) {
      case 'NOT_FRIENDS':
        return "You're not friends anymore.";
      case 'FRIEND_OFFLINE':
        return "${widget.friend.username} is offline. Try again later.";
      case 'THROTTLED':
        return "You just challenged them. Wait a minute and try again.";
      default:
        return 'Challenge failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appCardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Avatar with online dot.
          Stack(
            clipBehavior: Clip.none,
            children: [
              GoogleStyleAvatar(
                name: widget.friend.username,
                size: 44,
              ),
              if (widget.friend.online)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friend.username,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.friend.online ? 'Online · ready to play' : 'Offline',
                  style: TextStyle(
                    color: widget.friend.online
                        ? AppColors.success
                        : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Challenge button — primary when online, muted when offline
          // (still tap-able; server returns FRIEND_OFFLINE which we
          // surface in the snackbar).
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: _challenging ? null : _onChallenge,
              icon: _challenging
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bolt_rounded, size: 16),
              label: const Text(
                'Challenge',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.friend.online
                    ? AppColors.primary
                    : AppColors.cardTint,
                foregroundColor: widget.friend.online
                    ? Colors.white
                    : AppColors.textMuted,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: widget.friend.online
                      ? BorderSide.none
                      : const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Requests tab
// ─────────────────────────────────────────────────────────────────────

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(friendRequestsProvider);

    return requests.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        iconColor: AppColors.danger,
        title: "Couldn't load requests",
        body: e.toString(),
        actionLabel: 'Retry',
        onActionTap: () => ref.invalidate(friendRequestsProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_rounded,
            iconColor: AppColors.accent,
            title: 'No pending requests',
            body: "When someone sends you a friend request, it'll show up here.",
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _RequestRow(request: list[i])
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
        );
      },
    );
  }
}

class _RequestRow extends ConsumerStatefulWidget {
  final FriendRequest request;
  const _RequestRow({required this.request});

  @override
  ConsumerState<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends ConsumerState<_RequestRow> {
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    setState(() => _busy = true);
    try {
      final ok = await ref.read(friendsServiceProvider).respond(
            requestId: widget.request.id,
            accept: accept,
          );
      if (!mounted) return;
      if (ok) {
        // Refresh both: an accept moves the row from Requests to
        // Friends; a reject just removes it.
        ref.invalidate(friendRequestsProvider);
        if (accept) ref.invalidate(friendsListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept
                ? "You're now friends with ${widget.request.fromUsername}!"
                : 'Request rejected.'),
            backgroundColor: accept ? AppColors.success : AppColors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on GrpcError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appCardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          GoogleStyleAvatar(name: widget.request.fromUsername, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.fromUsername,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'wants to be your friend',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Reject + Accept buttons.
          IconButton(
            onPressed: _busy ? null : () => _respond(false),
            tooltip: 'Reject',
            icon: const Icon(Icons.close_rounded, color: AppColors.danger),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.danger.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _busy ? null : () => _respond(true),
            tooltip: 'Accept',
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
