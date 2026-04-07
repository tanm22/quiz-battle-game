// This is a generated file - do not edit.
//
// Generated from proto/quiz.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use matchmakingStatusDescriptor instead')
const MatchmakingStatus$json = {
  '1': 'MatchmakingStatus',
  '2': [
    {'1': 'QUEUED', '2': 0},
    {'1': 'ALREADY_IN_QUEUE', '2': 1},
  ],
};

/// Descriptor for `MatchmakingStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List matchmakingStatusDescriptor = $convert.base64Decode(
    'ChFNYXRjaG1ha2luZ1N0YXR1cxIKCgZRVUVVRUQQABIUChBBTFJFQURZX0lOX1FVRVVFEAE=');

@$core.Deprecated('Use joinMatchmakingRequestDescriptor instead')
const JoinMatchmakingRequest$json = {
  '1': 'JoinMatchmakingRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'rating', '3': 2, '4': 1, '5': 5, '10': 'rating'},
  ],
};

/// Descriptor for `JoinMatchmakingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinMatchmakingRequestDescriptor =
    $convert.base64Decode(
        'ChZKb2luTWF0Y2htYWtpbmdSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIWCgZyYX'
        'RpbmcYAiABKAVSBnJhdGluZw==');

@$core.Deprecated('Use joinMatchmakingResponseDescriptor instead')
const JoinMatchmakingResponse$json = {
  '1': 'JoinMatchmakingResponse',
  '2': [
    {
      '1': 'status',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.quiz.MatchmakingStatus',
      '10': 'status'
    },
  ],
};

/// Descriptor for `JoinMatchmakingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinMatchmakingResponseDescriptor =
    $convert.base64Decode(
        'ChdKb2luTWF0Y2htYWtpbmdSZXNwb25zZRIvCgZzdGF0dXMYASABKA4yFy5xdWl6Lk1hdGNobW'
        'FraW5nU3RhdHVzUgZzdGF0dXM=');

@$core.Deprecated('Use leaveMatchmakingRequestDescriptor instead')
const LeaveMatchmakingRequest$json = {
  '1': 'LeaveMatchmakingRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `LeaveMatchmakingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaveMatchmakingRequestDescriptor =
    $convert.base64Decode(
        'ChdMZWF2ZU1hdGNobWFraW5nUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQ=');

@$core.Deprecated('Use leaveMatchmakingResponseDescriptor instead')
const LeaveMatchmakingResponse$json = {
  '1': 'LeaveMatchmakingResponse',
  '2': [
    {'1': 'removed', '3': 1, '4': 1, '5': 8, '10': 'removed'},
  ],
};

/// Descriptor for `LeaveMatchmakingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaveMatchmakingResponseDescriptor =
    $convert.base64Decode(
        'ChhMZWF2ZU1hdGNobWFraW5nUmVzcG9uc2USGAoHcmVtb3ZlZBgBIAEoCFIHcmVtb3ZlZA==');

@$core.Deprecated('Use subscribeToMatchRequestDescriptor instead')
const SubscribeToMatchRequest$json = {
  '1': 'SubscribeToMatchRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'sequence_number', '3': 2, '4': 1, '5': 3, '10': 'sequenceNumber'},
  ],
};

/// Descriptor for `SubscribeToMatchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscribeToMatchRequestDescriptor =
    $convert.base64Decode(
        'ChdTdWJzY3JpYmVUb01hdGNoUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSJwoPc2'
        'VxdWVuY2VfbnVtYmVyGAIgASgDUg5zZXF1ZW5jZU51bWJlcg==');

@$core.Deprecated('Use matchEventDescriptor instead')
const MatchEvent$json = {
  '1': 'MatchEvent',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'players', '3': 2, '4': 3, '5': 9, '10': 'players'},
    {'1': 'sequence_number', '3': 3, '4': 1, '5': 3, '10': 'sequenceNumber'},
  ],
};

/// Descriptor for `MatchEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matchEventDescriptor = $convert.base64Decode(
    'CgpNYXRjaEV2ZW50EhcKB3Jvb21faWQYASABKAlSBnJvb21JZBIYCgdwbGF5ZXJzGAIgAygJUg'
    'dwbGF5ZXJzEicKD3NlcXVlbmNlX251bWJlchgDIAEoA1IOc2VxdWVuY2VOdW1iZXI=');

