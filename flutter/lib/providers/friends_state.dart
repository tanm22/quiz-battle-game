import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proto/quiz.pb.dart';
import '../services/friends_service.dart';
import '../services/quiz_service.dart';

/// Singleton service binding. Reuses the shared QuizService channel
/// + JWT call-options — same pattern as coinsServiceProvider.
final friendsServiceProvider = Provider<FriendsService>((ref) {
  return FriendsService.fromQuizService(QuizService());
});

/// Accepted friendships. Refreshed by:
///   - `ref.invalidate(friendsListProvider)` after accepting a request
///   - `ref.invalidate(friendsListProvider)` after a successful
///     SendFriendRequest auto-accept-reverse path
///   - pull-to-refresh on the Friends screen
///   - the FCM tap handler for `notif.friend.request_accepted`
///   - **autoDispose**: navigating away from the Friends screen disposes
///     this provider, so the next entry to the screen always fetches a
///     fresh list. Without autoDispose the cached value survives
///     navigation and presence flags (online/offline) go stale.
final friendsListProvider = FutureProvider.autoDispose<List<Friend>>((ref) async {
  return ref.watch(friendsServiceProvider).list();
});

/// Incoming pending friend requests (the badge on the home tile +
/// the Requests tab pull from this). Outgoing requests aren't surfaced
/// here in v1 — the SendFriendRequest response is enough for the sender.
///
/// **autoDispose**: same rationale as friendsListProvider — navigating
/// away from the Requests tab should free the cache so a re-entry
/// reflects requests that arrived while the screen was unmounted.
/// Without this, a request that lands while the user is on the home
/// screen wouldn't appear when they re-enter Friends → Requests.
final friendRequestsProvider = FutureProvider.autoDispose<List<FriendRequest>>((ref) async {
  return ref.watch(friendsServiceProvider).incomingRequests();
});

/// Convenience derived count for the home-tile badge — number of
/// incoming pending requests. Renders 0 while loading or on error so
/// the badge doesn't flicker on every refresh.
final friendRequestsCountProvider = Provider<int>((ref) {
  return ref.watch(friendRequestsProvider).maybeWhen(
        data: (requests) => requests.length,
        orElse: () => 0,
      );
});
