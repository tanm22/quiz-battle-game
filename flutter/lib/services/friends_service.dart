import 'package:grpc/grpc.dart';

import '../proto/quiz.pbgrpc.dart';
import 'quiz_service.dart';

/// Result of a SendFriendRequest call. We surface the typed
/// `error_code` to the UI rather than throwing, since "USER_NOT_FOUND"
/// and "ALREADY_FRIENDS" need different copy and aren't really errors
/// in the network sense — same hybrid contract the purchase modal uses.
class FriendRequestResult {
  final bool success;
  final String? requestId;
  final String? errorCode; // empty/null on success
  const FriendRequestResult({
    required this.success,
    this.requestId,
    this.errorCode,
  });
}

class ChallengeResult {
  final bool success;
  final String? roomId;
  final String? errorCode;
  const ChallengeResult({
    required this.success,
    this.roomId,
    this.errorCode,
  });
}

/// Thin typed wrapper around [ScoringServiceClient] for every friends
/// + challenges RPC the Flutter app needs. Same pattern as
/// [CoinsService] / [AnalyticsService] — reuses the shared
/// [QuizService] singleton's gRPC channel + JWT call-options instead
/// of opening a duplicate.
class FriendsService {
  FriendsService(this._client, this._optsBuilder);

  factory FriendsService.fromQuizService(QuizService qs) =>
      FriendsService(qs.scoring, () => qs.authCallOptions);

  final ScoringServiceClient _client;
  final CallOptions Function() _optsBuilder;

  /// Accepted friendships, with `online` derived from the Redis
  /// presence:{userId} TTL key on the server.
  Future<List<Friend>> list() async {
    final r = await _client.getFriendsList(
      GetFriendsListRequest(),
      options: _optsBuilder(),
    );
    return r.friends;
  }

  /// Incoming pending friend requests. Outgoing requests aren't
  /// surfaced here in v1 — the sender already knows from the
  /// SendFriendRequest response.
  Future<List<FriendRequest>> incomingRequests() async {
    final r = await _client.getFriendRequests(
      GetFriendRequestsRequest(),
      options: _optsBuilder(),
    );
    return r.incoming;
  }

  /// Add by username OR by referral code (exactly one must be set).
  /// The "auto-accept-reverse" path on the server means this can also
  /// turn an incoming pending request into an accepted friendship if
  /// the target had previously requested the caller.
  Future<FriendRequestResult> sendRequest({
    String? username,
    String? referralCode,
  }) async {
    final req = SendFriendRequestRequest();
    if (username != null && username.isNotEmpty) {
      req.targetUsername = username;
    }
    if (referralCode != null && referralCode.isNotEmpty) {
      req.targetReferralCode = referralCode;
    }
    final r = await _client.sendFriendRequest(req, options: _optsBuilder());
    return FriendRequestResult(
      success: r.success,
      requestId: r.requestId.isEmpty ? null : r.requestId,
      errorCode: r.errorCode.isEmpty ? null : r.errorCode,
    );
  }

  /// Accept or reject a pending incoming request. Caller must be the
  /// recipient of the request — the server enforces that.
  Future<bool> respond({required String requestId, required bool accept}) async {
    final r = await _client.respondToFriendRequest(
      RespondToFriendRequestRequest()
        ..requestId = requestId
        ..accept = accept,
      options: _optsBuilder(),
    );
    return r.success;
  }

  /// Challenge an accepted friend to a private 1v1 room. Returns the
  /// room id on success (the friend's notification handler routes them
  /// into the same room). Surfaces typed error codes (NOT_FRIENDS,
  /// FRIEND_OFFLINE, THROTTLED) to the UI.
  Future<ChallengeResult> challenge(String friendUserId) async {
    final r = await _client.challengeFriend(
      ChallengeFriendRequest()..friendUserId = friendUserId,
      options: _optsBuilder(),
    );
    return ChallengeResult(
      success: r.success,
      roomId: r.roomId.isEmpty ? null : r.roomId,
      errorCode: r.errorCode.isEmpty ? null : r.errorCode,
    );
  }

  /// Heartbeat — refresh the caller's presence:{userId} TTL on Redis.
  /// Clients call this on app foreground / every ~30s while open. The
  /// server stamps `presence:{userId}` with a TTL so the friends list's
  /// `online` flag goes false naturally when this stops firing.
  Future<void> heartbeat() async {
    await _client.heartbeat(HeartbeatRequest(), options: _optsBuilder());
  }
}