@$core.Deprecated('Use getRoomQuestionsRequestDescriptor instead')
const GetRoomQuestionsRequest$json = {
  '1': 'GetRoomQuestionsRequest',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
  ],
};

/// Descriptor for `GetRoomQuestionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getRoomQuestionsRequestDescriptor =
    $convert.base64Decode(
        'ChdHZXRSb29tUXVlc3Rpb25zUmVxdWVzdBIXCgdyb29tX2lkGAEgASgJUgZyb29tSWQ=');

@$core.Deprecated('Use getRoomQuestionsResponseDescriptor instead')
const GetRoomQuestionsResponse$json = {
  '1': 'GetRoomQuestionsResponse',
  '2': [
    {
      '1': 'questions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.quiz.Question',
      '10': 'questions'
    },
  ],
};

/// Descriptor for `GetRoomQuestionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getRoomQuestionsResponseDescriptor =
    $convert.base64Decode(
        'ChhHZXRSb29tUXVlc3Rpb25zUmVzcG9uc2USLAoJcXVlc3Rpb25zGAEgAygLMg4ucXVpei5RdW'
        'VzdGlvblIJcXVlc3Rpb25z');

@$core.Deprecated('Use questionDescriptor instead')
const Question$json = {
  '1': 'Question',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'options', '3': 3, '4': 3, '5': 9, '10': 'options'},
    {'1': 'difficulty', '3': 4, '4': 1, '5': 9, '10': 'difficulty'},
    {'1': 'topic', '3': 5, '4': 1, '5': 9, '10': 'topic'},
  ],
};

/// Descriptor for `Question`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List questionDescriptor = $convert.base64Decode(
    'CghRdWVzdGlvbhIOCgJpZBgBIAEoCVICaWQSEgoEdGV4dBgCIAEoCVIEdGV4dBIYCgdvcHRpb2'
    '5zGAMgAygJUgdvcHRpb25zEh4KCmRpZmZpY3VsdHkYBCABKAlSCmRpZmZpY3VsdHkSFAoFdG9w'
    'aWMYBSABKAlSBXRvcGlj');

@$core.Deprecated('Use submitAnswerRequestDescriptor instead')
const SubmitAnswerRequest$json = {
  '1': 'SubmitAnswerRequest',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'round', '3': 3, '4': 1, '5': 5, '10': 'round'},
    {'1': 'option_index', '3': 4, '4': 1, '5': 5, '10': 'optionIndex'},
    {'1': 'client_timestamp', '3': 5, '4': 1, '5': 3, '10': 'clientTimestamp'},
  ],
};

/// Descriptor for `SubmitAnswerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitAnswerRequestDescriptor = $convert.base64Decode(
    'ChNTdWJtaXRBbnN3ZXJSZXF1ZXN0EhcKB3Jvb21faWQYASABKAlSBnJvb21JZBIXCgd1c2VyX2'
    'lkGAIgASgJUgZ1c2VySWQSFAoFcm91bmQYAyABKAVSBXJvdW5kEiEKDG9wdGlvbl9pbmRleBgE'
    'IAEoBVILb3B0aW9uSW5kZXgSKQoQY2xpZW50X3RpbWVzdGFtcBgFIAEoA1IPY2xpZW50VGltZX'
    'N0YW1w');

@$core.Deprecated('Use submitAnswerResponseDescriptor instead')
const SubmitAnswerResponse$json = {
  '1': 'SubmitAnswerResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
  ],
};

/// Descriptor for `SubmitAnswerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitAnswerResponseDescriptor =
    $convert.base64Decode(
        'ChRTdWJtaXRBbnN3ZXJSZXNwb25zZRIaCghhY2NlcHRlZBgBIAEoCFIIYWNjZXB0ZWQ=');

@$core.Deprecated('Use streamGameEventsRequestDescriptor instead')
const StreamGameEventsRequest$json = {
  '1': 'StreamGameEventsRequest',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'sequence_number', '3': 3, '4': 1, '5': 3, '10': 'sequenceNumber'},
  ],
};

