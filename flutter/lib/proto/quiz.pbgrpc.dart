// This is a generated file - do not edit.
//
// Generated from proto/quiz.proto.

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
}
