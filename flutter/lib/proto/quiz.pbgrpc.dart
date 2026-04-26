// This is a generated file - do not edit.
//
// Generated from quiz.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'quiz.pb.dart' as $0;

export 'quiz.pb.dart';

@$pb.GrpcServiceName('quiz.MatchmakingService')
class MatchmakingServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  MatchmakingServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.JoinMatchmakingResponse> joinMatchmaking(
    $0.JoinMatchmakingRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$joinMatchmaking, request, options: options);
  }

  $grpc.ResponseFuture<$0.LeaveMatchmakingResponse> leaveMatchmaking(
    $0.LeaveMatchmakingRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$leaveMatchmaking, request, options: options);
  }

  $grpc.ResponseStream<$0.MatchEvent> subscribeToMatch(
    $0.SubscribeToMatchRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$subscribeToMatch, $async.Stream.fromIterable([request]),
        options: options);
  }

  // method descriptors

  static final _$joinMatchmaking =
      $grpc.ClientMethod<$0.JoinMatchmakingRequest, $0.JoinMatchmakingResponse>(
          '/quiz.MatchmakingService/JoinMatchmaking',
          ($0.JoinMatchmakingRequest value) => value.writeToBuffer(),
          $0.JoinMatchmakingResponse.fromBuffer);
  static final _$leaveMatchmaking = $grpc.ClientMethod<
          $0.LeaveMatchmakingRequest, $0.LeaveMatchmakingResponse>(
      '/quiz.MatchmakingService/LeaveMatchmaking',
      ($0.LeaveMatchmakingRequest value) => value.writeToBuffer(),
      $0.LeaveMatchmakingResponse.fromBuffer);
  static final _$subscribeToMatch =
      $grpc.ClientMethod<$0.SubscribeToMatchRequest, $0.MatchEvent>(
          '/quiz.MatchmakingService/SubscribeToMatch',
          ($0.SubscribeToMatchRequest value) => value.writeToBuffer(),
          $0.MatchEvent.fromBuffer);
}

@$pb.GrpcServiceName('quiz.MatchmakingService')
abstract class MatchmakingServiceBase extends $grpc.Service {
  $core.String get $name => 'quiz.MatchmakingService';

  MatchmakingServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.JoinMatchmakingRequest,
            $0.JoinMatchmakingResponse>(
        'JoinMatchmaking',
        joinMatchmaking_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.JoinMatchmakingRequest.fromBuffer(value),
        ($0.JoinMatchmakingResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LeaveMatchmakingRequest,
            $0.LeaveMatchmakingResponse>(
        'LeaveMatchmaking',
        leaveMatchmaking_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.LeaveMatchmakingRequest.fromBuffer(value),
        ($0.LeaveMatchmakingResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SubscribeToMatchRequest, $0.MatchEvent>(
        'SubscribeToMatch',
        subscribeToMatch_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.SubscribeToMatchRequest.fromBuffer(value),
        ($0.MatchEvent value) => value.writeToBuffer()));
  }

  $async.Future<$0.JoinMatchmakingResponse> joinMatchmaking_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.JoinMatchmakingRequest> $request) async {
    return joinMatchmaking($call, await $request);
  }

  $async.Future<$0.JoinMatchmakingResponse> joinMatchmaking(
      $grpc.ServiceCall call, $0.JoinMatchmakingRequest request);

  $async.Future<$0.LeaveMatchmakingResponse> leaveMatchmaking_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.LeaveMatchmakingRequest> $request) async {
    return leaveMatchmaking($call, await $request);
  }

  $async.Future<$0.LeaveMatchmakingResponse> leaveMatchmaking(
      $grpc.ServiceCall call, $0.LeaveMatchmakingRequest request);

  $async.Stream<$0.MatchEvent> subscribeToMatch_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SubscribeToMatchRequest> $request) async* {
    yield* subscribeToMatch($call, await $request);
  }

  $async.Stream<$0.MatchEvent> subscribeToMatch(
      $grpc.ServiceCall call, $0.SubscribeToMatchRequest request);
}

@$pb.GrpcServiceName('quiz.QuizService')
class QuizServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  QuizServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.GetRoomQuestionsResponse> getRoomQuestions(
    $0.GetRoomQuestionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getRoomQuestions, request, options: options);
  }

  $grpc.ResponseFuture<$0.SubmitAnswerResponse> submitAnswer(
    $0.SubmitAnswerRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$submitAnswer, request, options: options);
  }

  $grpc.ResponseStream<$0.GameEvent> streamGameEvents(
    $0.StreamGameEventsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$streamGameEvents, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Phase 2
  $grpc.ResponseFuture<$0.GetTournamentListResponse> getTournamentList(
    $0.GetTournamentListRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getTournamentList, request, options: options);
  }

  $grpc.ResponseFuture<$0.JoinTournamentResponse> joinTournament(
    $0.JoinTournamentRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$joinTournament, request, options: options);
  }

  // method descriptors

  static final _$getRoomQuestions = $grpc.ClientMethod<
          $0.GetRoomQuestionsRequest, $0.GetRoomQuestionsResponse>(
      '/quiz.QuizService/GetRoomQuestions',
      ($0.GetRoomQuestionsRequest value) => value.writeToBuffer(),
      $0.GetRoomQuestionsResponse.fromBuffer);
  static final _$submitAnswer =
      $grpc.ClientMethod<$0.SubmitAnswerRequest, $0.SubmitAnswerResponse>(
          '/quiz.QuizService/SubmitAnswer',
          ($0.SubmitAnswerRequest value) => value.writeToBuffer(),
          $0.SubmitAnswerResponse.fromBuffer);
  static final _$streamGameEvents =
      $grpc.ClientMethod<$0.StreamGameEventsRequest, $0.GameEvent>(
          '/quiz.QuizService/StreamGameEvents',
          ($0.StreamGameEventsRequest value) => value.writeToBuffer(),
          $0.GameEvent.fromBuffer);
  static final _$getTournamentList = $grpc.ClientMethod<
          $0.GetTournamentListRequest, $0.GetTournamentListResponse>(
      '/quiz.QuizService/GetTournamentList',
      ($0.GetTournamentListRequest value) => value.writeToBuffer(),
      $0.GetTournamentListResponse.fromBuffer);
  static final _$joinTournament =
      $grpc.ClientMethod<$0.JoinTournamentRequest, $0.JoinTournamentResponse>(
          '/quiz.QuizService/JoinTournament',
          ($0.JoinTournamentRequest value) => value.writeToBuffer(),
          $0.JoinTournamentResponse.fromBuffer);
}

@$pb.GrpcServiceName('quiz.QuizService')
abstract class QuizServiceBase extends $grpc.Service {
  $core.String get $name => 'quiz.QuizService';

  QuizServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetRoomQuestionsRequest,
            $0.GetRoomQuestionsResponse>(
        'GetRoomQuestions',
        getRoomQuestions_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetRoomQuestionsRequest.fromBuffer(value),
        ($0.GetRoomQuestionsResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SubmitAnswerRequest, $0.SubmitAnswerResponse>(
            'SubmitAnswer',
            submitAnswer_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SubmitAnswerRequest.fromBuffer(value),
            ($0.SubmitAnswerResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.StreamGameEventsRequest, $0.GameEvent>(
        'StreamGameEvents',
        streamGameEvents_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.StreamGameEventsRequest.fromBuffer(value),
        ($0.GameEvent value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetTournamentListRequest,
            $0.GetTournamentListResponse>(
        'GetTournamentList',
        getTournamentList_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetTournamentListRequest.fromBuffer(value),
        ($0.GetTournamentListResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.JoinTournamentRequest,
            $0.JoinTournamentResponse>(
        'JoinTournament',
        joinTournament_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.JoinTournamentRequest.fromBuffer(value),
        ($0.JoinTournamentResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.GetRoomQuestionsResponse> getRoomQuestions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetRoomQuestionsRequest> $request) async {
    return getRoomQuestions($call, await $request);
  }

  $async.Future<$0.GetRoomQuestionsResponse> getRoomQuestions(
      $grpc.ServiceCall call, $0.GetRoomQuestionsRequest request);

  $async.Future<$0.SubmitAnswerResponse> submitAnswer_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SubmitAnswerRequest> $request) async {
    return submitAnswer($call, await $request);
  }

  $async.Future<$0.SubmitAnswerResponse> submitAnswer(
      $grpc.ServiceCall call, $0.SubmitAnswerRequest request);

  $async.Stream<$0.GameEvent> streamGameEvents_Pre($grpc.ServiceCall $call,
      $async.Future<$0.StreamGameEventsRequest> $request) async* {
    yield* streamGameEvents($call, await $request);
  }

  $async.Stream<$0.GameEvent> streamGameEvents(
      $grpc.ServiceCall call, $0.StreamGameEventsRequest request);

  $async.Future<$0.GetTournamentListResponse> getTournamentList_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetTournamentListRequest> $request) async {
    return getTournamentList($call, await $request);
  }

  $async.Future<$0.GetTournamentListResponse> getTournamentList(
      $grpc.ServiceCall call, $0.GetTournamentListRequest request);

  $async.Future<$0.JoinTournamentResponse> joinTournament_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.JoinTournamentRequest> $request) async {
    return joinTournament($call, await $request);
  }

  $async.Future<$0.JoinTournamentResponse> joinTournament(
      $grpc.ServiceCall call, $0.JoinTournamentRequest request);
}

@$pb.GrpcServiceName('quiz.ScoringService')
class ScoringServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  ScoringServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.CalculateScoreResponse> calculateScore(
    $0.CalculateScoreRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$calculateScore, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetLeaderboardResponse> getLeaderboard(
    $0.GetLeaderboardRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getLeaderboard, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetMatchHistoryResponse> getMatchHistory(
    $0.GetMatchHistoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getMatchHistory, request, options: options);
  }

  /// Phase 2: User Service RPCs (scoring service acts as user service)
  $grpc.ResponseFuture<$0.GetHomeScreenDataResponse> getHomeScreenData(
    $0.GetHomeScreenDataRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getHomeScreenData, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetReferralDashboardResponse> getReferralDashboard(
    $0.GetReferralDashboardRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getReferralDashboard, request, options: options);
  }

  $grpc.ResponseFuture<$0.ApplyReferralCodeResponse> applyReferralCode(
    $0.ApplyReferralCodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$applyReferralCode, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateFCMTokenResponse> updateFCMToken(
    $0.UpdateFCMTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateFCMToken, request, options: options);
  }

  /// Phase 3: Global leaderboard with time filters
  $grpc.ResponseFuture<$0.GetGlobalLeaderboardResponse> getGlobalLeaderboard(
    $0.GetGlobalLeaderboardRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getGlobalLeaderboard, request, options: options);
  }

  /// Phase 3 (4.3): Coins & Shop — balance read + ledger history.
  $grpc.ResponseFuture<$0.GetCoinBalanceResponse> getCoinBalance(
    $0.GetCoinBalanceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getCoinBalance, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetCoinLedgerResponse> getCoinLedger(
    $0.GetCoinLedgerRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getCoinLedger, request, options: options);
  }

  /// Phase 3 (4.3) PR 4: shop catalog + inventory + spend.
  $grpc.ResponseFuture<$0.GetShopCatalogResponse> getShopCatalog(
    $0.GetShopCatalogRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getShopCatalog, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetShopInventoryResponse> getShopInventory(
    $0.GetShopInventoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getShopInventory, request, options: options);
  }

  $grpc.ResponseFuture<$0.PurchaseShopItemResponse> purchaseShopItem(
    $0.PurchaseShopItemRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$purchaseShopItem, request, options: options);
  }

  /// Phase 3 (4.3) PR 5: item effects.
  /// EquipCosmetic activates an owned avatar frame or name color. Idempotent
  /// — re-equipping the already-equipped item is a no-op success.
  $grpc.ResponseFuture<$0.EquipCosmeticResponse> equipCosmetic(
    $0.EquipCosmeticRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$equipCosmetic, request, options: options);
  }

  /// ConsumeReroll atomically decrements rerollCharges by 1; returns the
  /// post-decrement count so the caller can render "N left" without a
  /// second read.
  $grpc.ResponseFuture<$0.ConsumeRerollResponse> consumeReroll(
    $0.ConsumeRerollRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$consumeReroll, request, options: options);
  }

  /// Phase 3 (4.4): Friends & Challenges.
  /// SendFriendRequest takes EXACTLY ONE of target_username / target_referral_code.
  /// Idempotent on (fromUserId, toUserId): a duplicate send returns the
  /// existing pending request or the existing accepted relationship.
  $grpc.ResponseFuture<$0.SendFriendRequestResponse> sendFriendRequest(
    $0.SendFriendRequestRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sendFriendRequest, request, options: options);
  }

  /// RespondToFriendRequest accepts or rejects a pending incoming request.
  /// The caller must be the request's recipient; otherwise PERMISSION_DENIED.
  $grpc.ResponseFuture<$0.RespondToFriendRequestResponse>
      respondToFriendRequest(
    $0.RespondToFriendRequestRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$respondToFriendRequest, request,
        options: options);
  }