/// Descriptor for `StreamGameEventsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamGameEventsRequestDescriptor = $convert.base64Decode(
    'ChdTdHJlYW1HYW1lRXZlbnRzUmVxdWVzdBIXCgdyb29tX2lkGAEgASgJUgZyb29tSWQSFwoHdX'
    'Nlcl9pZBgCIAEoCVIGdXNlcklkEicKD3NlcXVlbmNlX251bWJlchgDIAEoA1IOc2VxdWVuY2VO'
    'dW1iZXI=');

@$core.Deprecated('Use gameEventDescriptor instead')
const GameEvent$json = {
  '1': 'GameEvent',
  '2': [
    {'1': 'sequence_number', '3': 7, '4': 1, '5': 3, '10': 'sequenceNumber'},
    {
      '1': 'question',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.quiz.QuestionBroadcast',
      '9': 0,
      '10': 'question'
    },
    {
      '1': 'leaderboard',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.quiz.LeaderboardUpdate',
      '9': 0,
      '10': 'leaderboard'
    },
    {
      '1': 'round_result',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.quiz.RoundResult',
      '9': 0,
      '10': 'roundResult'
    },
    {
      '1': 'match_end',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.quiz.MatchEnd',
      '9': 0,
      '10': 'matchEnd'
    },
    {
      '1': 'player_joined',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.quiz.PlayerJoined',
      '9': 0,
      '10': 'playerJoined'
    },
    {
      '1': 'timer_sync',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.quiz.TimerSync',
      '9': 0,
      '10': 'timerSync'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `GameEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gameEventDescriptor = $convert.base64Decode(
    'CglHYW1lRXZlbnQSJwoPc2VxdWVuY2VfbnVtYmVyGAcgASgDUg5zZXF1ZW5jZU51bWJlchI1Cg'
    'hxdWVzdGlvbhgBIAEoCzIXLnF1aXouUXVlc3Rpb25Ccm9hZGNhc3RIAFIIcXVlc3Rpb24SOwoL'
    'bGVhZGVyYm9hcmQYAiABKAsyFy5xdWl6LkxlYWRlcmJvYXJkVXBkYXRlSABSC2xlYWRlcmJvYX'
    'JkEjYKDHJvdW5kX3Jlc3VsdBgDIAEoCzIRLnF1aXouUm91bmRSZXN1bHRIAFILcm91bmRSZXN1'
    'bHQSLQoJbWF0Y2hfZW5kGAQgASgLMg4ucXVpei5NYXRjaEVuZEgAUghtYXRjaEVuZBI5Cg1wbG'
    'F5ZXJfam9pbmVkGAUgASgLMhIucXVpei5QbGF5ZXJKb2luZWRIAFIMcGxheWVySm9pbmVkEjAK'
    'CnRpbWVyX3N5bmMYBiABKAsyDy5xdWl6LlRpbWVyU3luY0gAUgl0aW1lclN5bmNCBwoFZXZlbn'
    'Q=');

@$core.Deprecated('Use questionBroadcastDescriptor instead')
const QuestionBroadcast$json = {
  '1': 'QuestionBroadcast',
  '2': [
    {'1': 'question_id', '3': 1, '4': 1, '5': 9, '10': 'questionId'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'options', '3': 3, '4': 3, '5': 9, '10': 'options'},
    {'1': 'deadline_unix', '3': 4, '4': 1, '5': 3, '10': 'deadlineUnix'},
    {'1': 'round', '3': 5, '4': 1, '5': 5, '10': 'round'},
  ],
};

/// Descriptor for `QuestionBroadcast`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List questionBroadcastDescriptor = $convert.base64Decode(
    'ChFRdWVzdGlvbkJyb2FkY2FzdBIfCgtxdWVzdGlvbl9pZBgBIAEoCVIKcXVlc3Rpb25JZBISCg'
    'R0ZXh0GAIgASgJUgR0ZXh0EhgKB29wdGlvbnMYAyADKAlSB29wdGlvbnMSIwoNZGVhZGxpbmVf'
    'dW5peBgEIAEoA1IMZGVhZGxpbmVVbml4EhQKBXJvdW5kGAUgASgFUgVyb3VuZA==');

@$core.Deprecated('Use leaderboardUpdateDescriptor instead')
const LeaderboardUpdate$json = {
  '1': 'LeaderboardUpdate',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.quiz.LeaderboardEntry',
      '10': 'entries'
    },
  ],
};

/// Descriptor for `LeaderboardUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaderboardUpdateDescriptor = $convert.base64Decode(
    'ChFMZWFkZXJib2FyZFVwZGF0ZRIwCgdlbnRyaWVzGAEgAygLMhYucXVpei5MZWFkZXJib2FyZE'
    'VudHJ5UgdlbnRyaWVz');

@$core.Deprecated('Use leaderboardEntryDescriptor instead')
const LeaderboardEntry$json = {
  '1': 'LeaderboardEntry',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {'1': 'score', '3': 3, '4': 1, '5': 1, '10': 'score'},
    {'1': 'rank', '3': 4, '4': 1, '5': 5, '10': 'rank'},
  ],
};

/// Descriptor for `LeaderboardEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaderboardEntryDescriptor = $convert.base64Decode(
    'ChBMZWFkZXJib2FyZEVudHJ5EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIaCgh1c2VybmFtZR'
    'gCIAEoCVIIdXNlcm5hbWUSFAoFc2NvcmUYAyABKAFSBXNjb3JlEhIKBHJhbmsYBCABKAVSBHJh'
    'bms=');

@$core.Deprecated('Use roundResultDescriptor instead')
const RoundResult$json = {
  '1': 'RoundResult',
  '2': [
    {'1': 'round', '3': 1, '4': 1, '5': 5, '10': 'round'},
    {'1': 'correct_index', '3': 2, '4': 1, '5': 5, '10': 'correctIndex'},
  ],
};

/// Descriptor for `RoundResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List roundResultDescriptor = $convert.base64Decode(
    'CgtSb3VuZFJlc3VsdBIUCgVyb3VuZBgBIAEoBVIFcm91bmQSIwoNY29ycmVjdF9pbmRleBgCIA'
    'EoBVIMY29ycmVjdEluZGV4');

