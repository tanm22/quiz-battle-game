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
    $core.String? referralCode,
  }) {
    final result = create();
    if (username != null) result.username = username;
    if (password != null) result.password = password;
    if (email != null) result.email = email;
    if (referralCode != null) result.referralCode = referralCode;
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
    ..aOS(4, _omitFieldNames ? '' : 'referralCode')
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

  @$pb.TagNumber(4)
  $core.String get referralCode => $_getSZ(3);
  @$pb.TagNumber(4)
  set referralCode($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReferralCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearReferralCode() => $_clearField(4);
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
    $core.String? plan,
    $fixnum.Int64? coins,
    StreakInfo? streak,
    $core.String? referralCode,
    $core.bool? streakUpdated,
    RewardGrant? reward,
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
    if (plan != null) result.plan = plan;
    if (coins != null) result.coins = coins;
    if (streak != null) result.streak = streak;
    if (referralCode != null) result.referralCode = referralCode;
    if (streakUpdated != null) result.streakUpdated = streakUpdated;
    if (reward != null) result.reward = reward;
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
    ..aOS(9, _omitFieldNames ? '' : 'plan')
    ..aInt64(10, _omitFieldNames ? '' : 'coins')
    ..aOM<StreakInfo>(11, _omitFieldNames ? '' : 'streak',
        subBuilder: StreakInfo.create)
    ..aOS(12, _omitFieldNames ? '' : 'referralCode')
    ..aOB(13, _omitFieldNames ? '' : 'streakUpdated')
    ..aOM<RewardGrant>(14, _omitFieldNames ? '' : 'reward',
        subBuilder: RewardGrant.create)
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

  @$pb.TagNumber(9)
  $core.String get plan => $_getSZ(8);
  @$pb.TagNumber(9)
  set plan($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPlan() => $_has(8);
  @$pb.TagNumber(9)
  void clearPlan() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get coins => $_getI64(9);
  @$pb.TagNumber(10)
  set coins($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCoins() => $_has(9);
  @$pb.TagNumber(10)
  void clearCoins() => $_clearField(10);

  @$pb.TagNumber(11)
  StreakInfo get streak => $_getN(10);
  @$pb.TagNumber(11)
  set streak(StreakInfo value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasStreak() => $_has(10);
  @$pb.TagNumber(11)
  void clearStreak() => $_clearField(11);
  @$pb.TagNumber(11)
  StreakInfo ensureStreak() => $_ensure(10);

  @$pb.TagNumber(12)
  $core.String get referralCode => $_getSZ(11);
  @$pb.TagNumber(12)
  set referralCode($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasReferralCode() => $_has(11);
  @$pb.TagNumber(12)
  void clearReferralCode() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get streakUpdated => $_getBF(12);
  @$pb.TagNumber(13)
  set streakUpdated($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasStreakUpdated() => $_has(12);
  @$pb.TagNumber(13)
  void clearStreakUpdated() => $_clearField(13);

  @$pb.TagNumber(14)
  RewardGrant get reward => $_getN(13);
  @$pb.TagNumber(14)
  set reward(RewardGrant value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasReward() => $_has(13);
  @$pb.TagNumber(14)
  void clearReward() => $_clearField(14);
  @$pb.TagNumber(14)
  RewardGrant ensureReward() => $_ensure(13);
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
    $core.String? plan,
    $fixnum.Int64? coins,
    StreakInfo? streak,
    $core.String? referralCode,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (username != null) result.username = username;
    if (rating != null) result.rating = rating;
    if (matchesPlayed != null) result.matchesPlayed = matchesPlayed;
    if (wins != null) result.wins = wins;
    if (email != null) result.email = email;
    if (isGuest != null) result.isGuest = isGuest;
    if (plan != null) result.plan = plan;
    if (coins != null) result.coins = coins;
    if (streak != null) result.streak = streak;
    if (referralCode != null) result.referralCode = referralCode;
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
    ..aOS(8, _omitFieldNames ? '' : 'plan')
    ..aInt64(9, _omitFieldNames ? '' : 'coins')
    ..aOM<StreakInfo>(10, _omitFieldNames ? '' : 'streak',
        subBuilder: StreakInfo.create)
    ..aOS(11, _omitFieldNames ? '' : 'referralCode')
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

  @$pb.TagNumber(8)
  $core.String get plan => $_getSZ(7);
  @$pb.TagNumber(8)
  set plan($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPlan() => $_has(7);
  @$pb.TagNumber(8)
  void clearPlan() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get coins => $_getI64(8);
  @$pb.TagNumber(9)
  set coins($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCoins() => $_has(8);
  @$pb.TagNumber(9)
  void clearCoins() => $_clearField(9);

  @$pb.TagNumber(10)
  StreakInfo get streak => $_getN(9);
  @$pb.TagNumber(10)
  set streak(StreakInfo value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasStreak() => $_has(9);
  @$pb.TagNumber(10)
  void clearStreak() => $_clearField(10);
  @$pb.TagNumber(10)
  StreakInfo ensureStreak() => $_ensure(9);

  @$pb.TagNumber(11)
  $core.String get referralCode => $_getSZ(10);
  @$pb.TagNumber(11)
  set referralCode($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasReferralCode() => $_has(10);
  @$pb.TagNumber(11)
  void clearReferralCode() => $_clearField(11);
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

class DeleteAccountRequest extends $pb.GeneratedMessage {
  factory DeleteAccountRequest() => create();

  DeleteAccountRequest._();

  factory DeleteAccountRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteAccountRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteAccountRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAccountRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAccountRequest copyWith(void Function(DeleteAccountRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteAccountRequest))
          as DeleteAccountRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteAccountRequest create() => DeleteAccountRequest._();
  @$core.override
  DeleteAccountRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteAccountRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteAccountRequest>(create);
  static DeleteAccountRequest? _defaultInstance;
}

class DeleteAccountResponse extends $pb.GeneratedMessage {
  factory DeleteAccountResponse({
    $core.bool? deleted,
  }) {
    final result = create();
    if (deleted != null) result.deleted = deleted;
    return result;
  }

  DeleteAccountResponse._();

  factory DeleteAccountResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteAccountResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteAccountResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'deleted')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAccountResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAccountResponse copyWith(
          void Function(DeleteAccountResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteAccountResponse))
          as DeleteAccountResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteAccountResponse create() => DeleteAccountResponse._();
  @$core.override
  DeleteAccountResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteAccountResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteAccountResponse>(create);
  static DeleteAccountResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get deleted => $_getBF(0);
  @$pb.TagNumber(1)
  set deleted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeleted() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeleted() => $_clearField(1);
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

class GetMatchHistoryRequest extends $pb.GeneratedMessage {
  factory GetMatchHistoryRequest({
    $core.int? limit,
    $core.int? offset,
  }) {
    final result = create();
    if (limit != null) result.limit = limit;
    if (offset != null) result.offset = offset;
    return result;
  }

  GetMatchHistoryRequest._();

  factory GetMatchHistoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetMatchHistoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetMatchHistoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'limit')
    ..aI(2, _omitFieldNames ? '' : 'offset')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMatchHistoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMatchHistoryRequest copyWith(
          void Function(GetMatchHistoryRequest) updates) =>
      super.copyWith((message) => updates(message as GetMatchHistoryRequest))
          as GetMatchHistoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetMatchHistoryRequest create() => GetMatchHistoryRequest._();
  @$core.override
  GetMatchHistoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetMatchHistoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetMatchHistoryRequest>(create);
  static GetMatchHistoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get limit => $_getIZ(0);
  @$pb.TagNumber(1)
  set limit($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLimit() => $_has(0);
  @$pb.TagNumber(1)
  void clearLimit() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get offset => $_getIZ(1);
  @$pb.TagNumber(2)
  set offset($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => $_clearField(2);
}

class GetMatchHistoryResponse extends $pb.GeneratedMessage {
  factory GetMatchHistoryResponse({
    $core.Iterable<MatchHistoryEntry>? matches,
  }) {
    final result = create();
    if (matches != null) result.matches.addAll(matches);
    return result;
  }

  GetMatchHistoryResponse._();

  factory GetMatchHistoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetMatchHistoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetMatchHistoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..pPM<MatchHistoryEntry>(1, _omitFieldNames ? '' : 'matches',
        subBuilder: MatchHistoryEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMatchHistoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMatchHistoryResponse copyWith(
          void Function(GetMatchHistoryResponse) updates) =>
      super.copyWith((message) => updates(message as GetMatchHistoryResponse))
          as GetMatchHistoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetMatchHistoryResponse create() => GetMatchHistoryResponse._();
  @$core.override
  GetMatchHistoryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetMatchHistoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetMatchHistoryResponse>(create);
  static GetMatchHistoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MatchHistoryEntry> get matches => $_getList(0);
}

class MatchHistoryEntry extends $pb.GeneratedMessage {
  factory MatchHistoryEntry({
    $core.String? roomId,
    $core.String? winner,
    $core.Iterable<PlayerResult>? players,
    $core.int? rounds,
    $fixnum.Int64? duration,
    $fixnum.Int64? createdAt,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (winner != null) result.winner = winner;
    if (players != null) result.players.addAll(players);
    if (rounds != null) result.rounds = rounds;
    if (duration != null) result.duration = duration;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  MatchHistoryEntry._();

  factory MatchHistoryEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MatchHistoryEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MatchHistoryEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'winner')
    ..pPM<PlayerResult>(3, _omitFieldNames ? '' : 'players',
        subBuilder: PlayerResult.create)
    ..aI(4, _omitFieldNames ? '' : 'rounds')
    ..aInt64(5, _omitFieldNames ? '' : 'duration')
    ..aInt64(6, _omitFieldNames ? '' : 'createdAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MatchHistoryEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MatchHistoryEntry copyWith(void Function(MatchHistoryEntry) updates) =>
      super.copyWith((message) => updates(message as MatchHistoryEntry))
          as MatchHistoryEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchHistoryEntry create() => MatchHistoryEntry._();
  @$core.override
  MatchHistoryEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MatchHistoryEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MatchHistoryEntry>(create);
  static MatchHistoryEntry? _defaultInstance;

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

  @$pb.TagNumber(6)
  $fixnum.Int64 get createdAt => $_getI64(5);
  @$pb.TagNumber(6)
  set createdAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => $_clearField(6);
}

class StreakInfo extends $pb.GeneratedMessage {
  factory StreakInfo({
    $core.int? current,
    $core.int? longest,
    $core.String? lastClaimedDate,
  }) {
    final result = create();
    if (current != null) result.current = current;
    if (longest != null) result.longest = longest;
    if (lastClaimedDate != null) result.lastClaimedDate = lastClaimedDate;
    return result;
  }

  StreakInfo._();

  factory StreakInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreakInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreakInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'current')
    ..aI(2, _omitFieldNames ? '' : 'longest')
    ..aOS(3, _omitFieldNames ? '' : 'lastClaimedDate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreakInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreakInfo copyWith(void Function(StreakInfo) updates) =>
      super.copyWith((message) => updates(message as StreakInfo)) as StreakInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreakInfo create() => StreakInfo._();
  @$core.override
  StreakInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreakInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreakInfo>(create);
  static StreakInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get current => $_getIZ(0);
  @$pb.TagNumber(1)
  set current($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCurrent() => $_has(0);
  @$pb.TagNumber(1)
  void clearCurrent() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get longest => $_getIZ(1);
  @$pb.TagNumber(2)
  set longest($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLongest() => $_has(1);
  @$pb.TagNumber(2)
  void clearLongest() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get lastClaimedDate => $_getSZ(2);
  @$pb.TagNumber(3)
  set lastClaimedDate($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastClaimedDate() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastClaimedDate() => $_clearField(3);
}

class RewardGrant extends $pb.GeneratedMessage {
  factory RewardGrant({
    $fixnum.Int64? coins,
    $core.String? badgeName,
    $core.int? bonusQuizzes,
  }) {
    final result = create();
    if (coins != null) result.coins = coins;
    if (badgeName != null) result.badgeName = badgeName;
    if (bonusQuizzes != null) result.bonusQuizzes = bonusQuizzes;
    return result;
  }

  RewardGrant._();

  factory RewardGrant.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RewardGrant.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RewardGrant',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'coins')
    ..aOS(2, _omitFieldNames ? '' : 'badgeName')
    ..aI(3, _omitFieldNames ? '' : 'bonusQuizzes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RewardGrant clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RewardGrant copyWith(void Function(RewardGrant) updates) =>
      super.copyWith((message) => updates(message as RewardGrant))
          as RewardGrant;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RewardGrant create() => RewardGrant._();
  @$core.override
  RewardGrant createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RewardGrant getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RewardGrant>(create);
  static RewardGrant? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get coins => $_getI64(0);
  @$pb.TagNumber(1)
  set coins($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCoins() => $_has(0);
  @$pb.TagNumber(1)
  void clearCoins() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get badgeName => $_getSZ(1);
  @$pb.TagNumber(2)
  set badgeName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBadgeName() => $_has(1);
  @$pb.TagNumber(2)
  void clearBadgeName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get bonusQuizzes => $_getIZ(2);
  @$pb.TagNumber(3)
  set bonusQuizzes($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBonusQuizzes() => $_has(2);
  @$pb.TagNumber(3)
  void clearBonusQuizzes() => $_clearField(3);
}

class PlanStatus extends $pb.GeneratedMessage {
  factory PlanStatus({
    $core.String? plan,
    $fixnum.Int64? expiresAt,
  }) {
    final result = create();
    if (plan != null) result.plan = plan;
    if (expiresAt != null) result.expiresAt = expiresAt;
    return result;
  }

  PlanStatus._();

  factory PlanStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlanStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlanStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'plan')
    ..aInt64(2, _omitFieldNames ? '' : 'expiresAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanStatus copyWith(void Function(PlanStatus) updates) =>
      super.copyWith((message) => updates(message as PlanStatus)) as PlanStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlanStatus create() => PlanStatus._();
  @$core.override
  PlanStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlanStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlanStatus>(create);
  static PlanStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get plan => $_getSZ(0);
  @$pb.TagNumber(1)
  set plan($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlan() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlan() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expiresAt => $_getI64(1);
  @$pb.TagNumber(2)
  set expiresAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpiresAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpiresAt() => $_clearField(2);
}

class GoogleSignInRequest extends $pb.GeneratedMessage {
  factory GoogleSignInRequest({
    $core.String? idToken,
    $core.String? referralCode,
  }) {
    final result = create();
    if (idToken != null) result.idToken = idToken;
    if (referralCode != null) result.referralCode = referralCode;
    return result;
  }

  GoogleSignInRequest._();

  factory GoogleSignInRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GoogleSignInRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GoogleSignInRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'idToken')
    ..aOS(2, _omitFieldNames ? '' : 'referralCode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GoogleSignInRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GoogleSignInRequest copyWith(void Function(GoogleSignInRequest) updates) =>
      super.copyWith((message) => updates(message as GoogleSignInRequest))
          as GoogleSignInRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GoogleSignInRequest create() => GoogleSignInRequest._();
  @$core.override
  GoogleSignInRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GoogleSignInRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GoogleSignInRequest>(create);
  static GoogleSignInRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get idToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set idToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIdToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearIdToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get referralCode => $_getSZ(1);
  @$pb.TagNumber(2)
  set referralCode($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReferralCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearReferralCode() => $_clearField(2);
}

class GoogleSignInResponse extends $pb.GeneratedMessage {
  factory GoogleSignInResponse({
    $core.String? token,
    UserProfile? userProfile,
    $core.bool? isNewUser,
    $core.bool? streakUpdated,
    RewardGrant? reward,
  }) {
    final result = create();
    if (token != null) result.token = token;
    if (userProfile != null) result.userProfile = userProfile;
    if (isNewUser != null) result.isNewUser = isNewUser;
    if (streakUpdated != null) result.streakUpdated = streakUpdated;
    if (reward != null) result.reward = reward;
    return result;
  }

  GoogleSignInResponse._();

  factory GoogleSignInResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GoogleSignInResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GoogleSignInResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aOM<UserProfile>(2, _omitFieldNames ? '' : 'userProfile',
        subBuilder: UserProfile.create)
    ..aOB(3, _omitFieldNames ? '' : 'isNewUser')
    ..aOB(4, _omitFieldNames ? '' : 'streakUpdated')
    ..aOM<RewardGrant>(5, _omitFieldNames ? '' : 'reward',
        subBuilder: RewardGrant.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GoogleSignInResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GoogleSignInResponse copyWith(void Function(GoogleSignInResponse) updates) =>
      super.copyWith((message) => updates(message as GoogleSignInResponse))
          as GoogleSignInResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GoogleSignInResponse create() => GoogleSignInResponse._();
  @$core.override
  GoogleSignInResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GoogleSignInResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GoogleSignInResponse>(create);
  static GoogleSignInResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  @$pb.TagNumber(2)
  UserProfile get userProfile => $_getN(1);
  @$pb.TagNumber(2)
  set userProfile(UserProfile value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUserProfile() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserProfile() => $_clearField(2);
  @$pb.TagNumber(2)
  UserProfile ensureUserProfile() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.bool get isNewUser => $_getBF(2);
  @$pb.TagNumber(3)
  set isNewUser($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsNewUser() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsNewUser() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get streakUpdated => $_getBF(3);
  @$pb.TagNumber(4)
  set streakUpdated($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStreakUpdated() => $_has(3);
  @$pb.TagNumber(4)
  void clearStreakUpdated() => $_clearField(4);

  @$pb.TagNumber(5)
  RewardGrant get reward => $_getN(4);
  @$pb.TagNumber(5)
  set reward(RewardGrant value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasReward() => $_has(4);
  @$pb.TagNumber(5)
  void clearReward() => $_clearField(5);
  @$pb.TagNumber(5)
  RewardGrant ensureReward() => $_ensure(4);
}

class UserProfile extends $pb.GeneratedMessage {
  factory UserProfile({
    $core.String? userId,
    $core.String? username,
    $core.String? displayName,
    $core.String? email,
    $core.String? avatarUrl,
    $core.int? rating,
    $core.int? matchesPlayed,
    $core.int? wins,
    $core.String? plan,
    $fixnum.Int64? coins,
    StreakInfo? streak,
    $core.String? referralCode,
    $core.bool? isGuest,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (username != null) result.username = username;
    if (displayName != null) result.displayName = displayName;
    if (email != null) result.email = email;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    if (rating != null) result.rating = rating;
    if (matchesPlayed != null) result.matchesPlayed = matchesPlayed;
    if (wins != null) result.wins = wins;
    if (plan != null) result.plan = plan;
    if (coins != null) result.coins = coins;
    if (streak != null) result.streak = streak;
    if (referralCode != null) result.referralCode = referralCode;
    if (isGuest != null) result.isGuest = isGuest;
    return result;
  }

  UserProfile._();

  factory UserProfile.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserProfile.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserProfile',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'username')
    ..aOS(3, _omitFieldNames ? '' : 'displayName')
    ..aOS(4, _omitFieldNames ? '' : 'email')
    ..aOS(5, _omitFieldNames ? '' : 'avatarUrl')
    ..aI(6, _omitFieldNames ? '' : 'rating')
    ..aI(7, _omitFieldNames ? '' : 'matchesPlayed')
    ..aI(8, _omitFieldNames ? '' : 'wins')
    ..aOS(9, _omitFieldNames ? '' : 'plan')
    ..aInt64(10, _omitFieldNames ? '' : 'coins')
    ..aOM<StreakInfo>(11, _omitFieldNames ? '' : 'streak',
        subBuilder: StreakInfo.create)
    ..aOS(12, _omitFieldNames ? '' : 'referralCode')
    ..aOB(13, _omitFieldNames ? '' : 'isGuest')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserProfile clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserProfile copyWith(void Function(UserProfile) updates) =>
      super.copyWith((message) => updates(message as UserProfile))
          as UserProfile;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserProfile create() => UserProfile._();
  @$core.override
  UserProfile createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserProfile getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserProfile>(create);
  static UserProfile? _defaultInstance;

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
  $core.String get displayName => $_getSZ(2);
  @$pb.TagNumber(3)
  set displayName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDisplayName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get email => $_getSZ(3);
  @$pb.TagNumber(4)
  set email($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEmail() => $_has(3);
  @$pb.TagNumber(4)
  void clearEmail() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get avatarUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set avatarUrl($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAvatarUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearAvatarUrl() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get rating => $_getIZ(5);
  @$pb.TagNumber(6)
  set rating($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRating() => $_has(5);
  @$pb.TagNumber(6)
  void clearRating() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get matchesPlayed => $_getIZ(6);
  @$pb.TagNumber(7)
  set matchesPlayed($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMatchesPlayed() => $_has(6);
  @$pb.TagNumber(7)
  void clearMatchesPlayed() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get wins => $_getIZ(7);
  @$pb.TagNumber(8)
  set wins($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasWins() => $_has(7);
  @$pb.TagNumber(8)
  void clearWins() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get plan => $_getSZ(8);
  @$pb.TagNumber(9)
  set plan($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPlan() => $_has(8);
  @$pb.TagNumber(9)
  void clearPlan() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get coins => $_getI64(9);
  @$pb.TagNumber(10)
  set coins($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCoins() => $_has(9);
  @$pb.TagNumber(10)
  void clearCoins() => $_clearField(10);

  @$pb.TagNumber(11)
  StreakInfo get streak => $_getN(10);
  @$pb.TagNumber(11)
  set streak(StreakInfo value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasStreak() => $_has(10);
  @$pb.TagNumber(11)
  void clearStreak() => $_clearField(11);
  @$pb.TagNumber(11)
  StreakInfo ensureStreak() => $_ensure(10);

  @$pb.TagNumber(12)
  $core.String get referralCode => $_getSZ(11);
  @$pb.TagNumber(12)
  set referralCode($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasReferralCode() => $_has(11);
  @$pb.TagNumber(12)
  void clearReferralCode() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get isGuest => $_getBF(12);
  @$pb.TagNumber(13)
  set isGuest($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasIsGuest() => $_has(12);
  @$pb.TagNumber(13)
  void clearIsGuest() => $_clearField(13);
}

class ClaimDailyRewardRequest extends $pb.GeneratedMessage {
  factory ClaimDailyRewardRequest() => create();

  ClaimDailyRewardRequest._();

  factory ClaimDailyRewardRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClaimDailyRewardRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClaimDailyRewardRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClaimDailyRewardRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClaimDailyRewardRequest copyWith(
          void Function(ClaimDailyRewardRequest) updates) =>
      super.copyWith((message) => updates(message as ClaimDailyRewardRequest))
          as ClaimDailyRewardRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClaimDailyRewardRequest create() => ClaimDailyRewardRequest._();
  @$core.override
  ClaimDailyRewardRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClaimDailyRewardRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClaimDailyRewardRequest>(create);
  static ClaimDailyRewardRequest? _defaultInstance;
}

class ClaimDailyRewardResponse extends $pb.GeneratedMessage {
  factory ClaimDailyRewardResponse({
    RewardGrant? reward,
    StreakInfo? streak,
  }) {
    final result = create();
    if (reward != null) result.reward = reward;
    if (streak != null) result.streak = streak;
    return result;
  }

  ClaimDailyRewardResponse._();

  factory ClaimDailyRewardResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClaimDailyRewardResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClaimDailyRewardResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOM<RewardGrant>(1, _omitFieldNames ? '' : 'reward',
        subBuilder: RewardGrant.create)
    ..aOM<StreakInfo>(2, _omitFieldNames ? '' : 'streak',
        subBuilder: StreakInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClaimDailyRewardResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClaimDailyRewardResponse copyWith(
          void Function(ClaimDailyRewardResponse) updates) =>
      super.copyWith((message) => updates(message as ClaimDailyRewardResponse))
          as ClaimDailyRewardResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClaimDailyRewardResponse create() => ClaimDailyRewardResponse._();
  @$core.override
  ClaimDailyRewardResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClaimDailyRewardResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClaimDailyRewardResponse>(create);
  static ClaimDailyRewardResponse? _defaultInstance;

  @$pb.TagNumber(1)
  RewardGrant get reward => $_getN(0);
  @$pb.TagNumber(1)
  set reward(RewardGrant value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasReward() => $_has(0);
  @$pb.TagNumber(1)
  void clearReward() => $_clearField(1);
  @$pb.TagNumber(1)
  RewardGrant ensureReward() => $_ensure(0);

  @$pb.TagNumber(2)
  StreakInfo get streak => $_getN(1);
  @$pb.TagNumber(2)
  set streak(StreakInfo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStreak() => $_has(1);
  @$pb.TagNumber(2)
  void clearStreak() => $_clearField(2);
  @$pb.TagNumber(2)
  StreakInfo ensureStreak() => $_ensure(1);
}

class GetStreakInfoRequest extends $pb.GeneratedMessage {
  factory GetStreakInfoRequest() => create();

  GetStreakInfoRequest._();

  factory GetStreakInfoRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetStreakInfoRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStreakInfoRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStreakInfoRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStreakInfoRequest copyWith(void Function(GetStreakInfoRequest) updates) =>
      super.copyWith((message) => updates(message as GetStreakInfoRequest))
          as GetStreakInfoRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetStreakInfoRequest create() => GetStreakInfoRequest._();
  @$core.override
  GetStreakInfoRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetStreakInfoRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetStreakInfoRequest>(create);
  static GetStreakInfoRequest? _defaultInstance;
}

class GetStreakInfoResponse extends $pb.GeneratedMessage {
  factory GetStreakInfoResponse({
    StreakInfo? streak,
  }) {
    final result = create();
    if (streak != null) result.streak = streak;
    return result;
  }

  GetStreakInfoResponse._();

  factory GetStreakInfoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetStreakInfoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStreakInfoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOM<StreakInfo>(1, _omitFieldNames ? '' : 'streak',
        subBuilder: StreakInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStreakInfoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStreakInfoResponse copyWith(
          void Function(GetStreakInfoResponse) updates) =>
      super.copyWith((message) => updates(message as GetStreakInfoResponse))
          as GetStreakInfoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetStreakInfoResponse create() => GetStreakInfoResponse._();
  @$core.override
  GetStreakInfoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetStreakInfoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetStreakInfoResponse>(create);
  static GetStreakInfoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  StreakInfo get streak => $_getN(0);
  @$pb.TagNumber(1)
  set streak(StreakInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStreak() => $_has(0);
  @$pb.TagNumber(1)
  void clearStreak() => $_clearField(1);
  @$pb.TagNumber(1)
  StreakInfo ensureStreak() => $_ensure(0);
}

class GetHomeScreenDataRequest extends $pb.GeneratedMessage {
  factory GetHomeScreenDataRequest() => create();

  GetHomeScreenDataRequest._();

  factory GetHomeScreenDataRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetHomeScreenDataRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetHomeScreenDataRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetHomeScreenDataRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetHomeScreenDataRequest copyWith(
          void Function(GetHomeScreenDataRequest) updates) =>
      super.copyWith((message) => updates(message as GetHomeScreenDataRequest))
          as GetHomeScreenDataRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetHomeScreenDataRequest create() => GetHomeScreenDataRequest._();
  @$core.override
  GetHomeScreenDataRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetHomeScreenDataRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetHomeScreenDataRequest>(create);
  static GetHomeScreenDataRequest? _defaultInstance;
}

class GetHomeScreenDataResponse extends $pb.GeneratedMessage {
  factory GetHomeScreenDataResponse({
    UserProfile? profile,
    $core.int? quotaRemaining,
    $core.int? quotaLimit,
    $core.Iterable<LeaderboardEntry>? leaderboardPreview,
  }) {
    final result = create();
    if (profile != null) result.profile = profile;
    if (quotaRemaining != null) result.quotaRemaining = quotaRemaining;
    if (quotaLimit != null) result.quotaLimit = quotaLimit;
    if (leaderboardPreview != null)
      result.leaderboardPreview.addAll(leaderboardPreview);
    return result;
  }

  GetHomeScreenDataResponse._();

  factory GetHomeScreenDataResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetHomeScreenDataResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetHomeScreenDataResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOM<UserProfile>(1, _omitFieldNames ? '' : 'profile',
        subBuilder: UserProfile.create)
    ..aI(2, _omitFieldNames ? '' : 'quotaRemaining')
    ..aI(3, _omitFieldNames ? '' : 'quotaLimit')
    ..pPM<LeaderboardEntry>(4, _omitFieldNames ? '' : 'leaderboardPreview',
        subBuilder: LeaderboardEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetHomeScreenDataResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetHomeScreenDataResponse copyWith(
          void Function(GetHomeScreenDataResponse) updates) =>
      super.copyWith((message) => updates(message as GetHomeScreenDataResponse))
          as GetHomeScreenDataResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetHomeScreenDataResponse create() => GetHomeScreenDataResponse._();
  @$core.override
  GetHomeScreenDataResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetHomeScreenDataResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetHomeScreenDataResponse>(create);
  static GetHomeScreenDataResponse? _defaultInstance;

  @$pb.TagNumber(1)
  UserProfile get profile => $_getN(0);
  @$pb.TagNumber(1)
  set profile(UserProfile value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProfile() => $_has(0);
  @$pb.TagNumber(1)
  void clearProfile() => $_clearField(1);
  @$pb.TagNumber(1)
  UserProfile ensureProfile() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get quotaRemaining => $_getIZ(1);
  @$pb.TagNumber(2)
  set quotaRemaining($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuotaRemaining() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuotaRemaining() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get quotaLimit => $_getIZ(2);
  @$pb.TagNumber(3)
  set quotaLimit($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasQuotaLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearQuotaLimit() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<LeaderboardEntry> get leaderboardPreview => $_getList(3);
}

class GetReferralDashboardRequest extends $pb.GeneratedMessage {
  factory GetReferralDashboardRequest() => create();

  GetReferralDashboardRequest._();

  factory GetReferralDashboardRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetReferralDashboardRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetReferralDashboardRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetReferralDashboardRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetReferralDashboardRequest copyWith(
          void Function(GetReferralDashboardRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetReferralDashboardRequest))
          as GetReferralDashboardRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetReferralDashboardRequest create() =>
      GetReferralDashboardRequest._();
  @$core.override
  GetReferralDashboardRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetReferralDashboardRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetReferralDashboardRequest>(create);
  static GetReferralDashboardRequest? _defaultInstance;
}

class GetReferralDashboardResponse extends $pb.GeneratedMessage {
  factory GetReferralDashboardResponse({
    $core.String? referralCode,
    $core.int? totalInvites,
    $core.int? conversions,
    $fixnum.Int64? coinsEarned,
  }) {
    final result = create();
    if (referralCode != null) result.referralCode = referralCode;
    if (totalInvites != null) result.totalInvites = totalInvites;
    if (conversions != null) result.conversions = conversions;
    if (coinsEarned != null) result.coinsEarned = coinsEarned;
    return result;
  }

  GetReferralDashboardResponse._();

  factory GetReferralDashboardResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetReferralDashboardResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetReferralDashboardResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'referralCode')
    ..aI(2, _omitFieldNames ? '' : 'totalInvites')
    ..aI(3, _omitFieldNames ? '' : 'conversions')
    ..aInt64(4, _omitFieldNames ? '' : 'coinsEarned')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetReferralDashboardResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetReferralDashboardResponse copyWith(
          void Function(GetReferralDashboardResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetReferralDashboardResponse))
          as GetReferralDashboardResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetReferralDashboardResponse create() =>
      GetReferralDashboardResponse._();
  @$core.override
  GetReferralDashboardResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetReferralDashboardResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetReferralDashboardResponse>(create);
  static GetReferralDashboardResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get referralCode => $_getSZ(0);
  @$pb.TagNumber(1)
  set referralCode($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReferralCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearReferralCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get totalInvites => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalInvites($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalInvites() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalInvites() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get conversions => $_getIZ(2);
  @$pb.TagNumber(3)
  set conversions($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConversions() => $_has(2);
  @$pb.TagNumber(3)
  void clearConversions() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get coinsEarned => $_getI64(3);
  @$pb.TagNumber(4)
  set coinsEarned($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCoinsEarned() => $_has(3);
  @$pb.TagNumber(4)
  void clearCoinsEarned() => $_clearField(4);
}

class ApplyReferralCodeRequest extends $pb.GeneratedMessage {
  factory ApplyReferralCodeRequest({
    $core.String? code,
  }) {
    final result = create();
    if (code != null) result.code = code;
    return result;
  }

  ApplyReferralCodeRequest._();

  factory ApplyReferralCodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ApplyReferralCodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ApplyReferralCodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApplyReferralCodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApplyReferralCodeRequest copyWith(
          void Function(ApplyReferralCodeRequest) updates) =>
      super.copyWith((message) => updates(message as ApplyReferralCodeRequest))
          as ApplyReferralCodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ApplyReferralCodeRequest create() => ApplyReferralCodeRequest._();
  @$core.override
  ApplyReferralCodeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ApplyReferralCodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ApplyReferralCodeRequest>(create);
  static ApplyReferralCodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);
}

class ApplyReferralCodeResponse extends $pb.GeneratedMessage {
  factory ApplyReferralCodeResponse({
    $core.bool? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  ApplyReferralCodeResponse._();

  factory ApplyReferralCodeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ApplyReferralCodeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ApplyReferralCodeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApplyReferralCodeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApplyReferralCodeResponse copyWith(
          void Function(ApplyReferralCodeResponse) updates) =>
      super.copyWith((message) => updates(message as ApplyReferralCodeResponse))
          as ApplyReferralCodeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ApplyReferralCodeResponse create() => ApplyReferralCodeResponse._();
  @$core.override
  ApplyReferralCodeResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ApplyReferralCodeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ApplyReferralCodeResponse>(create);
  static ApplyReferralCodeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
}

class UpdateFCMTokenRequest extends $pb.GeneratedMessage {
  factory UpdateFCMTokenRequest({
    $core.String? token,
  }) {
    final result = create();
    if (token != null) result.token = token;
    return result;
  }

  UpdateFCMTokenRequest._();

  factory UpdateFCMTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateFCMTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateFCMTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateFCMTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateFCMTokenRequest copyWith(
          void Function(UpdateFCMTokenRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateFCMTokenRequest))
          as UpdateFCMTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateFCMTokenRequest create() => UpdateFCMTokenRequest._();
  @$core.override
  UpdateFCMTokenRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateFCMTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateFCMTokenRequest>(create);
  static UpdateFCMTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);
}

class UpdateFCMTokenResponse extends $pb.GeneratedMessage {
  factory UpdateFCMTokenResponse({
    $core.bool? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  UpdateFCMTokenResponse._();

  factory UpdateFCMTokenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateFCMTokenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateFCMTokenResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateFCMTokenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateFCMTokenResponse copyWith(
          void Function(UpdateFCMTokenResponse) updates) =>
      super.copyWith((message) => updates(message as UpdateFCMTokenResponse))
          as UpdateFCMTokenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateFCMTokenResponse create() => UpdateFCMTokenResponse._();
  @$core.override
  UpdateFCMTokenResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateFCMTokenResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateFCMTokenResponse>(create);
  static UpdateFCMTokenResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
}

class CreateOrderRequest extends $pb.GeneratedMessage {
  factory CreateOrderRequest({
    $core.String? planDuration,
  }) {
    final result = create();
    if (planDuration != null) result.planDuration = planDuration;
    return result;
  }

  CreateOrderRequest._();

  factory CreateOrderRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateOrderRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateOrderRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'planDuration')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateOrderRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateOrderRequest copyWith(void Function(CreateOrderRequest) updates) =>
      super.copyWith((message) => updates(message as CreateOrderRequest))
          as CreateOrderRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateOrderRequest create() => CreateOrderRequest._();
  @$core.override
  CreateOrderRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateOrderRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateOrderRequest>(create);
  static CreateOrderRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get planDuration => $_getSZ(0);
  @$pb.TagNumber(1)
  set planDuration($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlanDuration() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlanDuration() => $_clearField(1);
}

class CreateOrderResponse extends $pb.GeneratedMessage {
  factory CreateOrderResponse({
    $core.String? orderId,
    $core.String? keyId,
    $fixnum.Int64? amount,
    $core.String? currency,
  }) {
    final result = create();
    if (orderId != null) result.orderId = orderId;
    if (keyId != null) result.keyId = keyId;
    if (amount != null) result.amount = amount;
    if (currency != null) result.currency = currency;
    return result;
  }

  CreateOrderResponse._();

  factory CreateOrderResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateOrderResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateOrderResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'orderId')
    ..aOS(2, _omitFieldNames ? '' : 'keyId')
    ..aInt64(3, _omitFieldNames ? '' : 'amount')
    ..aOS(4, _omitFieldNames ? '' : 'currency')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateOrderResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateOrderResponse copyWith(void Function(CreateOrderResponse) updates) =>
      super.copyWith((message) => updates(message as CreateOrderResponse))
          as CreateOrderResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateOrderResponse create() => CreateOrderResponse._();
  @$core.override
  CreateOrderResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateOrderResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateOrderResponse>(create);
  static CreateOrderResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get orderId => $_getSZ(0);
  @$pb.TagNumber(1)
  set orderId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrderId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrderId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get keyId => $_getSZ(1);
  @$pb.TagNumber(2)
  set keyId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKeyId() => $_has(1);
  @$pb.TagNumber(2)
  void clearKeyId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get amount => $_getI64(2);
  @$pb.TagNumber(3)
  set amount($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get currency => $_getSZ(3);
  @$pb.TagNumber(4)
  set currency($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrency() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrency() => $_clearField(4);
}

class GetPlanStatusRequest extends $pb.GeneratedMessage {
  factory GetPlanStatusRequest() => create();

  GetPlanStatusRequest._();

  factory GetPlanStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPlanStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPlanStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPlanStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPlanStatusRequest copyWith(void Function(GetPlanStatusRequest) updates) =>
      super.copyWith((message) => updates(message as GetPlanStatusRequest))
          as GetPlanStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPlanStatusRequest create() => GetPlanStatusRequest._();
  @$core.override
  GetPlanStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPlanStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPlanStatusRequest>(create);
  static GetPlanStatusRequest? _defaultInstance;
}

class GetPlanStatusResponse extends $pb.GeneratedMessage {
  factory GetPlanStatusResponse({
    $core.String? plan,
    $fixnum.Int64? expiresAt,
  }) {
    final result = create();
    if (plan != null) result.plan = plan;
    if (expiresAt != null) result.expiresAt = expiresAt;
    return result;
  }

  GetPlanStatusResponse._();

  factory GetPlanStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPlanStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPlanStatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'plan')
    ..aInt64(2, _omitFieldNames ? '' : 'expiresAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPlanStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPlanStatusResponse copyWith(
          void Function(GetPlanStatusResponse) updates) =>
      super.copyWith((message) => updates(message as GetPlanStatusResponse))
          as GetPlanStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPlanStatusResponse create() => GetPlanStatusResponse._();
  @$core.override
  GetPlanStatusResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPlanStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPlanStatusResponse>(create);
  static GetPlanStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get plan => $_getSZ(0);
  @$pb.TagNumber(1)
  set plan($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlan() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlan() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expiresAt => $_getI64(1);
  @$pb.TagNumber(2)
  set expiresAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpiresAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpiresAt() => $_clearField(2);
}

class GetPaymentHistoryRequest extends $pb.GeneratedMessage {
  factory GetPaymentHistoryRequest({
    $core.int? limit,
    $core.int? offset,
  }) {
    final result = create();
    if (limit != null) result.limit = limit;
    if (offset != null) result.offset = offset;
    return result;
  }

  GetPaymentHistoryRequest._();

  factory GetPaymentHistoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPaymentHistoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPaymentHistoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'limit')
    ..aI(2, _omitFieldNames ? '' : 'offset')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaymentHistoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaymentHistoryRequest copyWith(
          void Function(GetPaymentHistoryRequest) updates) =>
      super.copyWith((message) => updates(message as GetPaymentHistoryRequest))
          as GetPaymentHistoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPaymentHistoryRequest create() => GetPaymentHistoryRequest._();
  @$core.override
  GetPaymentHistoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPaymentHistoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPaymentHistoryRequest>(create);
  static GetPaymentHistoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get limit => $_getIZ(0);
  @$pb.TagNumber(1)
  set limit($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLimit() => $_has(0);
  @$pb.TagNumber(1)
  void clearLimit() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get offset => $_getIZ(1);
  @$pb.TagNumber(2)
  set offset($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => $_clearField(2);
}

class GetPaymentHistoryResponse extends $pb.GeneratedMessage {
  factory GetPaymentHistoryResponse({
    $core.Iterable<PaymentRecord>? payments,
  }) {
    final result = create();
    if (payments != null) result.payments.addAll(payments);
    return result;
  }

  GetPaymentHistoryResponse._();

  factory GetPaymentHistoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPaymentHistoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPaymentHistoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..pPM<PaymentRecord>(1, _omitFieldNames ? '' : 'payments',
        subBuilder: PaymentRecord.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaymentHistoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaymentHistoryResponse copyWith(
          void Function(GetPaymentHistoryResponse) updates) =>
      super.copyWith((message) => updates(message as GetPaymentHistoryResponse))
          as GetPaymentHistoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPaymentHistoryResponse create() => GetPaymentHistoryResponse._();
  @$core.override
  GetPaymentHistoryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPaymentHistoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPaymentHistoryResponse>(create);
  static GetPaymentHistoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PaymentRecord> get payments => $_getList(0);
}

class PaymentRecord extends $pb.GeneratedMessage {
  factory PaymentRecord({
    $core.String? orderId,
    $fixnum.Int64? amount,
    $core.String? currency,
    $core.String? status,
    $core.String? planDuration,
    $fixnum.Int64? createdAt,
  }) {
    final result = create();
    if (orderId != null) result.orderId = orderId;
    if (amount != null) result.amount = amount;
    if (currency != null) result.currency = currency;
    if (status != null) result.status = status;
    if (planDuration != null) result.planDuration = planDuration;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  PaymentRecord._();

  factory PaymentRecord.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PaymentRecord.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaymentRecord',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'orderId')
    ..aInt64(2, _omitFieldNames ? '' : 'amount')
    ..aOS(3, _omitFieldNames ? '' : 'currency')
    ..aOS(4, _omitFieldNames ? '' : 'status')
    ..aOS(5, _omitFieldNames ? '' : 'planDuration')
    ..aInt64(6, _omitFieldNames ? '' : 'createdAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentRecord clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentRecord copyWith(void Function(PaymentRecord) updates) =>
      super.copyWith((message) => updates(message as PaymentRecord))
          as PaymentRecord;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentRecord create() => PaymentRecord._();
  @$core.override
  PaymentRecord createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PaymentRecord getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PaymentRecord>(create);
  static PaymentRecord? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get orderId => $_getSZ(0);
  @$pb.TagNumber(1)
  set orderId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrderId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrderId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get amount => $_getI64(1);
  @$pb.TagNumber(2)
  set amount($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAmount() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get currency => $_getSZ(2);
  @$pb.TagNumber(3)
  set currency($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCurrency() => $_has(2);
  @$pb.TagNumber(3)
  void clearCurrency() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get status => $_getSZ(3);
  @$pb.TagNumber(4)
  set status($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get planDuration => $_getSZ(4);
  @$pb.TagNumber(5)
  set planDuration($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPlanDuration() => $_has(4);
  @$pb.TagNumber(5)
  void clearPlanDuration() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get createdAt => $_getI64(5);
  @$pb.TagNumber(6)
  set createdAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => $_clearField(6);
}

class GetTournamentListRequest extends $pb.GeneratedMessage {
  factory GetTournamentListRequest() => create();

  GetTournamentListRequest._();

  factory GetTournamentListRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTournamentListRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTournamentListRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTournamentListRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTournamentListRequest copyWith(
          void Function(GetTournamentListRequest) updates) =>
      super.copyWith((message) => updates(message as GetTournamentListRequest))
          as GetTournamentListRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTournamentListRequest create() => GetTournamentListRequest._();
  @$core.override
  GetTournamentListRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTournamentListRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTournamentListRequest>(create);
  static GetTournamentListRequest? _defaultInstance;
}

class GetTournamentListResponse extends $pb.GeneratedMessage {
  factory GetTournamentListResponse({
    $core.Iterable<TournamentInfo>? tournaments,
  }) {
    final result = create();
    if (tournaments != null) result.tournaments.addAll(tournaments);
    return result;
  }

  GetTournamentListResponse._();

  factory GetTournamentListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTournamentListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTournamentListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..pPM<TournamentInfo>(1, _omitFieldNames ? '' : 'tournaments',
        subBuilder: TournamentInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTournamentListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTournamentListResponse copyWith(
          void Function(GetTournamentListResponse) updates) =>
      super.copyWith((message) => updates(message as GetTournamentListResponse))
          as GetTournamentListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTournamentListResponse create() => GetTournamentListResponse._();
  @$core.override
  GetTournamentListResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTournamentListResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTournamentListResponse>(create);
  static GetTournamentListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TournamentInfo> get tournaments => $_getList(0);
}

class TournamentInfo extends $pb.GeneratedMessage {
  factory TournamentInfo({
    $core.String? id,
    $core.String? name,
    $fixnum.Int64? startTime,
    $fixnum.Int64? endTime,
    $core.String? status,
    $core.int? participantCount,
    $core.String? requiredPlan,
    $core.String? prizeDescription,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
    if (status != null) result.status = status;
    if (participantCount != null) result.participantCount = participantCount;
    if (requiredPlan != null) result.requiredPlan = requiredPlan;
    if (prizeDescription != null) result.prizeDescription = prizeDescription;
    return result;
  }

  TournamentInfo._();

  factory TournamentInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TournamentInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TournamentInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aInt64(3, _omitFieldNames ? '' : 'startTime')
    ..aInt64(4, _omitFieldNames ? '' : 'endTime')
    ..aOS(5, _omitFieldNames ? '' : 'status')
    ..aI(6, _omitFieldNames ? '' : 'participantCount')
    ..aOS(7, _omitFieldNames ? '' : 'requiredPlan')
    ..aOS(8, _omitFieldNames ? '' : 'prizeDescription')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TournamentInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TournamentInfo copyWith(void Function(TournamentInfo) updates) =>
      super.copyWith((message) => updates(message as TournamentInfo))
          as TournamentInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TournamentInfo create() => TournamentInfo._();
  @$core.override
  TournamentInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TournamentInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TournamentInfo>(create);
  static TournamentInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get startTime => $_getI64(2);
  @$pb.TagNumber(3)
  set startTime($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartTime() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get endTime => $_getI64(3);
  @$pb.TagNumber(4)
  set endTime($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEndTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndTime() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get status => $_getSZ(4);
  @$pb.TagNumber(5)
  set status($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatus() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get participantCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set participantCount($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasParticipantCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearParticipantCount() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get requiredPlan => $_getSZ(6);
  @$pb.TagNumber(7)
  set requiredPlan($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRequiredPlan() => $_has(6);
  @$pb.TagNumber(7)
  void clearRequiredPlan() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get prizeDescription => $_getSZ(7);
  @$pb.TagNumber(8)
  set prizeDescription($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPrizeDescription() => $_has(7);
  @$pb.TagNumber(8)
  void clearPrizeDescription() => $_clearField(8);
}

class JoinTournamentRequest extends $pb.GeneratedMessage {
  factory JoinTournamentRequest({
    $core.String? tournamentId,
  }) {
    final result = create();
    if (tournamentId != null) result.tournamentId = tournamentId;
    return result;
  }

  JoinTournamentRequest._();

  factory JoinTournamentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinTournamentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinTournamentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'tournamentId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinTournamentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinTournamentRequest copyWith(
          void Function(JoinTournamentRequest) updates) =>
      super.copyWith((message) => updates(message as JoinTournamentRequest))
          as JoinTournamentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinTournamentRequest create() => JoinTournamentRequest._();
  @$core.override
  JoinTournamentRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinTournamentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinTournamentRequest>(create);
  static JoinTournamentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get tournamentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set tournamentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTournamentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTournamentId() => $_clearField(1);
}

class JoinTournamentResponse extends $pb.GeneratedMessage {
  factory JoinTournamentResponse({
    $core.bool? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  JoinTournamentResponse._();

  factory JoinTournamentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinTournamentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinTournamentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'quiz'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinTournamentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinTournamentResponse copyWith(
          void Function(JoinTournamentResponse) updates) =>
      super.copyWith((message) => updates(message as JoinTournamentResponse))
          as JoinTournamentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinTournamentResponse create() => JoinTournamentResponse._();
  @$core.override
  JoinTournamentResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinTournamentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinTournamentResponse>(create);
  static JoinTournamentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