  /// GetFriendsList returns accepted friendships for the caller, with each
  /// friend's online flag derived from the Redis presence:{userId} TTL key.
  $grpc.ResponseFuture<$0.GetFriendsListResponse> getFriendsList(
    $0.GetFriendsListRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getFriendsList, request, options: options);
  }

  /// GetFriendRequests returns pending incoming friend requests (the
  /// outgoing direction is implicit from SendFriendRequest's response).
  $grpc.ResponseFuture<$0.GetFriendRequestsResponse> getFriendRequests(
    $0.GetFriendRequestsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getFriendRequests, request, options: options);
  }

  /// Heartbeat refreshes the caller's presence TTL. Clients call this on
  /// app foreground / every ~30s while open. No-op safe.
  $grpc.ResponseFuture<$0.HeartbeatResponse> heartbeat(
    $0.HeartbeatRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$heartbeat, request, options: options);
  }

  /// ChallengeFriend creates a private 1v1 room with the caller and the
  /// friend, publishes notif.friend.challenge, and returns the room id
  /// both clients can use to enter the game flow. The friend must be in
  /// the caller's accepted friends; otherwise NOT_FRIENDS error code.
  $grpc.ResponseFuture<$0.ChallengeFriendResponse> challengeFriend(
    $0.ChallengeFriendRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$challengeFriend, request, options: options);
  }

  /// §4.6 Notification policy. The caller manages their per-type mute
  /// preferences and timezone. Quiet hours (23:00–08:00 in the user's
  /// timezone) and the daily cap are server-side product defaults — not
  /// exposed here so individual users can't opt out of fatigue protection.
  $grpc.ResponseFuture<$0.GetNotificationPrefsResponse> getNotificationPrefs(
    $0.GetNotificationPrefsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getNotificationPrefs, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateNotificationPrefsResponse>
      updateNotificationPrefs(
    $0.UpdateNotificationPrefsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateNotificationPrefs, request,
        options: options);
  }

  /// MarkNotificationOpened is fired by the Flutter client when the user
  /// taps a notification. Increments the per-category open counter so we
  /// can compute open-rate offline (sent vs opened, per type, per day).
  $grpc.ResponseFuture<$0.MarkNotificationOpenedResponse>
      markNotificationOpened(
    $0.MarkNotificationOpenedRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$markNotificationOpened, request,
        options: options);
  }

  // method descriptors

  static final _$calculateScore =
      $grpc.ClientMethod<$0.CalculateScoreRequest, $0.CalculateScoreResponse>(
          '/quiz.ScoringService/CalculateScore',
          ($0.CalculateScoreRequest value) => value.writeToBuffer(),
          $0.CalculateScoreResponse.fromBuffer);
  static final _$getLeaderboard =
      $grpc.ClientMethod<$0.GetLeaderboardRequest, $0.GetLeaderboardResponse>(
          '/quiz.ScoringService/GetLeaderboard',
          ($0.GetLeaderboardRequest value) => value.writeToBuffer(),
          $0.GetLeaderboardResponse.fromBuffer);
  static final _$getMatchHistory =
      $grpc.ClientMethod<$0.GetMatchHistoryRequest, $0.GetMatchHistoryResponse>(
          '/quiz.ScoringService/GetMatchHistory',
          ($0.GetMatchHistoryRequest value) => value.writeToBuffer(),
          $0.GetMatchHistoryResponse.fromBuffer);
  static final _$getHomeScreenData = $grpc.ClientMethod<
          $0.GetHomeScreenDataRequest, $0.GetHomeScreenDataResponse>(
      '/quiz.ScoringService/GetHomeScreenData',
      ($0.GetHomeScreenDataRequest value) => value.writeToBuffer(),
      $0.GetHomeScreenDataResponse.fromBuffer);
  static final _$getReferralDashboard = $grpc.ClientMethod<
          $0.GetReferralDashboardRequest, $0.GetReferralDashboardResponse>(
      '/quiz.ScoringService/GetReferralDashboard',
      ($0.GetReferralDashboardRequest value) => value.writeToBuffer(),
      $0.GetReferralDashboardResponse.fromBuffer);
  static final _$applyReferralCode = $grpc.ClientMethod<
          $0.ApplyReferralCodeRequest, $0.ApplyReferralCodeResponse>(
      '/quiz.ScoringService/ApplyReferralCode',
      ($0.ApplyReferralCodeRequest value) => value.writeToBuffer(),
      $0.ApplyReferralCodeResponse.fromBuffer);
  static final _$updateFCMToken =
      $grpc.ClientMethod<$0.UpdateFCMTokenRequest, $0.UpdateFCMTokenResponse>(
          '/quiz.ScoringService/UpdateFCMToken',
          ($0.UpdateFCMTokenRequest value) => value.writeToBuffer(),
          $0.UpdateFCMTokenResponse.fromBuffer);
  static final _$getGlobalLeaderboard = $grpc.ClientMethod<
          $0.GetGlobalLeaderboardRequest, $0.GetGlobalLeaderboardResponse>(
      '/quiz.ScoringService/GetGlobalLeaderboard',
      ($0.GetGlobalLeaderboardRequest value) => value.writeToBuffer(),
      $0.GetGlobalLeaderboardResponse.fromBuffer);
  static final _$getCoinBalance =
      $grpc.ClientMethod<$0.GetCoinBalanceRequest, $0.GetCoinBalanceResponse>(
          '/quiz.ScoringService/GetCoinBalance',
          ($0.GetCoinBalanceRequest value) => value.writeToBuffer(),
          $0.GetCoinBalanceResponse.fromBuffer);
  static final _$getCoinLedger =
      $grpc.ClientMethod<$0.GetCoinLedgerRequest, $0.GetCoinLedgerResponse>(
          '/quiz.ScoringService/GetCoinLedger',
          ($0.GetCoinLedgerRequest value) => value.writeToBuffer(),
          $0.GetCoinLedgerResponse.fromBuffer);
  static final _$getShopCatalog =
      $grpc.ClientMethod<$0.GetShopCatalogRequest, $0.GetShopCatalogResponse>(
          '/quiz.ScoringService/GetShopCatalog',
          ($0.GetShopCatalogRequest value) => value.writeToBuffer(),
          $0.GetShopCatalogResponse.fromBuffer);
  static final _$getShopInventory = $grpc.ClientMethod<
          $0.GetShopInventoryRequest, $0.GetShopInventoryResponse>(
      '/quiz.ScoringService/GetShopInventory',
      ($0.GetShopInventoryRequest value) => value.writeToBuffer(),
      $0.GetShopInventoryResponse.fromBuffer);
  static final _$purchaseShopItem = $grpc.ClientMethod<
          $0.PurchaseShopItemRequest, $0.PurchaseShopItemResponse>(
      '/quiz.ScoringService/PurchaseShopItem',
      ($0.PurchaseShopItemRequest value) => value.writeToBuffer(),
      $0.PurchaseShopItemResponse.fromBuffer);
  static final _$equipCosmetic =
      $grpc.ClientMethod<$0.EquipCosmeticRequest, $0.EquipCosmeticResponse>(
          '/quiz.ScoringService/EquipCosmetic',
          ($0.EquipCosmeticRequest value) => value.writeToBuffer(),
          $0.EquipCosmeticResponse.fromBuffer);
  static final _$consumeReroll =
      $grpc.ClientMethod<$0.ConsumeRerollRequest, $0.ConsumeRerollResponse>(
          '/quiz.ScoringService/ConsumeReroll',
          ($0.ConsumeRerollRequest value) => value.writeToBuffer(),
          $0.ConsumeRerollResponse.fromBuffer);
  static final _$sendFriendRequest = $grpc.ClientMethod<
          $0.SendFriendRequestRequest, $0.SendFriendRequestResponse>(
      '/quiz.ScoringService/SendFriendRequest',
      ($0.SendFriendRequestRequest value) => value.writeToBuffer(),
      $0.SendFriendRequestResponse.fromBuffer);
  static final _$respondToFriendRequest = $grpc.ClientMethod<
          $0.RespondToFriendRequestRequest, $0.RespondToFriendRequestResponse>(
      '/quiz.ScoringService/RespondToFriendRequest',
      ($0.RespondToFriendRequestRequest value) => value.writeToBuffer(),
      $0.RespondToFriendRequestResponse.fromBuffer);
  static final _$getFriendsList =
      $grpc.ClientMethod<$0.GetFriendsListRequest, $0.GetFriendsListResponse>(
          '/quiz.ScoringService/GetFriendsList',
          ($0.GetFriendsListRequest value) => value.writeToBuffer(),
          $0.GetFriendsListResponse.fromBuffer);
  static final _$getFriendRequests = $grpc.ClientMethod<
          $0.GetFriendRequestsRequest, $0.GetFriendRequestsResponse>(
      '/quiz.ScoringService/GetFriendRequests',
      ($0.GetFriendRequestsRequest value) => value.writeToBuffer(),
      $0.GetFriendRequestsResponse.fromBuffer);
  static final _$heartbeat =
      $grpc.ClientMethod<$0.HeartbeatRequest, $0.HeartbeatResponse>(
          '/quiz.ScoringService/Heartbeat',
          ($0.HeartbeatRequest value) => value.writeToBuffer(),
          $0.HeartbeatResponse.fromBuffer);
  static final _$challengeFriend =
      $grpc.ClientMethod<$0.ChallengeFriendRequest, $0.ChallengeFriendResponse>(
          '/quiz.ScoringService/ChallengeFriend',
          ($0.ChallengeFriendRequest value) => value.writeToBuffer(),
          $0.ChallengeFriendResponse.fromBuffer);
  static final _$getNotificationPrefs = $grpc.ClientMethod<
          $0.GetNotificationPrefsRequest, $0.GetNotificationPrefsResponse>(
      '/quiz.ScoringService/GetNotificationPrefs',
      ($0.GetNotificationPrefsRequest value) => value.writeToBuffer(),
      $0.GetNotificationPrefsResponse.fromBuffer);
  static final _$updateNotificationPrefs = $grpc.ClientMethod<
          $0.UpdateNotificationPrefsRequest,
          $0.UpdateNotificationPrefsResponse>(
      '/quiz.ScoringService/UpdateNotificationPrefs',
      ($0.UpdateNotificationPrefsRequest value) => value.writeToBuffer(),
      $0.UpdateNotificationPrefsResponse.fromBuffer);
  static final _$markNotificationOpened = $grpc.ClientMethod<
          $0.MarkNotificationOpenedRequest, $0.MarkNotificationOpenedResponse>(
      '/quiz.ScoringService/MarkNotificationOpened',
      ($0.MarkNotificationOpenedRequest value) => value.writeToBuffer(),
      $0.MarkNotificationOpenedResponse.fromBuffer);
}