@$core.Deprecated('Use matchEndDescriptor instead')
const MatchEnd$json = {
  '1': 'MatchEnd',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'winner', '3': 2, '4': 1, '5': 9, '10': 'winner'},
    {
      '1': 'players',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.quiz.PlayerResult',
      '10': 'players'
    },
    {'1': 'rounds', '3': 4, '4': 1, '5': 5, '10': 'rounds'},
    {'1': 'duration', '3': 5, '4': 1, '5': 3, '10': 'duration'},
  ],
};

/// Descriptor for `MatchEnd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matchEndDescriptor = $convert.base64Decode(
    'CghNYXRjaEVuZBIXCgdyb29tX2lkGAEgASgJUgZyb29tSWQSFgoGd2lubmVyGAIgASgJUgZ3aW'
    '5uZXISLAoHcGxheWVycxgDIAMoCzISLnF1aXouUGxheWVyUmVzdWx0UgdwbGF5ZXJzEhYKBnJv'
    'dW5kcxgEIAEoBVIGcm91bmRzEhoKCGR1cmF0aW9uGAUgASgDUghkdXJhdGlvbg==');

@$core.Deprecated('Use playerResultDescriptor instead')
const PlayerResult$json = {
  '1': 'PlayerResult',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {'1': 'final_score', '3': 3, '4': 1, '5': 1, '10': 'finalScore'},
    {'1': 'rank', '3': 4, '4': 1, '5': 5, '10': 'rank'},
    {'1': 'answers_correct', '3': 5, '4': 1, '5': 5, '10': 'answersCorrect'},
    {
      '1': 'avg_response_time_ms',
      '3': 6,
      '4': 1,
      '5': 1,
      '10': 'avgResponseTimeMs'
    },
  ],
};

/// Descriptor for `PlayerResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerResultDescriptor = $convert.base64Decode(
    'CgxQbGF5ZXJSZXN1bHQSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhoKCHVzZXJuYW1lGAIgAS'
    'gJUgh1c2VybmFtZRIfCgtmaW5hbF9zY29yZRgDIAEoAVIKZmluYWxTY29yZRISCgRyYW5rGAQg'
    'ASgFUgRyYW5rEicKD2Fuc3dlcnNfY29ycmVjdBgFIAEoBVIOYW5zd2Vyc0NvcnJlY3QSLwoUYX'
    'ZnX3Jlc3BvbnNlX3RpbWVfbXMYBiABKAFSEWF2Z1Jlc3BvbnNlVGltZU1z');

