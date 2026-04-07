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
}
