// This is a generated file - do not edit.
//
// Generated from proto/quiz.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'quiz.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'quiz.pbenum.dart';

class JoinMatchmakingRequest extends $pb.GeneratedMessage {
  factory JoinMatchmakingRequest({
    $core.String? userId,
    $core.int? rating,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (rating != null) result.rating = rating;
    return result;
  }

  JoinMatchmakingRequest._();

  factory JoinMatchmakingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinMatchmakingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinMatchmakingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aI(2, _omitFieldNames ? '' : 'rating')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinMatchmakingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinMatchmakingRequest copyWith(
          void Function(JoinMatchmakingRequest) updates) =>
      super.copyWith((message) => updates(message as JoinMatchmakingRequest))
          as JoinMatchmakingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinMatchmakingRequest create() => JoinMatchmakingRequest._();
  @$core.override
  JoinMatchmakingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinMatchmakingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinMatchmakingRequest>(create);
  static JoinMatchmakingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get rating => $_getIZ(1);
  @$pb.TagNumber(2)
  set rating($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRating() => $_has(1);
  @$pb.TagNumber(2)
  void clearRating() => $_clearField(2);
}

class JoinMatchmakingResponse extends $pb.GeneratedMessage {
  factory JoinMatchmakingResponse({
    MatchmakingStatus? status,
  }) {
    final result = create();
    if (status != null) result.status = status;
    return result;
  }

  JoinMatchmakingResponse._();

  factory JoinMatchmakingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinMatchmakingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinMatchmakingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aE<MatchmakingStatus>(1, _omitFieldNames ? '' : 'status',
        enumValues: MatchmakingStatus.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinMatchmakingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinMatchmakingResponse copyWith(
          void Function(JoinMatchmakingResponse) updates) =>
      super.copyWith((message) => updates(message as JoinMatchmakingResponse))
          as JoinMatchmakingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinMatchmakingResponse create() => JoinMatchmakingResponse._();
  @$core.override
  JoinMatchmakingResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinMatchmakingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinMatchmakingResponse>(create);
  static JoinMatchmakingResponse? _defaultInstance;

  @$pb.TagNumber(1)
  MatchmakingStatus get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(MatchmakingStatus value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);
}

class LeaveMatchmakingRequest extends $pb.GeneratedMessage {
  factory LeaveMatchmakingRequest({
    $core.String? userId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    return result;
  }

  LeaveMatchmakingRequest._();

  factory LeaveMatchmakingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LeaveMatchmakingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LeaveMatchmakingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveMatchmakingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveMatchmakingRequest copyWith(
          void Function(LeaveMatchmakingRequest) updates) =>
      super.copyWith((message) => updates(message as LeaveMatchmakingRequest))
          as LeaveMatchmakingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaveMatchmakingRequest create() => LeaveMatchmakingRequest._();
  @$core.override
  LeaveMatchmakingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LeaveMatchmakingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LeaveMatchmakingRequest>(create);
  static LeaveMatchmakingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);
}

class LeaveMatchmakingResponse extends $pb.GeneratedMessage {
  factory LeaveMatchmakingResponse({
    $core.bool? removed,
  }) {
    final result = create();
    if (removed != null) result.removed = removed;
    return result;
  }

  LeaveMatchmakingResponse._();

  factory LeaveMatchmakingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LeaveMatchmakingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LeaveMatchmakingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'removed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveMatchmakingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveMatchmakingResponse copyWith(
          void Function(LeaveMatchmakingResponse) updates) =>
      super.copyWith((message) => updates(message as LeaveMatchmakingResponse))
          as LeaveMatchmakingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaveMatchmakingResponse create() => LeaveMatchmakingResponse._();
  @$core.override
  LeaveMatchmakingResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LeaveMatchmakingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LeaveMatchmakingResponse>(create);
  static LeaveMatchmakingResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get removed => $_getBF(0);
  @$pb.TagNumber(1)
  set removed($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRemoved() => $_has(0);
  @$pb.TagNumber(1)
  void clearRemoved() => $_clearField(1);
}

class SubscribeToMatchRequest extends $pb.GeneratedMessage {
  factory SubscribeToMatchRequest({
    $core.String? userId,
    $fixnum.Int64? sequenceNumber,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (sequenceNumber != null) result.sequenceNumber = sequenceNumber;
    return result;
  }

  SubscribeToMatchRequest._();

  factory SubscribeToMatchRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubscribeToMatchRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubscribeToMatchRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aInt64(2, _omitFieldNames ? '' : 'sequenceNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeToMatchRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeToMatchRequest copyWith(
          void Function(SubscribeToMatchRequest) updates) =>
      super.copyWith((message) => updates(message as SubscribeToMatchRequest))
          as SubscribeToMatchRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubscribeToMatchRequest create() => SubscribeToMatchRequest._();
  @$core.override
  SubscribeToMatchRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubscribeToMatchRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubscribeToMatchRequest>(create);
  static SubscribeToMatchRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sequenceNumber => $_getI64(1);
  @$pb.TagNumber(2)
  set sequenceNumber($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSequenceNumber() => $_has(1);
  @$pb.TagNumber(2)
  void clearSequenceNumber() => $_clearField(2);
}

class MatchEvent extends $pb.GeneratedMessage {
  factory MatchEvent({
    $core.String? roomId,
    $core.Iterable<$core.String>? players,
    $fixnum.Int64? sequenceNumber,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (players != null) result.players.addAll(players);
    if (sequenceNumber != null) result.sequenceNumber = sequenceNumber;
    return result;
  }

  MatchEvent._();

  factory MatchEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MatchEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MatchEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..pPS(2, _omitFieldNames ? '' : 'players')
    ..aInt64(3, _omitFieldNames ? '' : 'sequenceNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MatchEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MatchEvent copyWith(void Function(MatchEvent) updates) =>
      super.copyWith((message) => updates(message as MatchEvent)) as MatchEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchEvent create() => MatchEvent._();
  @$core.override
  MatchEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MatchEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MatchEvent>(create);
  static MatchEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get players => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get sequenceNumber => $_getI64(2);
  @$pb.TagNumber(3)
  set sequenceNumber($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSequenceNumber() => $_has(2);
  @$pb.TagNumber(3)
  void clearSequenceNumber() => $_clearField(3);
}

class GetRoomQuestionsRequest extends $pb.GeneratedMessage {
  factory GetRoomQuestionsRequest({
    $core.String? roomId,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    return result;
  }

  GetRoomQuestionsRequest._();

  factory GetRoomQuestionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetRoomQuestionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetRoomQuestionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRoomQuestionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRoomQuestionsRequest copyWith(
          void Function(GetRoomQuestionsRequest) updates) =>
      super.copyWith((message) => updates(message as GetRoomQuestionsRequest))
          as GetRoomQuestionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetRoomQuestionsRequest create() => GetRoomQuestionsRequest._();
  @$core.override
  GetRoomQuestionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetRoomQuestionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetRoomQuestionsRequest>(create);
  static GetRoomQuestionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);
}

class GetRoomQuestionsResponse extends $pb.GeneratedMessage {
  factory GetRoomQuestionsResponse({
    $core.Iterable<Question>? questions,
  }) {
    final result = create();
    if (questions != null) result.questions.addAll(questions);
    return result;
  }

  GetRoomQuestionsResponse._();

  factory GetRoomQuestionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetRoomQuestionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetRoomQuestionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..pPM<Question>(1, _omitFieldNames ? '' : 'questions',
        subBuilder: Question.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRoomQuestionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRoomQuestionsResponse copyWith(
          void Function(GetRoomQuestionsResponse) updates) =>
      super.copyWith((message) => updates(message as GetRoomQuestionsResponse))
          as GetRoomQuestionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetRoomQuestionsResponse create() => GetRoomQuestionsResponse._();
  @$core.override
  GetRoomQuestionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetRoomQuestionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetRoomQuestionsResponse>(create);
  static GetRoomQuestionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Question> get questions => $_getList(0);
}

class Question extends $pb.GeneratedMessage {
  factory Question({
    $core.String? id,
    $core.String? text,
    $core.Iterable<$core.String>? options,
    $core.String? difficulty,
    $core.String? topic,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (text != null) result.text = text;
    if (options != null) result.options.addAll(options);
    if (difficulty != null) result.difficulty = difficulty;
    if (topic != null) result.topic = topic;
    return result;
  }

  Question._();

  factory Question.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Question.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Question',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..pPS(3, _omitFieldNames ? '' : 'options')
    ..aOS(4, _omitFieldNames ? '' : 'difficulty')
    ..aOS(5, _omitFieldNames ? '' : 'topic')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Question clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Question copyWith(void Function(Question) updates) =>
      super.copyWith((message) => updates(message as Question)) as Question;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Question create() => Question._();
  @$core.override
  Question createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Question getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Question>(create);
  static Question? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get options => $_getList(2);

  @$pb.TagNumber(4)
  $core.String get difficulty => $_getSZ(3);
  @$pb.TagNumber(4)
  set difficulty($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDifficulty() => $_has(3);
  @$pb.TagNumber(4)
  void clearDifficulty() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get topic => $_getSZ(4);
  @$pb.TagNumber(5)
  set topic($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTopic() => $_has(4);
  @$pb.TagNumber(5)
  void clearTopic() => $_clearField(5);
}

class SubmitAnswerRequest extends $pb.GeneratedMessage {
  factory SubmitAnswerRequest({
    $core.String? roomId,
    $core.String? userId,
    $core.int? round,
    $core.int? optionIndex,
    $fixnum.Int64? clientTimestamp,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (userId != null) result.userId = userId;
    if (round != null) result.round = round;
    if (optionIndex != null) result.optionIndex = optionIndex;
    if (clientTimestamp != null) result.clientTimestamp = clientTimestamp;
    return result;
  }

  SubmitAnswerRequest._();

  factory SubmitAnswerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubmitAnswerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubmitAnswerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aI(3, _omitFieldNames ? '' : 'round')
    ..aI(4, _omitFieldNames ? '' : 'optionIndex')
    ..aInt64(5, _omitFieldNames ? '' : 'clientTimestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitAnswerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitAnswerRequest copyWith(void Function(SubmitAnswerRequest) updates) =>
      super.copyWith((message) => updates(message as SubmitAnswerRequest))
          as SubmitAnswerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubmitAnswerRequest create() => SubmitAnswerRequest._();
  @$core.override
  SubmitAnswerRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubmitAnswerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubmitAnswerRequest>(create);
  static SubmitAnswerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get round => $_getIZ(2);
  @$pb.TagNumber(3)
  set round($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRound() => $_has(2);
  @$pb.TagNumber(3)
  void clearRound() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get optionIndex => $_getIZ(3);
  @$pb.TagNumber(4)
  set optionIndex($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOptionIndex() => $_has(3);
  @$pb.TagNumber(4)
  void clearOptionIndex() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get clientTimestamp => $_getI64(4);
  @$pb.TagNumber(5)
  set clientTimestamp($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasClientTimestamp() => $_has(4);
  @$pb.TagNumber(5)
  void clearClientTimestamp() => $_clearField(5);
}

class SubmitAnswerResponse extends $pb.GeneratedMessage {
  factory SubmitAnswerResponse({
    $core.bool? accepted,
  }) {
    final result = create();
    if (accepted != null) result.accepted = accepted;
    return result;
  }

  SubmitAnswerResponse._();

  factory SubmitAnswerResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubmitAnswerResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubmitAnswerResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitAnswerResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitAnswerResponse copyWith(void Function(SubmitAnswerResponse) updates) =>
      super.copyWith((message) => updates(message as SubmitAnswerResponse))
          as SubmitAnswerResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubmitAnswerResponse create() => SubmitAnswerResponse._();
  @$core.override
  SubmitAnswerResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubmitAnswerResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubmitAnswerResponse>(create);
  static SubmitAnswerResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get accepted => $_getBF(0);
  @$pb.TagNumber(1)
  set accepted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);
}

class StreamGameEventsRequest extends $pb.GeneratedMessage {
  factory StreamGameEventsRequest({
    $core.String? roomId,
    $core.String? userId,
    $fixnum.Int64? sequenceNumber,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (userId != null) result.userId = userId;
    if (sequenceNumber != null) result.sequenceNumber = sequenceNumber;
    return result;
  }

  StreamGameEventsRequest._();

  factory StreamGameEventsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamGameEventsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamGameEventsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aInt64(3, _omitFieldNames ? '' : 'sequenceNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamGameEventsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamGameEventsRequest copyWith(
          void Function(StreamGameEventsRequest) updates) =>
      super.copyWith((message) => updates(message as StreamGameEventsRequest))
          as StreamGameEventsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamGameEventsRequest create() => StreamGameEventsRequest._();
  @$core.override
  StreamGameEventsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamGameEventsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamGameEventsRequest>(create);
  static StreamGameEventsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get sequenceNumber => $_getI64(2);
  @$pb.TagNumber(3)
  set sequenceNumber($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSequenceNumber() => $_has(2);
  @$pb.TagNumber(3)
  void clearSequenceNumber() => $_clearField(3);
}

enum GameEvent_Event {
  question,
  leaderboard,
  roundResult,
  matchEnd,
  playerJoined,
  timerSync,
  notSet
}

class GameEvent extends $pb.GeneratedMessage {
  factory GameEvent({
    QuestionBroadcast? question,
    LeaderboardUpdate? leaderboard,
    RoundResult? roundResult,
    MatchEnd? matchEnd,
    PlayerJoined? playerJoined,
    TimerSync? timerSync,
    $fixnum.Int64? sequenceNumber,
  }) {
    final result = create();
    if (question != null) result.question = question;
    if (leaderboard != null) result.leaderboard = leaderboard;
    if (roundResult != null) result.roundResult = roundResult;
    if (matchEnd != null) result.matchEnd = matchEnd;
    if (playerJoined != null) result.playerJoined = playerJoined;
    if (timerSync != null) result.timerSync = timerSync;
    if (sequenceNumber != null) result.sequenceNumber = sequenceNumber;
    return result;
  }

  GameEvent._();

  factory GameEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GameEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, GameEvent_Event> _GameEvent_EventByTag = {
    1: GameEvent_Event.question,
    2: GameEvent_Event.leaderboard,
    3: GameEvent_Event.roundResult,
    4: GameEvent_Event.matchEnd,
    5: GameEvent_Event.playerJoined,
    6: GameEvent_Event.timerSync,
    0: GameEvent_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GameEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6])
    ..aOM<QuestionBroadcast>(1, _omitFieldNames ? '' : 'question',
        subBuilder: QuestionBroadcast.create)
    ..aOM<LeaderboardUpdate>(2, _omitFieldNames ? '' : 'leaderboard',
        subBuilder: LeaderboardUpdate.create)
    ..aOM<RoundResult>(3, _omitFieldNames ? '' : 'roundResult',
        subBuilder: RoundResult.create)
    ..aOM<MatchEnd>(4, _omitFieldNames ? '' : 'matchEnd',
        subBuilder: MatchEnd.create)
    ..aOM<PlayerJoined>(5, _omitFieldNames ? '' : 'playerJoined',
        subBuilder: PlayerJoined.create)
    ..aOM<TimerSync>(6, _omitFieldNames ? '' : 'timerSync',
        subBuilder: TimerSync.create)
    ..aInt64(7, _omitFieldNames ? '' : 'sequenceNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GameEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GameEvent copyWith(void Function(GameEvent) updates) =>
      super.copyWith((message) => updates(message as GameEvent)) as GameEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GameEvent create() => GameEvent._();
  @$core.override
  GameEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GameEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GameEvent>(create);
  static GameEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  GameEvent_Event whichEvent() => _GameEvent_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  QuestionBroadcast get question => $_getN(0);
  @$pb.TagNumber(1)
  set question(QuestionBroadcast value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestion() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestion() => $_clearField(1);
  @$pb.TagNumber(1)
  QuestionBroadcast ensureQuestion() => $_ensure(0);

  @$pb.TagNumber(2)
  LeaderboardUpdate get leaderboard => $_getN(1);
  @$pb.TagNumber(2)
  set leaderboard(LeaderboardUpdate value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasLeaderboard() => $_has(1);
  @$pb.TagNumber(2)
  void clearLeaderboard() => $_clearField(2);
  @$pb.TagNumber(2)
  LeaderboardUpdate ensureLeaderboard() => $_ensure(1);

  @$pb.TagNumber(3)
  RoundResult get roundResult => $_getN(2);
  @$pb.TagNumber(3)
  set roundResult(RoundResult value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRoundResult() => $_has(2);
  @$pb.TagNumber(3)
  void clearRoundResult() => $_clearField(3);
  @$pb.TagNumber(3)
  RoundResult ensureRoundResult() => $_ensure(2);

  @$pb.TagNumber(4)
  MatchEnd get matchEnd => $_getN(3);
  @$pb.TagNumber(4)
  set matchEnd(MatchEnd value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasMatchEnd() => $_has(3);
  @$pb.TagNumber(4)
  void clearMatchEnd() => $_clearField(4);
  @$pb.TagNumber(4)
  MatchEnd ensureMatchEnd() => $_ensure(3);

  @$pb.TagNumber(5)
  PlayerJoined get playerJoined => $_getN(4);
  @$pb.TagNumber(5)
  set playerJoined(PlayerJoined value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPlayerJoined() => $_has(4);
  @$pb.TagNumber(5)
  void clearPlayerJoined() => $_clearField(5);
  @$pb.TagNumber(5)
  PlayerJoined ensurePlayerJoined() => $_ensure(4);

  @$pb.TagNumber(6)
  TimerSync get timerSync => $_getN(5);
  @$pb.TagNumber(6)
  set timerSync(TimerSync value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasTimerSync() => $_has(5);
  @$pb.TagNumber(6)
  void clearTimerSync() => $_clearField(6);
  @$pb.TagNumber(6)
  TimerSync ensureTimerSync() => $_ensure(5);

  @$pb.TagNumber(7)
  $fixnum.Int64 get sequenceNumber => $_getI64(6);
  @$pb.TagNumber(7)
  set sequenceNumber($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSequenceNumber() => $_has(6);
  @$pb.TagNumber(7)
  void clearSequenceNumber() => $_clearField(7);
}

class QuestionBroadcast extends $pb.GeneratedMessage {
  factory QuestionBroadcast({
    $core.String? questionId,
    $core.String? text,
    $core.Iterable<$core.String>? options,
    $fixnum.Int64? deadlineUnix,
    $core.int? round,
  }) {
    final result = create();
    if (questionId != null) result.questionId = questionId;
    if (text != null) result.text = text;
    if (options != null) result.options.addAll(options);
    if (deadlineUnix != null) result.deadlineUnix = deadlineUnix;
    if (round != null) result.round = round;
    return result;
  }

  QuestionBroadcast._();

  factory QuestionBroadcast.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QuestionBroadcast.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QuestionBroadcast',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'questionId')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..pPS(3, _omitFieldNames ? '' : 'options')
    ..aInt64(4, _omitFieldNames ? '' : 'deadlineUnix')
    ..aI(5, _omitFieldNames ? '' : 'round')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuestionBroadcast clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuestionBroadcast copyWith(void Function(QuestionBroadcast) updates) =>
      super.copyWith((message) => updates(message as QuestionBroadcast))
          as QuestionBroadcast;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuestionBroadcast create() => QuestionBroadcast._();
  @$core.override
  QuestionBroadcast createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QuestionBroadcast getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QuestionBroadcast>(create);
  static QuestionBroadcast? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get questionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set questionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get options => $_getList(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get deadlineUnix => $_getI64(3);
  @$pb.TagNumber(4)
  set deadlineUnix($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeadlineUnix() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeadlineUnix() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get round => $_getIZ(4);
  @$pb.TagNumber(5)
  set round($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRound() => $_has(4);
  @$pb.TagNumber(5)
  void clearRound() => $_clearField(5);
}

class LeaderboardUpdate extends $pb.GeneratedMessage {
  factory LeaderboardUpdate({
    $core.Iterable<LeaderboardEntry>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addAll(entries);
    return result;
  }

  LeaderboardUpdate._();

  factory LeaderboardUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LeaderboardUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LeaderboardUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..pPM<LeaderboardEntry>(1, _omitFieldNames ? '' : 'entries',
        subBuilder: LeaderboardEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaderboardUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaderboardUpdate copyWith(void Function(LeaderboardUpdate) updates) =>
      super.copyWith((message) => updates(message as LeaderboardUpdate))
          as LeaderboardUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaderboardUpdate create() => LeaderboardUpdate._();
  @$core.override
  LeaderboardUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LeaderboardUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LeaderboardUpdate>(create);
  static LeaderboardUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<LeaderboardEntry> get entries => $_getList(0);
}

class LeaderboardEntry extends $pb.GeneratedMessage {
  factory LeaderboardEntry({
    $core.String? userId,
    $core.String? username,
    $core.double? score,
    $core.int? rank,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (username != null) result.username = username;
    if (score != null) result.score = score;
    if (rank != null) result.rank = rank;
    return result;
  }

  LeaderboardEntry._();

  factory LeaderboardEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LeaderboardEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LeaderboardEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'username')
    ..aD(3, _omitFieldNames ? '' : 'score')
    ..aI(4, _omitFieldNames ? '' : 'rank')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaderboardEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaderboardEntry copyWith(void Function(LeaderboardEntry) updates) =>
      super.copyWith((message) => updates(message as LeaderboardEntry))
          as LeaderboardEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaderboardEntry create() => LeaderboardEntry._();
  @$core.override
  LeaderboardEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LeaderboardEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LeaderboardEntry>(create);
  static LeaderboardEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get username => $_getSZ(1);
  @$pb.TagNumber(2)
  set username($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUsername() => $_has(1);
  @$pb.TagNumber(2)
  void clearUsername() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get score => $_getN(2);
  @$pb.TagNumber(3)
  set score($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasScore() => $_has(2);
  @$pb.TagNumber(3)
  void clearScore() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get rank => $_getIZ(3);
  @$pb.TagNumber(4)
  set rank($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRank() => $_has(3);
  @$pb.TagNumber(4)
  void clearRank() => $_clearField(4);
}

class RoundResult extends $pb.GeneratedMessage {
  factory RoundResult({
    $core.int? round,
    $core.int? correctIndex,
  }) {
    final result = create();
    if (round != null) result.round = round;
    if (correctIndex != null) result.correctIndex = correctIndex;
    return result;
  }

  RoundResult._();

  factory RoundResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RoundResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RoundResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'round')
    ..aI(2, _omitFieldNames ? '' : 'correctIndex')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoundResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoundResult copyWith(void Function(RoundResult) updates) =>
      super.copyWith((message) => updates(message as RoundResult))
          as RoundResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoundResult create() => RoundResult._();
  @$core.override
  RoundResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RoundResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RoundResult>(create);
  static RoundResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get round => $_getIZ(0);
  @$pb.TagNumber(1)
  set round($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRound() => $_has(0);
  @$pb.TagNumber(1)
  void clearRound() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get correctIndex => $_getIZ(1);
  @$pb.TagNumber(2)
  set correctIndex($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCorrectIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearCorrectIndex() => $_clearField(2);
}

class MatchEnd extends $pb.GeneratedMessage {
  factory MatchEnd({
    $core.String? roomId,
    $core.String? winner,
    $core.Iterable<PlayerResult>? players,
    $core.int? rounds,
    $fixnum.Int64? duration,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (winner != null) result.winner = winner;
    if (players != null) result.players.addAll(players);
    if (rounds != null) result.rounds = rounds;
    if (duration != null) result.duration = duration;
    return result;
  }

  MatchEnd._();

  factory MatchEnd.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MatchEnd.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MatchEnd',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'winner')
    ..pPM<PlayerResult>(3, _omitFieldNames ? '' : 'players',
        subBuilder: PlayerResult.create)
    ..aI(4, _omitFieldNames ? '' : 'rounds')
    ..aInt64(5, _omitFieldNames ? '' : 'duration')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MatchEnd clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MatchEnd copyWith(void Function(MatchEnd) updates) =>
      super.copyWith((message) => updates(message as MatchEnd)) as MatchEnd;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchEnd create() => MatchEnd._();
  @$core.override
  MatchEnd createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MatchEnd getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchEnd>(create);
  static MatchEnd? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get winner => $_getSZ(1);
  @$pb.TagNumber(2)
  set winner($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWinner() => $_has(1);
  @$pb.TagNumber(2)
  void clearWinner() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<PlayerResult> get players => $_getList(2);

  @$pb.TagNumber(4)
  $core.int get rounds => $_getIZ(3);
  @$pb.TagNumber(4)
  set rounds($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRounds() => $_has(3);
  @$pb.TagNumber(4)
  void clearRounds() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get duration => $_getI64(4);
  @$pb.TagNumber(5)
  set duration($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDuration() => $_has(4);
  @$pb.TagNumber(5)
  void clearDuration() => $_clearField(5);
}

class PlayerResult extends $pb.GeneratedMessage {
  factory PlayerResult({
    $core.String? userId,
    $core.String? username,
    $core.double? finalScore,
    $core.int? rank,
    $core.int? answersCorrect,
    $core.double? avgResponseTimeMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (username != null) result.username = username;
    if (finalScore != null) result.finalScore = finalScore;
    if (rank != null) result.rank = rank;
    if (answersCorrect != null) result.answersCorrect = answersCorrect;
    if (avgResponseTimeMs != null) result.avgResponseTimeMs = avgResponseTimeMs;
    return result;
  }

  PlayerResult._();

  factory PlayerResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlayerResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayerResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'username')
    ..aD(3, _omitFieldNames ? '' : 'finalScore')
    ..aI(4, _omitFieldNames ? '' : 'rank')
    ..aI(5, _omitFieldNames ? '' : 'answersCorrect')
    ..aD(6, _omitFieldNames ? '' : 'avgResponseTimeMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerResult copyWith(void Function(PlayerResult) updates) =>
      super.copyWith((message) => updates(message as PlayerResult))
          as PlayerResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayerResult create() => PlayerResult._();
  @$core.override
  PlayerResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlayerResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayerResult>(create);
  static PlayerResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get username => $_getSZ(1);
  @$pb.TagNumber(2)
  set username($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUsername() => $_has(1);
  @$pb.TagNumber(2)
  void clearUsername() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get finalScore => $_getN(2);
  @$pb.TagNumber(3)
  set finalScore($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFinalScore() => $_has(2);
  @$pb.TagNumber(3)
  void clearFinalScore() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get rank => $_getIZ(3);
  @$pb.TagNumber(4)
  set rank($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRank() => $_has(3);
  @$pb.TagNumber(4)
  void clearRank() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get answersCorrect => $_getIZ(4);
  @$pb.TagNumber(5)
  set answersCorrect($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAnswersCorrect() => $_has(4);
  @$pb.TagNumber(5)
  void clearAnswersCorrect() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get avgResponseTimeMs => $_getN(5);
  @$pb.TagNumber(6)
  set avgResponseTimeMs($core.double value) => $_setDouble(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAvgResponseTimeMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearAvgResponseTimeMs() => $_clearField(6);
}

class PlayerJoined extends $pb.GeneratedMessage {
  factory PlayerJoined({
    $core.String? userId,
    $core.String? username,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (username != null) result.username = username;
    return result;
  }

  PlayerJoined._();

  factory PlayerJoined.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlayerJoined.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayerJoined',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'username')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerJoined clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerJoined copyWith(void Function(PlayerJoined) updates) =>
      super.copyWith((message) => updates(message as PlayerJoined))
          as PlayerJoined;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayerJoined create() => PlayerJoined._();
  @$core.override
  PlayerJoined createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlayerJoined getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayerJoined>(create);
  static PlayerJoined? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get username => $_getSZ(1);
  @$pb.TagNumber(2)
  set username($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUsername() => $_has(1);
  @$pb.TagNumber(2)
  void clearUsername() => $_clearField(2);
}

class TimerSync extends $pb.GeneratedMessage {
  factory TimerSync({
    $fixnum.Int64? deadlineUnix,
  }) {
    final result = create();
    if (deadlineUnix != null) result.deadlineUnix = deadlineUnix;
    return result;
  }

  TimerSync._();

  factory TimerSync.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TimerSync.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TimerSync',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'deadlineUnix')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimerSync clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimerSync copyWith(void Function(TimerSync) updates) =>
      super.copyWith((message) => updates(message as TimerSync)) as TimerSync;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TimerSync create() => TimerSync._();
  @$core.override
  TimerSync createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TimerSync getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TimerSync>(create);
  static TimerSync? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get deadlineUnix => $_getI64(0);
  @$pb.TagNumber(1)
  set deadlineUnix($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeadlineUnix() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeadlineUnix() => $_clearField(1);
}

class RegisterRequest extends $pb.GeneratedMessage {
  factory RegisterRequest({
    $core.String? username,
    $core.String? password,
    $core.String? email,
  }) {
    final result = create();
    if (username != null) result.username = username;
    if (password != null) result.password = password;
    if (email != null) result.email = email;
    return result;
  }

  RegisterRequest._();

  factory RegisterRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..aOS(2, _omitFieldNames ? '' : 'password')
    ..aOS(3, _omitFieldNames ? '' : 'email')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterRequest copyWith(void Function(RegisterRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterRequest))
          as RegisterRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterRequest create() => RegisterRequest._();
  @$core.override
  RegisterRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterRequest>(create);
  static RegisterRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get password => $_getSZ(1);
  @$pb.TagNumber(2)
  set password($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPassword() => $_has(1);
  @$pb.TagNumber(2)
  void clearPassword() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get email => $_getSZ(2);
  @$pb.TagNumber(3)
  set email($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEmail() => $_has(2);
  @$pb.TagNumber(3)
  void clearEmail() => $_clearField(3);
}

class LoginRequest extends $pb.GeneratedMessage {
  factory LoginRequest({
    $core.String? username,
    $core.String? password,
  }) {
    final result = create();
    if (username != null) result.username = username;
    if (password != null) result.password = password;
    return result;
  }

  LoginRequest._();

  factory LoginRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoginRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..aOS(2, _omitFieldNames ? '' : 'password')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginRequest copyWith(void Function(LoginRequest) updates) =>
      super.copyWith((message) => updates(message as LoginRequest))
          as LoginRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginRequest create() => LoginRequest._();
  @$core.override
  LoginRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoginRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginRequest>(create);
  static LoginRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get password => $_getSZ(1);
  @$pb.TagNumber(2)
  set password($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPassword() => $_has(1);
  @$pb.TagNumber(2)
  void clearPassword() => $_clearField(2);
}

class AuthResponse extends $pb.GeneratedMessage {
  factory AuthResponse({
    $core.String? userId,
    $core.String? username,
    $core.String? token,
    $core.int? rating,
    $core.int? matchesPlayed,
    $core.int? wins,
    $core.String? email,
    $core.bool? isGuest,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (username != null) result.username = username;
    if (token != null) result.token = token;
    if (rating != null) result.rating = rating;
    if (matchesPlayed != null) result.matchesPlayed = matchesPlayed;
    if (wins != null) result.wins = wins;
    if (email != null) result.email = email;
    if (isGuest != null) result.isGuest = isGuest;
    return result;
  }

  AuthResponse._();

  factory AuthResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AuthResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AuthResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'username')
    ..aOS(3, _omitFieldNames ? '' : 'token')
    ..aI(4, _omitFieldNames ? '' : 'rating')
    ..aI(5, _omitFieldNames ? '' : 'matchesPlayed')
    ..aI(6, _omitFieldNames ? '' : 'wins')
    ..aOS(7, _omitFieldNames ? '' : 'email')
    ..aOB(8, _omitFieldNames ? '' : 'isGuest')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthResponse copyWith(void Function(AuthResponse) updates) =>
      super.copyWith((message) => updates(message as AuthResponse))
          as AuthResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AuthResponse create() => AuthResponse._();
  @$core.override
  AuthResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AuthResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AuthResponse>(create);
  static AuthResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get username => $_getSZ(1);
  @$pb.TagNumber(2)
  set username($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUsername() => $_has(1);
  @$pb.TagNumber(2)
  void clearUsername() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get token => $_getSZ(2);
  @$pb.TagNumber(3)
  set token($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearToken() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get rating => $_getIZ(3);
  @$pb.TagNumber(4)
  set rating($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRating() => $_has(3);
  @$pb.TagNumber(4)
  void clearRating() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get matchesPlayed => $_getIZ(4);
  @$pb.TagNumber(5)
  set matchesPlayed($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMatchesPlayed() => $_has(4);
  @$pb.TagNumber(5)
  void clearMatchesPlayed() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get wins => $_getIZ(5);
  @$pb.TagNumber(6)
  set wins($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasWins() => $_has(5);
  @$pb.TagNumber(6)
  void clearWins() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get email => $_getSZ(6);
  @$pb.TagNumber(7)
  set email($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEmail() => $_has(6);
  @$pb.TagNumber(7)
  void clearEmail() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get isGuest => $_getBF(7);
  @$pb.TagNumber(8)
  set isGuest($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIsGuest() => $_has(7);
  @$pb.TagNumber(8)
  void clearIsGuest() => $_clearField(8);
}

class GetProfileRequest extends $pb.GeneratedMessage {
  factory GetProfileRequest() => create();

  GetProfileRequest._();

  factory GetProfileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetProfileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetProfileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProfileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProfileRequest copyWith(void Function(GetProfileRequest) updates) =>
      super.copyWith((message) => updates(message as GetProfileRequest))
          as GetProfileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProfileRequest create() => GetProfileRequest._();
  @$core.override
  GetProfileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetProfileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetProfileRequest>(create);
  static GetProfileRequest? _defaultInstance;
}

class ProfileResponse extends $pb.GeneratedMessage {
  factory ProfileResponse({
    $core.String? userId,
    $core.String? username,
    $core.int? rating,
    $core.int? matchesPlayed,
    $core.int? wins,
    $core.String? email,
    $core.bool? isGuest,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (username != null) result.username = username;
    if (rating != null) result.rating = rating;
    if (matchesPlayed != null) result.matchesPlayed = matchesPlayed;
    if (wins != null) result.wins = wins;
    if (email != null) result.email = email;
    if (isGuest != null) result.isGuest = isGuest;
    return result;
  }

  ProfileResponse._();

  factory ProfileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProfileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProfileResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'username')
    ..aI(3, _omitFieldNames ? '' : 'rating')
    ..aI(4, _omitFieldNames ? '' : 'matchesPlayed')
    ..aI(5, _omitFieldNames ? '' : 'wins')
    ..aOS(6, _omitFieldNames ? '' : 'email')
    ..aOB(7, _omitFieldNames ? '' : 'isGuest')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProfileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProfileResponse copyWith(void Function(ProfileResponse) updates) =>
      super.copyWith((message) => updates(message as ProfileResponse))
          as ProfileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProfileResponse create() => ProfileResponse._();
  @$core.override
  ProfileResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProfileResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProfileResponse>(create);
  static ProfileResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get username => $_getSZ(1);
  @$pb.TagNumber(2)
  set username($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUsername() => $_has(1);
  @$pb.TagNumber(2)
  void clearUsername() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get rating => $_getIZ(2);
  @$pb.TagNumber(3)
  set rating($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRating() => $_has(2);
  @$pb.TagNumber(3)
  void clearRating() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get matchesPlayed => $_getIZ(3);
  @$pb.TagNumber(4)
  set matchesPlayed($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMatchesPlayed() => $_has(3);
  @$pb.TagNumber(4)
  void clearMatchesPlayed() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get wins => $_getIZ(4);
  @$pb.TagNumber(5)
  set wins($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWins() => $_has(4);
  @$pb.TagNumber(5)
  void clearWins() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get email => $_getSZ(5);
  @$pb.TagNumber(6)
  set email($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEmail() => $_has(5);
  @$pb.TagNumber(6)
  void clearEmail() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get isGuest => $_getBF(6);
  @$pb.TagNumber(7)
  set isGuest($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsGuest() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsGuest() => $_clearField(7);
}

class GuestLoginRequest extends $pb.GeneratedMessage {
  factory GuestLoginRequest() => create();

  GuestLoginRequest._();

  factory GuestLoginRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GuestLoginRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GuestLoginRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GuestLoginRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GuestLoginRequest copyWith(void Function(GuestLoginRequest) updates) =>
      super.copyWith((message) => updates(message as GuestLoginRequest))
          as GuestLoginRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GuestLoginRequest create() => GuestLoginRequest._();
  @$core.override
  GuestLoginRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GuestLoginRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GuestLoginRequest>(create);
  static GuestLoginRequest? _defaultInstance;
}

class EmailLoginRequest extends $pb.GeneratedMessage {
  factory EmailLoginRequest({
    $core.String? email,
  }) {
    final result = create();
    if (email != null) result.email = email;
    return result;
  }

  EmailLoginRequest._();

  factory EmailLoginRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EmailLoginRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EmailLoginRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'email')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EmailLoginRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EmailLoginRequest copyWith(void Function(EmailLoginRequest) updates) =>
      super.copyWith((message) => updates(message as EmailLoginRequest))
          as EmailLoginRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EmailLoginRequest create() => EmailLoginRequest._();
  @$core.override
  EmailLoginRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EmailLoginRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EmailLoginRequest>(create);
  static EmailLoginRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get email => $_getSZ(0);
  @$pb.TagNumber(1)
  set email($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearEmail() => $_clearField(1);
}

class SendEmailCodeRequest extends $pb.GeneratedMessage {
  factory SendEmailCodeRequest({
    $core.String? email,
    $core.String? purpose,
  }) {
    final result = create();
    if (email != null) result.email = email;
    if (purpose != null) result.purpose = purpose;
    return result;
  }

  SendEmailCodeRequest._();

  factory SendEmailCodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendEmailCodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendEmailCodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'email')
    ..aOS(2, _omitFieldNames ? '' : 'purpose')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendEmailCodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendEmailCodeRequest copyWith(void Function(SendEmailCodeRequest) updates) =>
      super.copyWith((message) => updates(message as SendEmailCodeRequest))
          as SendEmailCodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendEmailCodeRequest create() => SendEmailCodeRequest._();
  @$core.override
  SendEmailCodeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendEmailCodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendEmailCodeRequest>(create);
  static SendEmailCodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get email => $_getSZ(0);
  @$pb.TagNumber(1)
  set email($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearEmail() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get purpose => $_getSZ(1);
  @$pb.TagNumber(2)
  set purpose($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPurpose() => $_has(1);
  @$pb.TagNumber(2)
  void clearPurpose() => $_clearField(2);
}

class SendEmailCodeResponse extends $pb.GeneratedMessage {
  factory SendEmailCodeResponse({
    $core.bool? sent,
  }) {
    final result = create();
    if (sent != null) result.sent = sent;
    return result;
  }

  SendEmailCodeResponse._();

  factory SendEmailCodeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendEmailCodeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendEmailCodeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'sent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendEmailCodeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendEmailCodeResponse copyWith(
          void Function(SendEmailCodeResponse) updates) =>
      super.copyWith((message) => updates(message as SendEmailCodeResponse))
          as SendEmailCodeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendEmailCodeResponse create() => SendEmailCodeResponse._();
  @$core.override
  SendEmailCodeResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendEmailCodeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendEmailCodeResponse>(create);
  static SendEmailCodeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get sent => $_getBF(0);
  @$pb.TagNumber(1)
  set sent($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSent() => $_has(0);
  @$pb.TagNumber(1)
  void clearSent() => $_clearField(1);
}

class VerifyEmailCodeRequest extends $pb.GeneratedMessage {
  factory VerifyEmailCodeRequest({
    $core.String? email,
    $core.String? code,
  }) {
    final result = create();
    if (email != null) result.email = email;
    if (code != null) result.code = code;
    return result;
  }

  VerifyEmailCodeRequest._();

  factory VerifyEmailCodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory VerifyEmailCodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VerifyEmailCodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'email')
    ..aOS(2, _omitFieldNames ? '' : 'code')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VerifyEmailCodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VerifyEmailCodeRequest copyWith(
          void Function(VerifyEmailCodeRequest) updates) =>
      super.copyWith((message) => updates(message as VerifyEmailCodeRequest))
          as VerifyEmailCodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static VerifyEmailCodeRequest create() => VerifyEmailCodeRequest._();
  @$core.override
  VerifyEmailCodeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static VerifyEmailCodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VerifyEmailCodeRequest>(create);
  static VerifyEmailCodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get email => $_getSZ(0);
  @$pb.TagNumber(1)
  set email($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearEmail() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get code => $_getSZ(1);
  @$pb.TagNumber(2)
  set code($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearCode() => $_clearField(2);
}

class VerifyEmailCodeResponse extends $pb.GeneratedMessage {
  factory VerifyEmailCodeResponse({
    $core.bool? verified,
    $core.String? token,
    $core.String? userId,
  }) {
    final result = create();
    if (verified != null) result.verified = verified;
    if (token != null) result.token = token;
    if (userId != null) result.userId = userId;
    return result;
  }

  VerifyEmailCodeResponse._();

  factory VerifyEmailCodeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory VerifyEmailCodeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VerifyEmailCodeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'verified')
    ..aOS(2, _omitFieldNames ? '' : 'token')
    ..aOS(3, _omitFieldNames ? '' : 'userId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VerifyEmailCodeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VerifyEmailCodeResponse copyWith(
          void Function(VerifyEmailCodeResponse) updates) =>
      super.copyWith((message) => updates(message as VerifyEmailCodeResponse))
          as VerifyEmailCodeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static VerifyEmailCodeResponse create() => VerifyEmailCodeResponse._();
  @$core.override
  VerifyEmailCodeResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static VerifyEmailCodeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VerifyEmailCodeResponse>(create);
  static VerifyEmailCodeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get verified => $_getBF(0);
  @$pb.TagNumber(1)
  set verified($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVerified() => $_has(0);
  @$pb.TagNumber(1)
  void clearVerified() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get token => $_getSZ(1);
  @$pb.TagNumber(2)
  set token($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearToken() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get userId => $_getSZ(2);
  @$pb.TagNumber(3)
  set userId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUserId() => $_has(2);
  @$pb.TagNumber(3)
  void clearUserId() => $_clearField(3);
}

class LinkEmailRequest extends $pb.GeneratedMessage {
  factory LinkEmailRequest({
    $core.String? email,
    $core.String? code,
  }) {
    final result = create();
    if (email != null) result.email = email;
    if (code != null) result.code = code;
    return result;
  }

  LinkEmailRequest._();

  factory LinkEmailRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LinkEmailRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LinkEmailRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'email')
    ..aOS(2, _omitFieldNames ? '' : 'code')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkEmailRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkEmailRequest copyWith(void Function(LinkEmailRequest) updates) =>
      super.copyWith((message) => updates(message as LinkEmailRequest))
          as LinkEmailRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LinkEmailRequest create() => LinkEmailRequest._();
  @$core.override
  LinkEmailRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LinkEmailRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LinkEmailRequest>(create);
  static LinkEmailRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get email => $_getSZ(0);
  @$pb.TagNumber(1)
  set email($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearEmail() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get code => $_getSZ(1);
  @$pb.TagNumber(2)
  set code($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearCode() => $_clearField(2);
}

class LinkEmailResponse extends $pb.GeneratedMessage {
  factory LinkEmailResponse({
    $core.bool? linked,
  }) {
    final result = create();
    if (linked != null) result.linked = linked;
    return result;
  }

  LinkEmailResponse._();

  factory LinkEmailResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LinkEmailResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LinkEmailResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'linked')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkEmailResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkEmailResponse copyWith(void Function(LinkEmailResponse) updates) =>
      super.copyWith((message) => updates(message as LinkEmailResponse))
          as LinkEmailResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LinkEmailResponse create() => LinkEmailResponse._();
  @$core.override
  LinkEmailResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LinkEmailResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LinkEmailResponse>(create);
  static LinkEmailResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get linked => $_getBF(0);
  @$pb.TagNumber(1)
  set linked($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLinked() => $_has(0);
  @$pb.TagNumber(1)
  void clearLinked() => $_clearField(1);
}

class ResetPasswordRequest extends $pb.GeneratedMessage {
  factory ResetPasswordRequest({
    $core.String? email,
    $core.String? code,
    $core.String? newPassword,
  }) {
    final result = create();
    if (email != null) result.email = email;
    if (code != null) result.code = code;
    if (newPassword != null) result.newPassword = newPassword;
    return result;
  }

  ResetPasswordRequest._();

  factory ResetPasswordRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResetPasswordRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResetPasswordRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'email')
    ..aOS(2, _omitFieldNames ? '' : 'code')
    ..aOS(3, _omitFieldNames ? '' : 'newPassword')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResetPasswordRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResetPasswordRequest copyWith(void Function(ResetPasswordRequest) updates) =>
      super.copyWith((message) => updates(message as ResetPasswordRequest))
          as ResetPasswordRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResetPasswordRequest create() => ResetPasswordRequest._();
  @$core.override
  ResetPasswordRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResetPasswordRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResetPasswordRequest>(create);
  static ResetPasswordRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get email => $_getSZ(0);
  @$pb.TagNumber(1)
  set email($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearEmail() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get code => $_getSZ(1);
  @$pb.TagNumber(2)
  set code($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get newPassword => $_getSZ(2);
  @$pb.TagNumber(3)
  set newPassword($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNewPassword() => $_has(2);
  @$pb.TagNumber(3)
  void clearNewPassword() => $_clearField(3);
}

class ResetPasswordResponse extends $pb.GeneratedMessage {
  factory ResetPasswordResponse({
    $core.bool? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  ResetPasswordResponse._();

  factory ResetPasswordResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResetPasswordResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResetPasswordResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResetPasswordResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResetPasswordResponse copyWith(
          void Function(ResetPasswordResponse) updates) =>
      super.copyWith((message) => updates(message as ResetPasswordResponse))
          as ResetPasswordResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResetPasswordResponse create() => ResetPasswordResponse._();
  @$core.override
  ResetPasswordResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResetPasswordResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResetPasswordResponse>(create);
  static ResetPasswordResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
}

class CheckUsernameRequest extends $pb.GeneratedMessage {
  factory CheckUsernameRequest({
    $core.String? username,
  }) {
    final result = create();
    if (username != null) result.username = username;
    return result;
  }

  CheckUsernameRequest._();

  factory CheckUsernameRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CheckUsernameRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckUsernameRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckUsernameRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckUsernameRequest copyWith(void Function(CheckUsernameRequest) updates) =>
      super.copyWith((message) => updates(message as CheckUsernameRequest))
          as CheckUsernameRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CheckUsernameRequest create() => CheckUsernameRequest._();
  @$core.override
  CheckUsernameRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CheckUsernameRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckUsernameRequest>(create);
  static CheckUsernameRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);
}

class CheckUsernameResponse extends $pb.GeneratedMessage {
  factory CheckUsernameResponse({
    $core.bool? available,
  }) {
    final result = create();
    if (available != null) result.available = available;
    return result;
  }

  CheckUsernameResponse._();

  factory CheckUsernameResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CheckUsernameResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckUsernameResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'available')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckUsernameResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckUsernameResponse copyWith(
          void Function(CheckUsernameResponse) updates) =>
      super.copyWith((message) => updates(message as CheckUsernameResponse))
          as CheckUsernameResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CheckUsernameResponse create() => CheckUsernameResponse._();
  @$core.override
  CheckUsernameResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CheckUsernameResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckUsernameResponse>(create);
  static CheckUsernameResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get available => $_getBF(0);
  @$pb.TagNumber(1)
  set available($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAvailable() => $_has(0);
  @$pb.TagNumber(1)
  void clearAvailable() => $_clearField(1);
}

class CalculateScoreRequest extends $pb.GeneratedMessage {
  factory CalculateScoreRequest({
    $core.String? roomId,
    $core.String? userId,
    $core.int? round,
    $core.int? optionIndex,
    $fixnum.Int64? answerTimeMs,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (userId != null) result.userId = userId;
    if (round != null) result.round = round;
    if (optionIndex != null) result.optionIndex = optionIndex;
    if (answerTimeMs != null) result.answerTimeMs = answerTimeMs;
    return result;
  }

  CalculateScoreRequest._();

  factory CalculateScoreRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CalculateScoreRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CalculateScoreRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aI(3, _omitFieldNames ? '' : 'round')
    ..aI(4, _omitFieldNames ? '' : 'optionIndex')
    ..aInt64(5, _omitFieldNames ? '' : 'answerTimeMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CalculateScoreRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CalculateScoreRequest copyWith(
          void Function(CalculateScoreRequest) updates) =>
      super.copyWith((message) => updates(message as CalculateScoreRequest))
          as CalculateScoreRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CalculateScoreRequest create() => CalculateScoreRequest._();
  @$core.override
  CalculateScoreRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CalculateScoreRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CalculateScoreRequest>(create);
  static CalculateScoreRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get round => $_getIZ(2);
  @$pb.TagNumber(3)
  set round($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRound() => $_has(2);
  @$pb.TagNumber(3)
  void clearRound() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get optionIndex => $_getIZ(3);
  @$pb.TagNumber(4)
  set optionIndex($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOptionIndex() => $_has(3);
  @$pb.TagNumber(4)
  void clearOptionIndex() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get answerTimeMs => $_getI64(4);
  @$pb.TagNumber(5)
  set answerTimeMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAnswerTimeMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearAnswerTimeMs() => $_clearField(5);
}

class CalculateScoreResponse extends $pb.GeneratedMessage {
  factory CalculateScoreResponse({
    $core.double? score,
    $core.bool? correct,
    $core.double? speedMultiplier,
  }) {
    final result = create();
    if (score != null) result.score = score;
    if (correct != null) result.correct = correct;
    if (speedMultiplier != null) result.speedMultiplier = speedMultiplier;
    return result;
  }

  CalculateScoreResponse._();

  factory CalculateScoreResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CalculateScoreResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CalculateScoreResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'score')
    ..aOB(2, _omitFieldNames ? '' : 'correct')
    ..aD(3, _omitFieldNames ? '' : 'speedMultiplier')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CalculateScoreResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CalculateScoreResponse copyWith(
          void Function(CalculateScoreResponse) updates) =>
      super.copyWith((message) => updates(message as CalculateScoreResponse))
          as CalculateScoreResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CalculateScoreResponse create() => CalculateScoreResponse._();
  @$core.override
  CalculateScoreResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CalculateScoreResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CalculateScoreResponse>(create);
  static CalculateScoreResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get score => $_getN(0);
  @$pb.TagNumber(1)
  set score($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScore() => $_has(0);
  @$pb.TagNumber(1)
  void clearScore() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get correct => $_getBF(1);
  @$pb.TagNumber(2)
  set correct($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCorrect() => $_has(1);
  @$pb.TagNumber(2)
  void clearCorrect() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get speedMultiplier => $_getN(2);
  @$pb.TagNumber(3)
  set speedMultiplier($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSpeedMultiplier() => $_has(2);
  @$pb.TagNumber(3)
  void clearSpeedMultiplier() => $_clearField(3);
}

class GetLeaderboardRequest extends $pb.GeneratedMessage {
  factory GetLeaderboardRequest({
    $core.String? roomId,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    return result;
  }

  GetLeaderboardRequest._();

  factory GetLeaderboardRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetLeaderboardRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetLeaderboardRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetLeaderboardRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetLeaderboardRequest copyWith(
          void Function(GetLeaderboardRequest) updates) =>
      super.copyWith((message) => updates(message as GetLeaderboardRequest))
          as GetLeaderboardRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetLeaderboardRequest create() => GetLeaderboardRequest._();
  @$core.override
  GetLeaderboardRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetLeaderboardRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetLeaderboardRequest>(create);
  static GetLeaderboardRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);
}

class GetLeaderboardResponse extends $pb.GeneratedMessage {
  factory GetLeaderboardResponse({
    $core.Iterable<LeaderboardEntry>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addAll(entries);
    return result;
  }

  GetLeaderboardResponse._();

  factory GetLeaderboardResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetLeaderboardResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetLeaderboardResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..pPM<LeaderboardEntry>(1, _omitFieldNames ? '' : 'entries',
        subBuilder: LeaderboardEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetLeaderboardResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetLeaderboardResponse copyWith(
          void Function(GetLeaderboardResponse) updates) =>
      super.copyWith((message) => updates(message as GetLeaderboardResponse))
          as GetLeaderboardResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetLeaderboardResponse create() => GetLeaderboardResponse._();
  @$core.override
  GetLeaderboardResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetLeaderboardResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetLeaderboardResponse>(create);
  static GetLeaderboardResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<LeaderboardEntry> get entries => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