@$pb.GrpcServiceName('quiz.ScoringService')
abstract class ScoringServiceBase extends $grpc.Service {
  $core.String get $name => 'quiz.ScoringService';

  ScoringServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CalculateScoreRequest,
            $0.CalculateScoreResponse>(
        'CalculateScore',
        calculateScore_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CalculateScoreRequest.fromBuffer(value),
        ($0.CalculateScoreResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetLeaderboardRequest,
            $0.GetLeaderboardResponse>(
        'GetLeaderboard',
        getLeaderboard_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetLeaderboardRequest.fromBuffer(value),
        ($0.GetLeaderboardResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetMatchHistoryRequest,
            $0.GetMatchHistoryResponse>(
        'GetMatchHistory',
        getMatchHistory_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetMatchHistoryRequest.fromBuffer(value),
        ($0.GetMatchHistoryResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetHomeScreenDataRequest,
            $0.GetHomeScreenDataResponse>(
        'GetHomeScreenData',
        getHomeScreenData_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetHomeScreenDataRequest.fromBuffer(value),
        ($0.GetHomeScreenDataResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetReferralDashboardRequest,
            $0.GetReferralDashboardResponse>(
        'GetReferralDashboard',
        getReferralDashboard_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetReferralDashboardRequest.fromBuffer(value),
        ($0.GetReferralDashboardResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ApplyReferralCodeRequest,
            $0.ApplyReferralCodeResponse>(
        'ApplyReferralCode',
        applyReferralCode_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ApplyReferralCodeRequest.fromBuffer(value),
        ($0.ApplyReferralCodeResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateFCMTokenRequest,
            $0.UpdateFCMTokenResponse>(
        'UpdateFCMToken',
        updateFCMToken_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateFCMTokenRequest.fromBuffer(value),
        ($0.UpdateFCMTokenResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetGlobalLeaderboardRequest,
            $0.GetGlobalLeaderboardResponse>(
        'GetGlobalLeaderboard',
        getGlobalLeaderboard_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetGlobalLeaderboardRequest.fromBuffer(value),
        ($0.GetGlobalLeaderboardResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetCoinBalanceRequest,
            $0.GetCoinBalanceResponse>(
        'GetCoinBalance',
        getCoinBalance_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetCoinBalanceRequest.fromBuffer(value),
        ($0.GetCoinBalanceResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetCoinLedgerRequest, $0.GetCoinLedgerResponse>(
            'GetCoinLedger',
            getCoinLedger_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetCoinLedgerRequest.fromBuffer(value),
            ($0.GetCoinLedgerResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetShopCatalogRequest,
            $0.GetShopCatalogResponse>(
        'GetShopCatalog',
        getShopCatalog_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetShopCatalogRequest.fromBuffer(value),
        ($0.GetShopCatalogResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetShopInventoryRequest,
            $0.GetShopInventoryResponse>(
        'GetShopInventory',
        getShopInventory_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetShopInventoryRequest.fromBuffer(value),
        ($0.GetShopInventoryResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PurchaseShopItemRequest,
            $0.PurchaseShopItemResponse>(
        'PurchaseShopItem',
        purchaseShopItem_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.PurchaseShopItemRequest.fromBuffer(value),
        ($0.PurchaseShopItemResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.EquipCosmeticRequest, $0.EquipCosmeticResponse>(
            'EquipCosmetic',
            equipCosmetic_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.EquipCosmeticRequest.fromBuffer(value),
            ($0.EquipCosmeticResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ConsumeRerollRequest, $0.ConsumeRerollResponse>(
            'ConsumeReroll',
            consumeReroll_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ConsumeRerollRequest.fromBuffer(value),
            ($0.ConsumeRerollResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SendFriendRequestRequest,
            $0.SendFriendRequestResponse>(
        'SendFriendRequest',
        sendFriendRequest_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SendFriendRequestRequest.fromBuffer(value),
        ($0.SendFriendRequestResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RespondToFriendRequestRequest,
            $0.RespondToFriendRequestResponse>(
        'RespondToFriendRequest',
        respondToFriendRequest_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RespondToFriendRequestRequest.fromBuffer(value),
        ($0.RespondToFriendRequestResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetFriendsListRequest,
            $0.GetFriendsListResponse>(
        'GetFriendsList',
        getFriendsList_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetFriendsListRequest.fromBuffer(value),
        ($0.GetFriendsListResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetFriendRequestsRequest,
            $0.GetFriendRequestsResponse>(
        'GetFriendRequests',
        getFriendRequests_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetFriendRequestsRequest.fromBuffer(value),
        ($0.GetFriendRequestsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.HeartbeatRequest, $0.HeartbeatResponse>(
        'Heartbeat',
        heartbeat_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.HeartbeatRequest.fromBuffer(value),
        ($0.HeartbeatResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ChallengeFriendRequest,
            $0.ChallengeFriendResponse>(
        'ChallengeFriend',
        challengeFriend_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ChallengeFriendRequest.fromBuffer(value),
        ($0.ChallengeFriendResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetNotificationPrefsRequest,
            $0.GetNotificationPrefsResponse>(
        'GetNotificationPrefs',
        getNotificationPrefs_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetNotificationPrefsRequest.fromBuffer(value),
        ($0.GetNotificationPrefsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateNotificationPrefsRequest,
            $0.UpdateNotificationPrefsResponse>(
        'UpdateNotificationPrefs',
        updateNotificationPrefs_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateNotificationPrefsRequest.fromBuffer(value),
        ($0.UpdateNotificationPrefsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.MarkNotificationOpenedRequest,
            $0.MarkNotificationOpenedResponse>(
        'MarkNotificationOpened',
        markNotificationOpened_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.MarkNotificationOpenedRequest.fromBuffer(value),
        ($0.MarkNotificationOpenedResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CalculateScoreResponse> calculateScore_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CalculateScoreRequest> $request) async {
    return calculateScore($call, await $request);
  }

  $async.Future<$0.CalculateScoreResponse> calculateScore(
      $grpc.ServiceCall call, $0.CalculateScoreRequest request);

  $async.Future<$0.GetLeaderboardResponse> getLeaderboard_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetLeaderboardRequest> $request) async {
    return getLeaderboard($call, await $request);
  }

  $async.Future<$0.GetLeaderboardResponse> getLeaderboard(
      $grpc.ServiceCall call, $0.GetLeaderboardRequest request);

  $async.Future<$0.GetMatchHistoryResponse> getMatchHistory_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetMatchHistoryRequest> $request) async {
    return getMatchHistory($call, await $request);
  }

  $async.Future<$0.GetMatchHistoryResponse> getMatchHistory(
      $grpc.ServiceCall call, $0.GetMatchHistoryRequest request);

  $async.Future<$0.GetHomeScreenDataResponse> getHomeScreenData_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetHomeScreenDataRequest> $request) async {
    return getHomeScreenData($call, await $request);
  }

  $async.Future<$0.GetHomeScreenDataResponse> getHomeScreenData(
      $grpc.ServiceCall call, $0.GetHomeScreenDataRequest request);

  $async.Future<$0.GetReferralDashboardResponse> getReferralDashboard_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetReferralDashboardRequest> $request) async {
    return getReferralDashboard($call, await $request);
  }

  $async.Future<$0.GetReferralDashboardResponse> getReferralDashboard(
      $grpc.ServiceCall call, $0.GetReferralDashboardRequest request);

  $async.Future<$0.ApplyReferralCodeResponse> applyReferralCode_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ApplyReferralCodeRequest> $request) async {
    return applyReferralCode($call, await $request);
  }

  $async.Future<$0.ApplyReferralCodeResponse> applyReferralCode(
      $grpc.ServiceCall call, $0.ApplyReferralCodeRequest request);

  $async.Future<$0.UpdateFCMTokenResponse> updateFCMToken_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateFCMTokenRequest> $request) async {
    return updateFCMToken($call, await $request);
  }

  $async.Future<$0.UpdateFCMTokenResponse> updateFCMToken(
      $grpc.ServiceCall call, $0.UpdateFCMTokenRequest request);

  $async.Future<$0.GetGlobalLeaderboardResponse> getGlobalLeaderboard_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetGlobalLeaderboardRequest> $request) async {
    return getGlobalLeaderboard($call, await $request);
  }

  $async.Future<$0.GetGlobalLeaderboardResponse> getGlobalLeaderboard(
      $grpc.ServiceCall call, $0.GetGlobalLeaderboardRequest request);

  $async.Future<$0.GetCoinBalanceResponse> getCoinBalance_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetCoinBalanceRequest> $request) async {
    return getCoinBalance($call, await $request);
  }

  $async.Future<$0.GetCoinBalanceResponse> getCoinBalance(
      $grpc.ServiceCall call, $0.GetCoinBalanceRequest request);

  $async.Future<$0.GetCoinLedgerResponse> getCoinLedger_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetCoinLedgerRequest> $request) async {
    return getCoinLedger($call, await $request);
  }

  $async.Future<$0.GetCoinLedgerResponse> getCoinLedger(
      $grpc.ServiceCall call, $0.GetCoinLedgerRequest request);

  $async.Future<$0.GetShopCatalogResponse> getShopCatalog_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetShopCatalogRequest> $request) async {
    return getShopCatalog($call, await $request);
  }

  $async.Future<$0.GetShopCatalogResponse> getShopCatalog(
      $grpc.ServiceCall call, $0.GetShopCatalogRequest request);

  $async.Future<$0.GetShopInventoryResponse> getShopInventory_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetShopInventoryRequest> $request) async {
    return getShopInventory($call, await $request);
  }

  $async.Future<$0.GetShopInventoryResponse> getShopInventory(
      $grpc.ServiceCall call, $0.GetShopInventoryRequest request);

  $async.Future<$0.PurchaseShopItemResponse> purchaseShopItem_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.PurchaseShopItemRequest> $request) async {
    return purchaseShopItem($call, await $request);
  }

  $async.Future<$0.PurchaseShopItemResponse> purchaseShopItem(
      $grpc.ServiceCall call, $0.PurchaseShopItemRequest request);

  $async.Future<$0.EquipCosmeticResponse> equipCosmetic_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.EquipCosmeticRequest> $request) async {
    return equipCosmetic($call, await $request);
  }

  $async.Future<$0.EquipCosmeticResponse> equipCosmetic(
      $grpc.ServiceCall call, $0.EquipCosmeticRequest request);

  $async.Future<$0.ConsumeRerollResponse> consumeReroll_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ConsumeRerollRequest> $request) async {
    return consumeReroll($call, await $request);
  }

  $async.Future<$0.ConsumeRerollResponse> consumeReroll(
      $grpc.ServiceCall call, $0.ConsumeRerollRequest request);

  $async.Future<$0.SendFriendRequestResponse> sendFriendRequest_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SendFriendRequestRequest> $request) async {
    return sendFriendRequest($call, await $request);
  }

  $async.Future<$0.SendFriendRequestResponse> sendFriendRequest(
      $grpc.ServiceCall call, $0.SendFriendRequestRequest request);

  $async.Future<$0.RespondToFriendRequestResponse> respondToFriendRequest_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RespondToFriendRequestRequest> $request) async {
    return respondToFriendRequest($call, await $request);
  }

  $async.Future<$0.RespondToFriendRequestResponse> respondToFriendRequest(
      $grpc.ServiceCall call, $0.RespondToFriendRequestRequest request);

  $async.Future<$0.GetFriendsListResponse> getFriendsList_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetFriendsListRequest> $request) async {
    return getFriendsList($call, await $request);
  }

  $async.Future<$0.GetFriendsListResponse> getFriendsList(
      $grpc.ServiceCall call, $0.GetFriendsListRequest request);

  $async.Future<$0.GetFriendRequestsResponse> getFriendRequests_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetFriendRequestsRequest> $request) async {
    return getFriendRequests($call, await $request);
  }

  $async.Future<$0.GetFriendRequestsResponse> getFriendRequests(
      $grpc.ServiceCall call, $0.GetFriendRequestsRequest request);

  $async.Future<$0.HeartbeatResponse> heartbeat_Pre($grpc.ServiceCall $call,
      $async.Future<$0.HeartbeatRequest> $request) async {
    return heartbeat($call, await $request);
  }

  $async.Future<$0.HeartbeatResponse> heartbeat(
      $grpc.ServiceCall call, $0.HeartbeatRequest request);

  $async.Future<$0.ChallengeFriendResponse> challengeFriend_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ChallengeFriendRequest> $request) async {
    return challengeFriend($call, await $request);
  }

  $async.Future<$0.ChallengeFriendResponse> challengeFriend(
      $grpc.ServiceCall call, $0.ChallengeFriendRequest request);

  $async.Future<$0.GetNotificationPrefsResponse> getNotificationPrefs_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetNotificationPrefsRequest> $request) async {
    return getNotificationPrefs($call, await $request);
  }

  $async.Future<$0.GetNotificationPrefsResponse> getNotificationPrefs(
      $grpc.ServiceCall call, $0.GetNotificationPrefsRequest request);

  $async.Future<$0.UpdateNotificationPrefsResponse> updateNotificationPrefs_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateNotificationPrefsRequest> $request) async {
    return updateNotificationPrefs($call, await $request);
  }

  $async.Future<$0.UpdateNotificationPrefsResponse> updateNotificationPrefs(
      $grpc.ServiceCall call, $0.UpdateNotificationPrefsRequest request);

  $async.Future<$0.MarkNotificationOpenedResponse> markNotificationOpened_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.MarkNotificationOpenedRequest> $request) async {
    return markNotificationOpened($call, await $request);
  }

  $async.Future<$0.MarkNotificationOpenedResponse> markNotificationOpened(
      $grpc.ServiceCall call, $0.MarkNotificationOpenedRequest request);
}

@$pb.GrpcServiceName('quiz.AuthService')
class AuthServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AuthServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.AuthResponse> register(
    $0.RegisterRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$register, request, options: options);
  }

  $grpc.ResponseFuture<$0.AuthResponse> login(
    $0.LoginRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$login, request, options: options);
  }

  $grpc.ResponseFuture<$0.ProfileResponse> getProfile(
    $0.GetProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getProfile, request, options: options);
  }

  $grpc.ResponseFuture<$0.AuthResponse> guestLogin(
    $0.GuestLoginRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$guestLogin, request, options: options);
  }

  $grpc.ResponseFuture<$0.SendEmailCodeResponse> loginWithEmail(
    $0.EmailLoginRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$loginWithEmail, request, options: options);
  }

  $grpc.ResponseFuture<$0.SendEmailCodeResponse> sendEmailCode(
    $0.SendEmailCodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sendEmailCode, request, options: options);
  }

  $grpc.ResponseFuture<$0.VerifyEmailCodeResponse> verifyEmailCode(
    $0.VerifyEmailCodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$verifyEmailCode, request, options: options);
  }

  $grpc.ResponseFuture<$0.LinkEmailResponse> linkEmail(
    $0.LinkEmailRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$linkEmail, request, options: options);
  }

  $grpc.ResponseFuture<$0.ResetPasswordResponse> resetPassword(
    $0.ResetPasswordRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$resetPassword, request, options: options);
  }

  $grpc.ResponseFuture<$0.CheckUsernameResponse> checkUsername(
    $0.CheckUsernameRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$checkUsername, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeleteAccountResponse> deleteAccount(
    $0.DeleteAccountRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteAccount, request, options: options);
  }

  /// Phase 2
  $grpc.ResponseFuture<$0.GoogleSignInResponse> googleSignIn(
    $0.GoogleSignInRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$googleSignIn, request, options: options);
  }

  $grpc.ResponseFuture<$0.ClaimDailyRewardResponse> claimDailyReward(
    $0.ClaimDailyRewardRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$claimDailyReward, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetStreakInfoResponse> getStreakInfo(
    $0.GetStreakInfoRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getStreakInfo, request, options: options);
  }

  /// Phase 3
  $grpc.ResponseFuture<$0.UpdateProfileResponse> updateProfile(
    $0.UpdateProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateProfile, request, options: options);
  }

  // method descriptors

  static final _$register =
      $grpc.ClientMethod<$0.RegisterRequest, $0.AuthResponse>(
          '/quiz.AuthService/Register',
          ($0.RegisterRequest value) => value.writeToBuffer(),
          $0.AuthResponse.fromBuffer);
  static final _$login = $grpc.ClientMethod<$0.LoginRequest, $0.AuthResponse>(
      '/quiz.AuthService/Login',
      ($0.LoginRequest value) => value.writeToBuffer(),
      $0.AuthResponse.fromBuffer);
  static final _$getProfile =
      $grpc.ClientMethod<$0.GetProfileRequest, $0.ProfileResponse>(
          '/quiz.AuthService/GetProfile',
          ($0.GetProfileRequest value) => value.writeToBuffer(),
          $0.ProfileResponse.fromBuffer);
  static final _$guestLogin =
      $grpc.ClientMethod<$0.GuestLoginRequest, $0.AuthResponse>(
          '/quiz.AuthService/GuestLogin',
          ($0.GuestLoginRequest value) => value.writeToBuffer(),
          $0.AuthResponse.fromBuffer);
  static final _$loginWithEmail =
      $grpc.ClientMethod<$0.EmailLoginRequest, $0.SendEmailCodeResponse>(
          '/quiz.AuthService/LoginWithEmail',
          ($0.EmailLoginRequest value) => value.writeToBuffer(),
          $0.SendEmailCodeResponse.fromBuffer);
  static final _$sendEmailCode =
      $grpc.ClientMethod<$0.SendEmailCodeRequest, $0.SendEmailCodeResponse>(
          '/quiz.AuthService/SendEmailCode',
          ($0.SendEmailCodeRequest value) => value.writeToBuffer(),
          $0.SendEmailCodeResponse.fromBuffer);
  static final _$verifyEmailCode =
      $grpc.ClientMethod<$0.VerifyEmailCodeRequest, $0.VerifyEmailCodeResponse>(
          '/quiz.AuthService/VerifyEmailCode',
          ($0.VerifyEmailCodeRequest value) => value.writeToBuffer(),
          $0.VerifyEmailCodeResponse.fromBuffer);
  static final _$linkEmail =
      $grpc.ClientMethod<$0.LinkEmailRequest, $0.LinkEmailResponse>(
          '/quiz.AuthService/LinkEmail',
          ($0.LinkEmailRequest value) => value.writeToBuffer(),
          $0.LinkEmailResponse.fromBuffer);
  static final _$resetPassword =
      $grpc.ClientMethod<$0.ResetPasswordRequest, $0.ResetPasswordResponse>(
          '/quiz.AuthService/ResetPassword',
          ($0.ResetPasswordRequest value) => value.writeToBuffer(),
          $0.ResetPasswordResponse.fromBuffer);
  static final _$checkUsername =
      $grpc.ClientMethod<$0.CheckUsernameRequest, $0.CheckUsernameResponse>(
          '/quiz.AuthService/CheckUsername',
          ($0.CheckUsernameRequest value) => value.writeToBuffer(),
          $0.CheckUsernameResponse.fromBuffer);
  static final _$deleteAccount =
      $grpc.ClientMethod<$0.DeleteAccountRequest, $0.DeleteAccountResponse>(
          '/quiz.AuthService/DeleteAccount',
          ($0.DeleteAccountRequest value) => value.writeToBuffer(),
          $0.DeleteAccountResponse.fromBuffer);
  static final _$googleSignIn =
      $grpc.ClientMethod<$0.GoogleSignInRequest, $0.GoogleSignInResponse>(
          '/quiz.AuthService/GoogleSignIn',
          ($0.GoogleSignInRequest value) => value.writeToBuffer(),
          $0.GoogleSignInResponse.fromBuffer);
  static final _$claimDailyReward = $grpc.ClientMethod<
          $0.ClaimDailyRewardRequest, $0.ClaimDailyRewardResponse>(
      '/quiz.AuthService/ClaimDailyReward',
      ($0.ClaimDailyRewardRequest value) => value.writeToBuffer(),
      $0.ClaimDailyRewardResponse.fromBuffer);
  static final _$getStreakInfo =
      $grpc.ClientMethod<$0.GetStreakInfoRequest, $0.GetStreakInfoResponse>(
          '/quiz.AuthService/GetStreakInfo',
          ($0.GetStreakInfoRequest value) => value.writeToBuffer(),
          $0.GetStreakInfoResponse.fromBuffer);
  static final _$updateProfile =
      $grpc.ClientMethod<$0.UpdateProfileRequest, $0.UpdateProfileResponse>(
          '/quiz.AuthService/UpdateProfile',
          ($0.UpdateProfileRequest value) => value.writeToBuffer(),
          $0.UpdateProfileResponse.fromBuffer);
}

@$pb.GrpcServiceName('quiz.AuthService')
abstract class AuthServiceBase extends $grpc.Service {
  $core.String get $name => 'quiz.AuthService';

  AuthServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.RegisterRequest, $0.AuthResponse>(
        'Register',
        register_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RegisterRequest.fromBuffer(value),
        ($0.AuthResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LoginRequest, $0.AuthResponse>(
        'Login',
        login_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.LoginRequest.fromBuffer(value),
        ($0.AuthResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetProfileRequest, $0.ProfileResponse>(
        'GetProfile',
        getProfile_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetProfileRequest.fromBuffer(value),
        ($0.ProfileResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GuestLoginRequest, $0.AuthResponse>(
        'GuestLogin',
        guestLogin_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GuestLoginRequest.fromBuffer(value),
        ($0.AuthResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.EmailLoginRequest, $0.SendEmailCodeResponse>(
            'LoginWithEmail',
            loginWithEmail_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.EmailLoginRequest.fromBuffer(value),
            ($0.SendEmailCodeResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SendEmailCodeRequest, $0.SendEmailCodeResponse>(
            'SendEmailCode',
            sendEmailCode_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SendEmailCodeRequest.fromBuffer(value),
            ($0.SendEmailCodeResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.VerifyEmailCodeRequest,
            $0.VerifyEmailCodeResponse>(
        'VerifyEmailCode',
        verifyEmailCode_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.VerifyEmailCodeRequest.fromBuffer(value),
        ($0.VerifyEmailCodeResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LinkEmailRequest, $0.LinkEmailResponse>(
        'LinkEmail',
        linkEmail_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.LinkEmailRequest.fromBuffer(value),
        ($0.LinkEmailResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ResetPasswordRequest, $0.ResetPasswordResponse>(
            'ResetPassword',
            resetPassword_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ResetPasswordRequest.fromBuffer(value),
            ($0.ResetPasswordResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.CheckUsernameRequest, $0.CheckUsernameResponse>(
            'CheckUsername',
            checkUsername_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CheckUsernameRequest.fromBuffer(value),
            ($0.CheckUsernameResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DeleteAccountRequest, $0.DeleteAccountResponse>(
            'DeleteAccount',
            deleteAccount_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DeleteAccountRequest.fromBuffer(value),
            ($0.DeleteAccountResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GoogleSignInRequest, $0.GoogleSignInResponse>(
            'GoogleSignIn',
            googleSignIn_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GoogleSignInRequest.fromBuffer(value),
            ($0.GoogleSignInResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ClaimDailyRewardRequest,
            $0.ClaimDailyRewardResponse>(
        'ClaimDailyReward',
        claimDailyReward_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ClaimDailyRewardRequest.fromBuffer(value),
        ($0.ClaimDailyRewardResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetStreakInfoRequest, $0.GetStreakInfoResponse>(
            'GetStreakInfo',
            getStreakInfo_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetStreakInfoRequest.fromBuffer(value),
            ($0.GetStreakInfoResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.UpdateProfileRequest, $0.UpdateProfileResponse>(
            'UpdateProfile',
            updateProfile_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.UpdateProfileRequest.fromBuffer(value),
            ($0.UpdateProfileResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.AuthResponse> register_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RegisterRequest> $request) async {
    return register($call, await $request);
  }

  $async.Future<$0.AuthResponse> register(
      $grpc.ServiceCall call, $0.RegisterRequest request);

  $async.Future<$0.AuthResponse> login_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.LoginRequest> $request) async {
    return login($call, await $request);
  }

  $async.Future<$0.AuthResponse> login(
      $grpc.ServiceCall call, $0.LoginRequest request);

  $async.Future<$0.ProfileResponse> getProfile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetProfileRequest> $request) async {
    return getProfile($call, await $request);
  }

  $async.Future<$0.ProfileResponse> getProfile(
      $grpc.ServiceCall call, $0.GetProfileRequest request);

  $async.Future<$0.AuthResponse> guestLogin_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GuestLoginRequest> $request) async {
    return guestLogin($call, await $request);
  }

  $async.Future<$0.AuthResponse> guestLogin(
      $grpc.ServiceCall call, $0.GuestLoginRequest request);

  $async.Future<$0.SendEmailCodeResponse> loginWithEmail_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.EmailLoginRequest> $request) async {
    return loginWithEmail($call, await $request);
  }

  $async.Future<$0.SendEmailCodeResponse> loginWithEmail(
      $grpc.ServiceCall call, $0.EmailLoginRequest request);

  $async.Future<$0.SendEmailCodeResponse> sendEmailCode_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SendEmailCodeRequest> $request) async {
    return sendEmailCode($call, await $request);
  }

  $async.Future<$0.SendEmailCodeResponse> sendEmailCode(
      $grpc.ServiceCall call, $0.SendEmailCodeRequest request);

  $async.Future<$0.VerifyEmailCodeResponse> verifyEmailCode_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.VerifyEmailCodeRequest> $request) async {
    return verifyEmailCode($call, await $request);
  }

  $async.Future<$0.VerifyEmailCodeResponse> verifyEmailCode(
      $grpc.ServiceCall call, $0.VerifyEmailCodeRequest request);

  $async.Future<$0.LinkEmailResponse> linkEmail_Pre($grpc.ServiceCall $call,
      $async.Future<$0.LinkEmailRequest> $request) async {
    return linkEmail($call, await $request);
  }

  $async.Future<$0.LinkEmailResponse> linkEmail(
      $grpc.ServiceCall call, $0.LinkEmailRequest request);

  $async.Future<$0.ResetPasswordResponse> resetPassword_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ResetPasswordRequest> $request) async {
    return resetPassword($call, await $request);
  }

  $async.Future<$0.ResetPasswordResponse> resetPassword(
      $grpc.ServiceCall call, $0.ResetPasswordRequest request);

  $async.Future<$0.CheckUsernameResponse> checkUsername_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CheckUsernameRequest> $request) async {
    return checkUsername($call, await $request);
  }

  $async.Future<$0.CheckUsernameResponse> checkUsername(
      $grpc.ServiceCall call, $0.CheckUsernameRequest request);

  $async.Future<$0.DeleteAccountResponse> deleteAccount_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DeleteAccountRequest> $request) async {
    return deleteAccount($call, await $request);
  }

  $async.Future<$0.DeleteAccountResponse> deleteAccount(
      $grpc.ServiceCall call, $0.DeleteAccountRequest request);

  $async.Future<$0.GoogleSignInResponse> googleSignIn_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GoogleSignInRequest> $request) async {
    return googleSignIn($call, await $request);
  }

  $async.Future<$0.GoogleSignInResponse> googleSignIn(
      $grpc.ServiceCall call, $0.GoogleSignInRequest request);

  $async.Future<$0.ClaimDailyRewardResponse> claimDailyReward_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ClaimDailyRewardRequest> $request) async {
    return claimDailyReward($call, await $request);
  }

  $async.Future<$0.ClaimDailyRewardResponse> claimDailyReward(
      $grpc.ServiceCall call, $0.ClaimDailyRewardRequest request);

  $async.Future<$0.GetStreakInfoResponse> getStreakInfo_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetStreakInfoRequest> $request) async {
    return getStreakInfo($call, await $request);
  }

  $async.Future<$0.GetStreakInfoResponse> getStreakInfo(
      $grpc.ServiceCall call, $0.GetStreakInfoRequest request);

  $async.Future<$0.UpdateProfileResponse> updateProfile_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateProfileRequest> $request) async {
    return updateProfile($call, await $request);
  }

  $async.Future<$0.UpdateProfileResponse> updateProfile(
      $grpc.ServiceCall call, $0.UpdateProfileRequest request);
}

@$pb.GrpcServiceName('quiz.PaymentService')
class PaymentServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  PaymentServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.CreateOrderResponse> createOrder(
    $0.CreateOrderRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createOrder, request, options: options);
  }

  /// Client-side signature verification — Flutter calls this with the
  /// (paymentId, orderId, signature) triple from the Razorpay SDK
  /// success callback. Activates premium synchronously without waiting
  /// on the webhook (which needs ngrok in dev). Idempotent: repeat
  /// calls with the same paymentId are no-ops.
  $grpc.ResponseFuture<$0.VerifyPaymentResponse> verifyPayment(
    $0.VerifyPaymentRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$verifyPayment, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetPlanStatusResponse> getPlanStatus(
    $0.GetPlanStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPlanStatus, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetPaymentHistoryResponse> getPaymentHistory(
    $0.GetPaymentHistoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPaymentHistory, request, options: options);
  }

  // method descriptors

  static final _$createOrder =
      $grpc.ClientMethod<$0.CreateOrderRequest, $0.CreateOrderResponse>(
          '/quiz.PaymentService/CreateOrder',
          ($0.CreateOrderRequest value) => value.writeToBuffer(),
          $0.CreateOrderResponse.fromBuffer);
  static final _$verifyPayment =
      $grpc.ClientMethod<$0.VerifyPaymentRequest, $0.VerifyPaymentResponse>(
          '/quiz.PaymentService/VerifyPayment',
          ($0.VerifyPaymentRequest value) => value.writeToBuffer(),
          $0.VerifyPaymentResponse.fromBuffer);
  static final _$getPlanStatus =
      $grpc.ClientMethod<$0.GetPlanStatusRequest, $0.GetPlanStatusResponse>(
          '/quiz.PaymentService/GetPlanStatus',
          ($0.GetPlanStatusRequest value) => value.writeToBuffer(),
          $0.GetPlanStatusResponse.fromBuffer);
  static final _$getPaymentHistory = $grpc.ClientMethod<
          $0.GetPaymentHistoryRequest, $0.GetPaymentHistoryResponse>(
      '/quiz.PaymentService/GetPaymentHistory',
      ($0.GetPaymentHistoryRequest value) => value.writeToBuffer(),
      $0.GetPaymentHistoryResponse.fromBuffer);
}

@$pb.GrpcServiceName('quiz.PaymentService')
abstract class PaymentServiceBase extends $grpc.Service {
  $core.String get $name => 'quiz.PaymentService';

  PaymentServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.CreateOrderRequest, $0.CreateOrderResponse>(
            'CreateOrder',
            createOrder_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CreateOrderRequest.fromBuffer(value),
            ($0.CreateOrderResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.VerifyPaymentRequest, $0.VerifyPaymentResponse>(
            'VerifyPayment',
            verifyPayment_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.VerifyPaymentRequest.fromBuffer(value),
            ($0.VerifyPaymentResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetPlanStatusRequest, $0.GetPlanStatusResponse>(
            'GetPlanStatus',
            getPlanStatus_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetPlanStatusRequest.fromBuffer(value),
            ($0.GetPlanStatusResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetPaymentHistoryRequest,
            $0.GetPaymentHistoryResponse>(
        'GetPaymentHistory',
        getPaymentHistory_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetPaymentHistoryRequest.fromBuffer(value),
        ($0.GetPaymentHistoryResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CreateOrderResponse> createOrder_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateOrderRequest> $request) async {
    return createOrder($call, await $request);
  }

  $async.Future<$0.CreateOrderResponse> createOrder(
      $grpc.ServiceCall call, $0.CreateOrderRequest request);

  $async.Future<$0.VerifyPaymentResponse> verifyPayment_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.VerifyPaymentRequest> $request) async {
    return verifyPayment($call, await $request);
  }

  $async.Future<$0.VerifyPaymentResponse> verifyPayment(
      $grpc.ServiceCall call, $0.VerifyPaymentRequest request);

  $async.Future<$0.GetPlanStatusResponse> getPlanStatus_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetPlanStatusRequest> $request) async {
    return getPlanStatus($call, await $request);
  }

  $async.Future<$0.GetPlanStatusResponse> getPlanStatus(
      $grpc.ServiceCall call, $0.GetPlanStatusRequest request);

  $async.Future<$0.GetPaymentHistoryResponse> getPaymentHistory_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetPaymentHistoryRequest> $request) async {
    return getPaymentHistory($call, await $request);
  }

  $async.Future<$0.GetPaymentHistoryResponse> getPaymentHistory(
      $grpc.ServiceCall call, $0.GetPaymentHistoryRequest request);
}