@$core.Deprecated('Use playerJoinedDescriptor instead')
const PlayerJoined$json = {
  '1': 'PlayerJoined',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
  ],
};

/// Descriptor for `PlayerJoined`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerJoinedDescriptor = $convert.base64Decode(
    'CgxQbGF5ZXJKb2luZWQSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhoKCHVzZXJuYW1lGAIgAS'
    'gJUgh1c2VybmFtZQ==');

@$core.Deprecated('Use timerSyncDescriptor instead')
const TimerSync$json = {
  '1': 'TimerSync',
  '2': [
    {'1': 'deadline_unix', '3': 1, '4': 1, '5': 3, '10': 'deadlineUnix'},
  ],
};

/// Descriptor for `TimerSync`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List timerSyncDescriptor = $convert.base64Decode(
    'CglUaW1lclN5bmMSIwoNZGVhZGxpbmVfdW5peBgBIAEoA1IMZGVhZGxpbmVVbml4');

@$core.Deprecated('Use calculateScoreRequestDescriptor instead')
const CalculateScoreRequest$json = {
  '1': 'CalculateScoreRequest',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'round', '3': 3, '4': 1, '5': 5, '10': 'round'},
    {'1': 'option_index', '3': 4, '4': 1, '5': 5, '10': 'optionIndex'},
    {'1': 'answer_time_ms', '3': 5, '4': 1, '5': 3, '10': 'answerTimeMs'},
  ],
};

/// Descriptor for `CalculateScoreRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List calculateScoreRequestDescriptor = $convert.base64Decode(
    'ChVDYWxjdWxhdGVTY29yZVJlcXVlc3QSFwoHcm9vbV9pZBgBIAEoCVIGcm9vbUlkEhcKB3VzZX'
    'JfaWQYAiABKAlSBnVzZXJJZBIUCgVyb3VuZBgDIAEoBVIFcm91bmQSIQoMb3B0aW9uX2luZGV4'
    'GAQgASgFUgtvcHRpb25JbmRleBIkCg5hbnN3ZXJfdGltZV9tcxgFIAEoA1IMYW5zd2VyVGltZU'
    '1z');

@$core.Deprecated('Use calculateScoreResponseDescriptor instead')
const CalculateScoreResponse$json = {
  '1': 'CalculateScoreResponse',
  '2': [
    {'1': 'score', '3': 1, '4': 1, '5': 1, '10': 'score'},
    {'1': 'correct', '3': 2, '4': 1, '5': 8, '10': 'correct'},
    {'1': 'speed_multiplier', '3': 3, '4': 1, '5': 1, '10': 'speedMultiplier'},
  ],
};

/// Descriptor for `CalculateScoreResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List calculateScoreResponseDescriptor = $convert.base64Decode(
    'ChZDYWxjdWxhdGVTY29yZVJlc3BvbnNlEhQKBXNjb3JlGAEgASgBUgVzY29yZRIYCgdjb3JyZW'
    'N0GAIgASgIUgdjb3JyZWN0EikKEHNwZWVkX211bHRpcGxpZXIYAyABKAFSD3NwZWVkTXVsdGlw'
    'bGllcg==');

@$core.Deprecated('Use getLeaderboardRequestDescriptor instead')
const GetLeaderboardRequest$json = {
  '1': 'GetLeaderboardRequest',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
  ],
};

/// Descriptor for `GetLeaderboardRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getLeaderboardRequestDescriptor =
    $convert.base64Decode(
        'ChVHZXRMZWFkZXJib2FyZFJlcXVlc3QSFwoHcm9vbV9pZBgBIAEoCVIGcm9vbUlk');

@$core.Deprecated('Use getLeaderboardResponseDescriptor instead')
const GetLeaderboardResponse$json = {
  '1': 'GetLeaderboardResponse',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.quiz.LeaderboardEntry',
      '10': 'entries'
    },
  ],
};

/// Descriptor for `GetLeaderboardResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getLeaderboardResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRMZWFkZXJib2FyZFJlc3BvbnNlEjAKB2VudHJpZXMYASADKAsyFi5xdWl6LkxlYWRlcm'
        'JvYXJkRW50cnlSB2VudHJpZXM=');
