// This is a generated file - do not edit.
//
// Generated from quiz.proto.

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
    {'1': 'plan', '3': 5, '4': 1, '5': 9, '10': 'plan'},
  ],
};

/// Descriptor for `LeaderboardEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaderboardEntryDescriptor = $convert.base64Decode(
    'ChBMZWFkZXJib2FyZEVudHJ5EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIaCgh1c2VybmFtZR'
    'gCIAEoCVIIdXNlcm5hbWUSFAoFc2NvcmUYAyABKAFSBXNjb3JlEhIKBHJhbmsYBCABKAVSBHJh'
    'bmsSEgoEcGxhbhgFIAEoCVIEcGxhbg==');

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
    {'1': 'plan', '3': 7, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'coins_awarded', '3': 8, '4': 1, '5': 3, '10': 'coinsAwarded'},
  ],
};

/// Descriptor for `PlayerResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerResultDescriptor = $convert.base64Decode(
    'CgxQbGF5ZXJSZXN1bHQSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhoKCHVzZXJuYW1lGAIgAS'
    'gJUgh1c2VybmFtZRIfCgtmaW5hbF9zY29yZRgDIAEoAVIKZmluYWxTY29yZRISCgRyYW5rGAQg'
    'ASgFUgRyYW5rEicKD2Fuc3dlcnNfY29ycmVjdBgFIAEoBVIOYW5zd2Vyc0NvcnJlY3QSLwoUYX'
    'ZnX3Jlc3BvbnNlX3RpbWVfbXMYBiABKAFSEWF2Z1Jlc3BvbnNlVGltZU1zEhIKBHBsYW4YByAB'
    'KAlSBHBsYW4SIwoNY29pbnNfYXdhcmRlZBgIIAEoA1IMY29pbnNBd2FyZGVk');

@$core.Deprecated('Use playerJoinedDescriptor instead')
const PlayerJoined$json = {
  '1': 'PlayerJoined',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {'1': 'plan', '3': 3, '4': 1, '5': 9, '10': 'plan'},
  ],
};

/// Descriptor for `PlayerJoined`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerJoinedDescriptor = $convert.base64Decode(
    'CgxQbGF5ZXJKb2luZWQSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhoKCHVzZXJuYW1lGAIgAS'
    'gJUgh1c2VybmFtZRISCgRwbGFuGAMgASgJUgRwbGFu');

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

@$core.Deprecated('Use registerRequestDescriptor instead')
const RegisterRequest$json = {
  '1': 'RegisterRequest',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
    {'1': 'password', '3': 2, '4': 1, '5': 9, '10': 'password'},
    {'1': 'email', '3': 3, '4': 1, '5': 9, '10': 'email'},
    {'1': 'referral_code', '3': 4, '4': 1, '5': 9, '10': 'referralCode'},
  ],
};

/// Descriptor for `RegisterRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerRequestDescriptor = $convert.base64Decode(
    'Cg9SZWdpc3RlclJlcXVlc3QSGgoIdXNlcm5hbWUYASABKAlSCHVzZXJuYW1lEhoKCHBhc3N3b3'
    'JkGAIgASgJUghwYXNzd29yZBIUCgVlbWFpbBgDIAEoCVIFZW1haWwSIwoNcmVmZXJyYWxfY29k'
    'ZRgEIAEoCVIMcmVmZXJyYWxDb2Rl');

@$core.Deprecated('Use loginRequestDescriptor instead')
const LoginRequest$json = {
  '1': 'LoginRequest',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
    {'1': 'password', '3': 2, '4': 1, '5': 9, '10': 'password'},
  ],
};

/// Descriptor for `LoginRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginRequestDescriptor = $convert.base64Decode(
    'CgxMb2dpblJlcXVlc3QSGgoIdXNlcm5hbWUYASABKAlSCHVzZXJuYW1lEhoKCHBhc3N3b3JkGA'
    'IgASgJUghwYXNzd29yZA==');

@$core.Deprecated('Use authResponseDescriptor instead')
const AuthResponse$json = {
  '1': 'AuthResponse',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {'1': 'token', '3': 3, '4': 1, '5': 9, '10': 'token'},
    {'1': 'rating', '3': 4, '4': 1, '5': 5, '10': 'rating'},
    {'1': 'matches_played', '3': 5, '4': 1, '5': 5, '10': 'matchesPlayed'},
    {'1': 'wins', '3': 6, '4': 1, '5': 5, '10': 'wins'},
    {'1': 'email', '3': 7, '4': 1, '5': 9, '10': 'email'},
    {'1': 'is_guest', '3': 8, '4': 1, '5': 8, '10': 'isGuest'},
    {'1': 'plan', '3': 9, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'coins', '3': 10, '4': 1, '5': 3, '10': 'coins'},
    {
      '1': 'streak',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.quiz.StreakInfo',
      '10': 'streak'
    },
    {'1': 'referral_code', '3': 12, '4': 1, '5': 9, '10': 'referralCode'},
    {'1': 'streak_updated', '3': 13, '4': 1, '5': 8, '10': 'streakUpdated'},
    {
      '1': 'reward',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.quiz.RewardGrant',
      '10': 'reward'
    },
    {
      '1': 'onboarding_completed',
      '3': 15,
      '4': 1,
      '5': 8,
      '10': 'onboardingCompleted'
    },
  ],
};

/// Descriptor for `AuthResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List authResponseDescriptor = $convert.base64Decode(
    'CgxBdXRoUmVzcG9uc2USFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhoKCHVzZXJuYW1lGAIgAS'
    'gJUgh1c2VybmFtZRIUCgV0b2tlbhgDIAEoCVIFdG9rZW4SFgoGcmF0aW5nGAQgASgFUgZyYXRp'
    'bmcSJQoObWF0Y2hlc19wbGF5ZWQYBSABKAVSDW1hdGNoZXNQbGF5ZWQSEgoEd2lucxgGIAEoBV'
    'IEd2lucxIUCgVlbWFpbBgHIAEoCVIFZW1haWwSGQoIaXNfZ3Vlc3QYCCABKAhSB2lzR3Vlc3QS'
    'EgoEcGxhbhgJIAEoCVIEcGxhbhIUCgVjb2lucxgKIAEoA1IFY29pbnMSKAoGc3RyZWFrGAsgAS'
    'gLMhAucXVpei5TdHJlYWtJbmZvUgZzdHJlYWsSIwoNcmVmZXJyYWxfY29kZRgMIAEoCVIMcmVm'
    'ZXJyYWxDb2RlEiUKDnN0cmVha191cGRhdGVkGA0gASgIUg1zdHJlYWtVcGRhdGVkEikKBnJld2'
    'FyZBgOIAEoCzIRLnF1aXouUmV3YXJkR3JhbnRSBnJld2FyZBIxChRvbmJvYXJkaW5nX2NvbXBs'
    'ZXRlZBgPIAEoCFITb25ib2FyZGluZ0NvbXBsZXRlZA==');

@$core.Deprecated('Use getProfileRequestDescriptor instead')
const GetProfileRequest$json = {
  '1': 'GetProfileRequest',
};

/// Descriptor for `GetProfileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProfileRequestDescriptor =
    $convert.base64Decode('ChFHZXRQcm9maWxlUmVxdWVzdA==');

@$core.Deprecated('Use profileResponseDescriptor instead')
const ProfileResponse$json = {
  '1': 'ProfileResponse',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {'1': 'rating', '3': 3, '4': 1, '5': 5, '10': 'rating'},
    {'1': 'matches_played', '3': 4, '4': 1, '5': 5, '10': 'matchesPlayed'},
    {'1': 'wins', '3': 5, '4': 1, '5': 5, '10': 'wins'},
    {'1': 'email', '3': 6, '4': 1, '5': 9, '10': 'email'},
    {'1': 'is_guest', '3': 7, '4': 1, '5': 8, '10': 'isGuest'},
    {'1': 'plan', '3': 8, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'coins', '3': 9, '4': 1, '5': 3, '10': 'coins'},
    {
      '1': 'streak',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.quiz.StreakInfo',
      '10': 'streak'
    },
    {'1': 'referral_code', '3': 11, '4': 1, '5': 9, '10': 'referralCode'},
    {'1': 'display_name', '3': 12, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'avatar_url', '3': 13, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'preferred_topics', '3': 14, '4': 3, '5': 9, '10': 'preferredTopics'},
    {
      '1': 'onboarding_completed',
      '3': 15,
      '4': 1,
      '5': 8,
      '10': 'onboardingCompleted'
    },
  ],
};

/// Descriptor for `ProfileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List profileResponseDescriptor = $convert.base64Decode(
    'Cg9Qcm9maWxlUmVzcG9uc2USFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhoKCHVzZXJuYW1lGA'
    'IgASgJUgh1c2VybmFtZRIWCgZyYXRpbmcYAyABKAVSBnJhdGluZxIlCg5tYXRjaGVzX3BsYXll'
    'ZBgEIAEoBVINbWF0Y2hlc1BsYXllZBISCgR3aW5zGAUgASgFUgR3aW5zEhQKBWVtYWlsGAYgAS'
    'gJUgVlbWFpbBIZCghpc19ndWVzdBgHIAEoCFIHaXNHdWVzdBISCgRwbGFuGAggASgJUgRwbGFu'
    'EhQKBWNvaW5zGAkgASgDUgVjb2lucxIoCgZzdHJlYWsYCiABKAsyEC5xdWl6LlN0cmVha0luZm'
    '9SBnN0cmVhaxIjCg1yZWZlcnJhbF9jb2RlGAsgASgJUgxyZWZlcnJhbENvZGUSIQoMZGlzcGxh'
    'eV9uYW1lGAwgASgJUgtkaXNwbGF5TmFtZRIdCgphdmF0YXJfdXJsGA0gASgJUglhdmF0YXJVcm'
    'wSKQoQcHJlZmVycmVkX3RvcGljcxgOIAMoCVIPcHJlZmVycmVkVG9waWNzEjEKFG9uYm9hcmRp'
    'bmdfY29tcGxldGVkGA8gASgIUhNvbmJvYXJkaW5nQ29tcGxldGVk');

@$core.Deprecated('Use guestLoginRequestDescriptor instead')
const GuestLoginRequest$json = {
  '1': 'GuestLoginRequest',
};

/// Descriptor for `GuestLoginRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List guestLoginRequestDescriptor =
    $convert.base64Decode('ChFHdWVzdExvZ2luUmVxdWVzdA==');

@$core.Deprecated('Use emailLoginRequestDescriptor instead')
const EmailLoginRequest$json = {
  '1': 'EmailLoginRequest',
  '2': [
    {'1': 'email', '3': 1, '4': 1, '5': 9, '10': 'email'},
  ],
};

/// Descriptor for `EmailLoginRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emailLoginRequestDescriptor = $convert
    .base64Decode('ChFFbWFpbExvZ2luUmVxdWVzdBIUCgVlbWFpbBgBIAEoCVIFZW1haWw=');

@$core.Deprecated('Use sendEmailCodeRequestDescriptor instead')
const SendEmailCodeRequest$json = {
  '1': 'SendEmailCodeRequest',
  '2': [
    {'1': 'email', '3': 1, '4': 1, '5': 9, '10': 'email'},
    {'1': 'purpose', '3': 2, '4': 1, '5': 9, '10': 'purpose'},
  ],
};

/// Descriptor for `SendEmailCodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendEmailCodeRequestDescriptor = $convert.base64Decode(
    'ChRTZW5kRW1haWxDb2RlUmVxdWVzdBIUCgVlbWFpbBgBIAEoCVIFZW1haWwSGAoHcHVycG9zZR'
    'gCIAEoCVIHcHVycG9zZQ==');

@$core.Deprecated('Use sendEmailCodeResponseDescriptor instead')
const SendEmailCodeResponse$json = {
  '1': 'SendEmailCodeResponse',
  '2': [
    {'1': 'sent', '3': 1, '4': 1, '5': 8, '10': 'sent'},
  ],
};

/// Descriptor for `SendEmailCodeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendEmailCodeResponseDescriptor =
    $convert.base64Decode(
        'ChVTZW5kRW1haWxDb2RlUmVzcG9uc2USEgoEc2VudBgBIAEoCFIEc2VudA==');

@$core.Deprecated('Use verifyEmailCodeRequestDescriptor instead')
const VerifyEmailCodeRequest$json = {
  '1': 'VerifyEmailCodeRequest',
  '2': [
    {'1': 'email', '3': 1, '4': 1, '5': 9, '10': 'email'},
    {'1': 'code', '3': 2, '4': 1, '5': 9, '10': 'code'},
  ],
};

/// Descriptor for `VerifyEmailCodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List verifyEmailCodeRequestDescriptor =
    $convert.base64Decode(
        'ChZWZXJpZnlFbWFpbENvZGVSZXF1ZXN0EhQKBWVtYWlsGAEgASgJUgVlbWFpbBISCgRjb2RlGA'
        'IgASgJUgRjb2Rl');

@$core.Deprecated('Use verifyEmailCodeResponseDescriptor instead')
const VerifyEmailCodeResponse$json = {
  '1': 'VerifyEmailCodeResponse',
  '2': [
    {'1': 'verified', '3': 1, '4': 1, '5': 8, '10': 'verified'},
    {'1': 'token', '3': 2, '4': 1, '5': 9, '10': 'token'},
    {'1': 'user_id', '3': 3, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `VerifyEmailCodeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List verifyEmailCodeResponseDescriptor =
    $convert.base64Decode(
        'ChdWZXJpZnlFbWFpbENvZGVSZXNwb25zZRIaCgh2ZXJpZmllZBgBIAEoCFIIdmVyaWZpZWQSFA'
        'oFdG9rZW4YAiABKAlSBXRva2VuEhcKB3VzZXJfaWQYAyABKAlSBnVzZXJJZA==');

@$core.Deprecated('Use linkEmailRequestDescriptor instead')
const LinkEmailRequest$json = {
  '1': 'LinkEmailRequest',
  '2': [
    {'1': 'email', '3': 1, '4': 1, '5': 9, '10': 'email'},
    {'1': 'code', '3': 2, '4': 1, '5': 9, '10': 'code'},
  ],
};

/// Descriptor for `LinkEmailRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List linkEmailRequestDescriptor = $convert.base64Decode(
    'ChBMaW5rRW1haWxSZXF1ZXN0EhQKBWVtYWlsGAEgASgJUgVlbWFpbBISCgRjb2RlGAIgASgJUg'
    'Rjb2Rl');

@$core.Deprecated('Use linkEmailResponseDescriptor instead')
const LinkEmailResponse$json = {
  '1': 'LinkEmailResponse',
  '2': [
    {'1': 'linked', '3': 1, '4': 1, '5': 8, '10': 'linked'},
  ],
};

/// Descriptor for `LinkEmailResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List linkEmailResponseDescriptor = $convert.base64Decode(
    'ChFMaW5rRW1haWxSZXNwb25zZRIWCgZsaW5rZWQYASABKAhSBmxpbmtlZA==');

@$core.Deprecated('Use resetPasswordRequestDescriptor instead')
const ResetPasswordRequest$json = {
  '1': 'ResetPasswordRequest',
  '2': [
    {'1': 'email', '3': 1, '4': 1, '5': 9, '10': 'email'},
    {'1': 'code', '3': 2, '4': 1, '5': 9, '10': 'code'},
    {'1': 'new_password', '3': 3, '4': 1, '5': 9, '10': 'newPassword'},
  ],
};

/// Descriptor for `ResetPasswordRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resetPasswordRequestDescriptor = $convert.base64Decode(
    'ChRSZXNldFBhc3N3b3JkUmVxdWVzdBIUCgVlbWFpbBgBIAEoCVIFZW1haWwSEgoEY29kZRgCIA'
    'EoCVIEY29kZRIhCgxuZXdfcGFzc3dvcmQYAyABKAlSC25ld1Bhc3N3b3Jk');

@$core.Deprecated('Use resetPasswordResponseDescriptor instead')
const ResetPasswordResponse$json = {
  '1': 'ResetPasswordResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `ResetPasswordResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resetPasswordResponseDescriptor =
    $convert.base64Decode(
        'ChVSZXNldFBhc3N3b3JkUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2Vzcw==');

@$core.Deprecated('Use checkUsernameRequestDescriptor instead')
const CheckUsernameRequest$json = {
  '1': 'CheckUsernameRequest',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
  ],
};

/// Descriptor for `CheckUsernameRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkUsernameRequestDescriptor =
    $convert.base64Decode(
        'ChRDaGVja1VzZXJuYW1lUmVxdWVzdBIaCgh1c2VybmFtZRgBIAEoCVIIdXNlcm5hbWU=');

@$core.Deprecated('Use checkUsernameResponseDescriptor instead')
const CheckUsernameResponse$json = {
  '1': 'CheckUsernameResponse',
  '2': [
    {'1': 'available', '3': 1, '4': 1, '5': 8, '10': 'available'},
  ],
};

/// Descriptor for `CheckUsernameResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkUsernameResponseDescriptor = $convert.base64Decode(
    'ChVDaGVja1VzZXJuYW1lUmVzcG9uc2USHAoJYXZhaWxhYmxlGAEgASgIUglhdmFpbGFibGU=');

@$core.Deprecated('Use deleteAccountRequestDescriptor instead')
const DeleteAccountRequest$json = {
  '1': 'DeleteAccountRequest',
};

/// Descriptor for `DeleteAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteAccountRequestDescriptor =
    $convert.base64Decode('ChREZWxldGVBY2NvdW50UmVxdWVzdA==');

@$core.Deprecated('Use deleteAccountResponseDescriptor instead')
const DeleteAccountResponse$json = {
  '1': 'DeleteAccountResponse',
  '2': [
    {'1': 'deleted', '3': 1, '4': 1, '5': 8, '10': 'deleted'},
  ],
};

/// Descriptor for `DeleteAccountResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteAccountResponseDescriptor =
    $convert.base64Decode(
        'ChVEZWxldGVBY2NvdW50UmVzcG9uc2USGAoHZGVsZXRlZBgBIAEoCFIHZGVsZXRlZA==');

@$core.Deprecated('Use updateProfileRequestDescriptor instead')
const UpdateProfileRequest$json = {
  '1': 'UpdateProfileRequest',
  '2': [
    {'1': 'display_name', '3': 1, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'avatar_url', '3': 2, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'preferred_topics', '3': 3, '4': 3, '5': 9, '10': 'preferredTopics'},
    {
      '1': 'onboarding_completed',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'onboardingCompleted'
    },
  ],
};

/// Descriptor for `UpdateProfileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateProfileRequestDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVQcm9maWxlUmVxdWVzdBIhCgxkaXNwbGF5X25hbWUYASABKAlSC2Rpc3BsYXlOYW'
    '1lEh0KCmF2YXRhcl91cmwYAiABKAlSCWF2YXRhclVybBIpChBwcmVmZXJyZWRfdG9waWNzGAMg'
    'AygJUg9wcmVmZXJyZWRUb3BpY3MSMQoUb25ib2FyZGluZ19jb21wbGV0ZWQYBCABKAhSE29uYm'
    '9hcmRpbmdDb21wbGV0ZWQ=');

@$core.Deprecated('Use updateProfileResponseDescriptor instead')
const UpdateProfileResponse$json = {
  '1': 'UpdateProfileResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `UpdateProfileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateProfileResponseDescriptor =
    $convert.base64Decode(
        'ChVVcGRhdGVQcm9maWxlUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2Vzcw==');

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

@$core.Deprecated('Use getMatchHistoryRequestDescriptor instead')
const GetMatchHistoryRequest$json = {
  '1': 'GetMatchHistoryRequest',
  '2': [
    {'1': 'limit', '3': 1, '4': 1, '5': 5, '10': 'limit'},
    {'1': 'offset', '3': 2, '4': 1, '5': 5, '10': 'offset'},
  ],
};

/// Descriptor for `GetMatchHistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMatchHistoryRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRNYXRjaEhpc3RvcnlSZXF1ZXN0EhQKBWxpbWl0GAEgASgFUgVsaW1pdBIWCgZvZmZzZX'
        'QYAiABKAVSBm9mZnNldA==');

@$core.Deprecated('Use getMatchHistoryResponseDescriptor instead')
const GetMatchHistoryResponse$json = {
  '1': 'GetMatchHistoryResponse',
  '2': [
    {
      '1': 'matches',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.quiz.MatchHistoryEntry',
      '10': 'matches'
    },
  ],
};

/// Descriptor for `GetMatchHistoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMatchHistoryResponseDescriptor =
    $convert.base64Decode(
        'ChdHZXRNYXRjaEhpc3RvcnlSZXNwb25zZRIxCgdtYXRjaGVzGAEgAygLMhcucXVpei5NYXRjaE'
        'hpc3RvcnlFbnRyeVIHbWF0Y2hlcw==');

@$core.Deprecated('Use matchHistoryEntryDescriptor instead')
const MatchHistoryEntry$json = {
  '1': 'MatchHistoryEntry',
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
    {'1': 'created_at', '3': 6, '4': 1, '5': 3, '10': 'createdAt'},
  ],
};

/// Descriptor for `MatchHistoryEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matchHistoryEntryDescriptor = $convert.base64Decode(
    'ChFNYXRjaEhpc3RvcnlFbnRyeRIXCgdyb29tX2lkGAEgASgJUgZyb29tSWQSFgoGd2lubmVyGA'
    'IgASgJUgZ3aW5uZXISLAoHcGxheWVycxgDIAMoCzISLnF1aXouUGxheWVyUmVzdWx0UgdwbGF5'
    'ZXJzEhYKBnJvdW5kcxgEIAEoBVIGcm91bmRzEhoKCGR1cmF0aW9uGAUgASgDUghkdXJhdGlvbh'
    'IdCgpjcmVhdGVkX2F0GAYgASgDUgljcmVhdGVkQXQ=');

@$core.Deprecated('Use streakInfoDescriptor instead')
const StreakInfo$json = {
  '1': 'StreakInfo',
  '2': [
    {'1': 'current', '3': 1, '4': 1, '5': 5, '10': 'current'},
    {'1': 'longest', '3': 2, '4': 1, '5': 5, '10': 'longest'},
    {'1': 'last_claimed_date', '3': 3, '4': 1, '5': 9, '10': 'lastClaimedDate'},
  ],
};

/// Descriptor for `StreakInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streakInfoDescriptor = $convert.base64Decode(
    'CgpTdHJlYWtJbmZvEhgKB2N1cnJlbnQYASABKAVSB2N1cnJlbnQSGAoHbG9uZ2VzdBgCIAEoBV'
    'IHbG9uZ2VzdBIqChFsYXN0X2NsYWltZWRfZGF0ZRgDIAEoCVIPbGFzdENsYWltZWREYXRl');

@$core.Deprecated('Use rewardGrantDescriptor instead')
const RewardGrant$json = {
  '1': 'RewardGrant',
  '2': [
    {'1': 'coins', '3': 1, '4': 1, '5': 3, '10': 'coins'},
    {'1': 'badge_name', '3': 2, '4': 1, '5': 9, '10': 'badgeName'},
    {'1': 'bonus_quizzes', '3': 3, '4': 1, '5': 5, '10': 'bonusQuizzes'},
  ],
};

/// Descriptor for `RewardGrant`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rewardGrantDescriptor = $convert.base64Decode(
    'CgtSZXdhcmRHcmFudBIUCgVjb2lucxgBIAEoA1IFY29pbnMSHQoKYmFkZ2VfbmFtZRgCIAEoCV'
    'IJYmFkZ2VOYW1lEiMKDWJvbnVzX3F1aXp6ZXMYAyABKAVSDGJvbnVzUXVpenplcw==');

@$core.Deprecated('Use planStatusDescriptor instead')
const PlanStatus$json = {
  '1': 'PlanStatus',
  '2': [
    {'1': 'plan', '3': 1, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'expires_at', '3': 2, '4': 1, '5': 3, '10': 'expiresAt'},
  ],
};

/// Descriptor for `PlanStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List planStatusDescriptor = $convert.base64Decode(
    'CgpQbGFuU3RhdHVzEhIKBHBsYW4YASABKAlSBHBsYW4SHQoKZXhwaXJlc19hdBgCIAEoA1IJZX'
    'hwaXJlc0F0');

@$core.Deprecated('Use googleSignInRequestDescriptor instead')
const GoogleSignInRequest$json = {
  '1': 'GoogleSignInRequest',
  '2': [
    {'1': 'id_token', '3': 1, '4': 1, '5': 9, '10': 'idToken'},
    {'1': 'referral_code', '3': 2, '4': 1, '5': 9, '10': 'referralCode'},
  ],
};

/// Descriptor for `GoogleSignInRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List googleSignInRequestDescriptor = $convert.base64Decode(
    'ChNHb29nbGVTaWduSW5SZXF1ZXN0EhkKCGlkX3Rva2VuGAEgASgJUgdpZFRva2VuEiMKDXJlZm'
    'VycmFsX2NvZGUYAiABKAlSDHJlZmVycmFsQ29kZQ==');

@$core.Deprecated('Use googleSignInResponseDescriptor instead')
const GoogleSignInResponse$json = {
  '1': 'GoogleSignInResponse',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {
      '1': 'user_profile',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.quiz.UserProfile',
      '10': 'userProfile'
    },
    {'1': 'is_new_user', '3': 3, '4': 1, '5': 8, '10': 'isNewUser'},
    {'1': 'streak_updated', '3': 4, '4': 1, '5': 8, '10': 'streakUpdated'},
    {
      '1': 'reward',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.quiz.RewardGrant',
      '10': 'reward'
    },
  ],
};

/// Descriptor for `GoogleSignInResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List googleSignInResponseDescriptor = $convert.base64Decode(
    'ChRHb29nbGVTaWduSW5SZXNwb25zZRIUCgV0b2tlbhgBIAEoCVIFdG9rZW4SNAoMdXNlcl9wcm'
    '9maWxlGAIgASgLMhEucXVpei5Vc2VyUHJvZmlsZVILdXNlclByb2ZpbGUSHgoLaXNfbmV3X3Vz'
    'ZXIYAyABKAhSCWlzTmV3VXNlchIlCg5zdHJlYWtfdXBkYXRlZBgEIAEoCFINc3RyZWFrVXBkYX'
    'RlZBIpCgZyZXdhcmQYBSABKAsyES5xdWl6LlJld2FyZEdyYW50UgZyZXdhcmQ=');

@$core.Deprecated('Use userProfileDescriptor instead')
const UserProfile$json = {
  '1': 'UserProfile',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {'1': 'display_name', '3': 3, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'email', '3': 4, '4': 1, '5': 9, '10': 'email'},
    {'1': 'avatar_url', '3': 5, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'rating', '3': 6, '4': 1, '5': 5, '10': 'rating'},
    {'1': 'matches_played', '3': 7, '4': 1, '5': 5, '10': 'matchesPlayed'},
    {'1': 'wins', '3': 8, '4': 1, '5': 5, '10': 'wins'},
    {'1': 'plan', '3': 9, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'coins', '3': 10, '4': 1, '5': 3, '10': 'coins'},
    {
      '1': 'streak',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.quiz.StreakInfo',
      '10': 'streak'
    },
    {'1': 'referral_code', '3': 12, '4': 1, '5': 9, '10': 'referralCode'},
    {'1': 'is_guest', '3': 13, '4': 1, '5': 8, '10': 'isGuest'},
    {'1': 'accuracy_percent', '3': 14, '4': 1, '5': 2, '10': 'accuracyPercent'},
    {'1': 'win_streak', '3': 15, '4': 1, '5': 5, '10': 'winStreak'},
    {'1': 'preferred_topics', '3': 16, '4': 3, '5': 9, '10': 'preferredTopics'},
    {
      '1': 'onboarding_completed',
      '3': 17,
      '4': 1,
      '5': 8,
      '10': 'onboardingCompleted'
    },
  ],
};

/// Descriptor for `UserProfile`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userProfileDescriptor = $convert.base64Decode(
    'CgtVc2VyUHJvZmlsZRIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSGgoIdXNlcm5hbWUYAiABKA'
    'lSCHVzZXJuYW1lEiEKDGRpc3BsYXlfbmFtZRgDIAEoCVILZGlzcGxheU5hbWUSFAoFZW1haWwY'
    'BCABKAlSBWVtYWlsEh0KCmF2YXRhcl91cmwYBSABKAlSCWF2YXRhclVybBIWCgZyYXRpbmcYBi'
    'ABKAVSBnJhdGluZxIlCg5tYXRjaGVzX3BsYXllZBgHIAEoBVINbWF0Y2hlc1BsYXllZBISCgR3'
    'aW5zGAggASgFUgR3aW5zEhIKBHBsYW4YCSABKAlSBHBsYW4SFAoFY29pbnMYCiABKANSBWNvaW'
    '5zEigKBnN0cmVhaxgLIAEoCzIQLnF1aXouU3RyZWFrSW5mb1IGc3RyZWFrEiMKDXJlZmVycmFs'
    'X2NvZGUYDCABKAlSDHJlZmVycmFsQ29kZRIZCghpc19ndWVzdBgNIAEoCFIHaXNHdWVzdBIpCh'
    'BhY2N1cmFjeV9wZXJjZW50GA4gASgCUg9hY2N1cmFjeVBlcmNlbnQSHQoKd2luX3N0cmVhaxgP'
    'IAEoBVIJd2luU3RyZWFrEikKEHByZWZlcnJlZF90b3BpY3MYECADKAlSD3ByZWZlcnJlZFRvcG'
    'ljcxIxChRvbmJvYXJkaW5nX2NvbXBsZXRlZBgRIAEoCFITb25ib2FyZGluZ0NvbXBsZXRlZA==');

@$core.Deprecated('Use claimDailyRewardRequestDescriptor instead')
const ClaimDailyRewardRequest$json = {
  '1': 'ClaimDailyRewardRequest',
};

/// Descriptor for `ClaimDailyRewardRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List claimDailyRewardRequestDescriptor =
    $convert.base64Decode('ChdDbGFpbURhaWx5UmV3YXJkUmVxdWVzdA==');

@$core.Deprecated('Use claimDailyRewardResponseDescriptor instead')
const ClaimDailyRewardResponse$json = {
  '1': 'ClaimDailyRewardResponse',
  '2': [
    {
      '1': 'reward',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.quiz.RewardGrant',
      '10': 'reward'
    },
    {
      '1': 'streak',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.quiz.StreakInfo',
      '10': 'streak'
    },
  ],
};

/// Descriptor for `ClaimDailyRewardResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List claimDailyRewardResponseDescriptor = $convert.base64Decode(
    'ChhDbGFpbURhaWx5UmV3YXJkUmVzcG9uc2USKQoGcmV3YXJkGAEgASgLMhEucXVpei5SZXdhcm'
    'RHcmFudFIGcmV3YXJkEigKBnN0cmVhaxgCIAEoCzIQLnF1aXouU3RyZWFrSW5mb1IGc3RyZWFr');

@$core.Deprecated('Use getStreakInfoRequestDescriptor instead')
const GetStreakInfoRequest$json = {
  '1': 'GetStreakInfoRequest',
};

/// Descriptor for `GetStreakInfoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStreakInfoRequestDescriptor =
    $convert.base64Decode('ChRHZXRTdHJlYWtJbmZvUmVxdWVzdA==');

@$core.Deprecated('Use getStreakInfoResponseDescriptor instead')
const GetStreakInfoResponse$json = {
  '1': 'GetStreakInfoResponse',
  '2': [
    {
      '1': 'streak',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.quiz.StreakInfo',
      '10': 'streak'
    },
  ],
};

/// Descriptor for `GetStreakInfoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStreakInfoResponseDescriptor = $convert.base64Decode(
    'ChVHZXRTdHJlYWtJbmZvUmVzcG9uc2USKAoGc3RyZWFrGAEgASgLMhAucXVpei5TdHJlYWtJbm'
    'ZvUgZzdHJlYWs=');

@$core.Deprecated('Use getHomeScreenDataRequestDescriptor instead')
const GetHomeScreenDataRequest$json = {
  '1': 'GetHomeScreenDataRequest',
};

/// Descriptor for `GetHomeScreenDataRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getHomeScreenDataRequestDescriptor =
    $convert.base64Decode('ChhHZXRIb21lU2NyZWVuRGF0YVJlcXVlc3Q=');

@$core.Deprecated('Use getHomeScreenDataResponseDescriptor instead')
const GetHomeScreenDataResponse$json = {
  '1': 'GetHomeScreenDataResponse',
  '2': [
    {
      '1': 'profile',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.quiz.UserProfile',
      '10': 'profile'
    },
    {'1': 'quota_remaining', '3': 2, '4': 1, '5': 5, '10': 'quotaRemaining'},
    {'1': 'quota_limit', '3': 3, '4': 1, '5': 5, '10': 'quotaLimit'},
    {
      '1': 'leaderboard_preview',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.quiz.LeaderboardEntry',
      '10': 'leaderboardPreview'
    },
  ],
};

/// Descriptor for `GetHomeScreenDataResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getHomeScreenDataResponseDescriptor = $convert.base64Decode(
    'ChlHZXRIb21lU2NyZWVuRGF0YVJlc3BvbnNlEisKB3Byb2ZpbGUYASABKAsyES5xdWl6LlVzZX'
    'JQcm9maWxlUgdwcm9maWxlEicKD3F1b3RhX3JlbWFpbmluZxgCIAEoBVIOcXVvdGFSZW1haW5p'
    'bmcSHwoLcXVvdGFfbGltaXQYAyABKAVSCnF1b3RhTGltaXQSRwoTbGVhZGVyYm9hcmRfcHJldm'
    'lldxgEIAMoCzIWLnF1aXouTGVhZGVyYm9hcmRFbnRyeVISbGVhZGVyYm9hcmRQcmV2aWV3');

@$core.Deprecated('Use getReferralDashboardRequestDescriptor instead')
const GetReferralDashboardRequest$json = {
  '1': 'GetReferralDashboardRequest',
};

/// Descriptor for `GetReferralDashboardRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getReferralDashboardRequestDescriptor =
    $convert.base64Decode('ChtHZXRSZWZlcnJhbERhc2hib2FyZFJlcXVlc3Q=');

@$core.Deprecated('Use getReferralDashboardResponseDescriptor instead')
const GetReferralDashboardResponse$json = {
  '1': 'GetReferralDashboardResponse',
  '2': [
    {'1': 'referral_code', '3': 1, '4': 1, '5': 9, '10': 'referralCode'},
    {'1': 'total_invites', '3': 2, '4': 1, '5': 5, '10': 'totalInvites'},
    {'1': 'conversions', '3': 3, '4': 1, '5': 5, '10': 'conversions'},
    {'1': 'coins_earned', '3': 4, '4': 1, '5': 3, '10': 'coinsEarned'},
  ],
};

/// Descriptor for `GetReferralDashboardResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getReferralDashboardResponseDescriptor = $convert.base64Decode(
    'ChxHZXRSZWZlcnJhbERhc2hib2FyZFJlc3BvbnNlEiMKDXJlZmVycmFsX2NvZGUYASABKAlSDH'
    'JlZmVycmFsQ29kZRIjCg10b3RhbF9pbnZpdGVzGAIgASgFUgx0b3RhbEludml0ZXMSIAoLY29u'
    'dmVyc2lvbnMYAyABKAVSC2NvbnZlcnNpb25zEiEKDGNvaW5zX2Vhcm5lZBgEIAEoA1ILY29pbn'
    'NFYXJuZWQ=');

@$core.Deprecated('Use applyReferralCodeRequestDescriptor instead')
const ApplyReferralCodeRequest$json = {
  '1': 'ApplyReferralCodeRequest',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
  ],
};

/// Descriptor for `ApplyReferralCodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List applyReferralCodeRequestDescriptor =
    $convert.base64Decode(
        'ChhBcHBseVJlZmVycmFsQ29kZVJlcXVlc3QSEgoEY29kZRgBIAEoCVIEY29kZQ==');

@$core.Deprecated('Use applyReferralCodeResponseDescriptor instead')
const ApplyReferralCodeResponse$json = {
  '1': 'ApplyReferralCodeResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `ApplyReferralCodeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List applyReferralCodeResponseDescriptor =
    $convert.base64Decode(
        'ChlBcHBseVJlZmVycmFsQ29kZVJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3M=');

@$core.Deprecated('Use updateFCMTokenRequestDescriptor instead')
const UpdateFCMTokenRequest$json = {
  '1': 'UpdateFCMTokenRequest',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `UpdateFCMTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateFCMTokenRequestDescriptor =
    $convert.base64Decode(
        'ChVVcGRhdGVGQ01Ub2tlblJlcXVlc3QSFAoFdG9rZW4YASABKAlSBXRva2Vu');

@$core.Deprecated('Use updateFCMTokenResponseDescriptor instead')
const UpdateFCMTokenResponse$json = {
  '1': 'UpdateFCMTokenResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `UpdateFCMTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateFCMTokenResponseDescriptor =
    $convert.base64Decode(
        'ChZVcGRhdGVGQ01Ub2tlblJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3M=');

@$core.Deprecated('Use createOrderRequestDescriptor instead')
const CreateOrderRequest$json = {
  '1': 'CreateOrderRequest',
  '2': [
    {'1': 'plan_duration', '3': 1, '4': 1, '5': 9, '10': 'planDuration'},
  ],
};

/// Descriptor for `CreateOrderRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createOrderRequestDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVPcmRlclJlcXVlc3QSIwoNcGxhbl9kdXJhdGlvbhgBIAEoCVIMcGxhbkR1cmF0aW'
    '9u');

@$core.Deprecated('Use createOrderResponseDescriptor instead')
const CreateOrderResponse$json = {
  '1': 'CreateOrderResponse',
  '2': [
    {'1': 'order_id', '3': 1, '4': 1, '5': 9, '10': 'orderId'},
    {'1': 'key_id', '3': 2, '4': 1, '5': 9, '10': 'keyId'},
    {'1': 'amount', '3': 3, '4': 1, '5': 3, '10': 'amount'},
    {'1': 'currency', '3': 4, '4': 1, '5': 9, '10': 'currency'},
  ],
};

/// Descriptor for `CreateOrderResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createOrderResponseDescriptor = $convert.base64Decode(
    'ChNDcmVhdGVPcmRlclJlc3BvbnNlEhkKCG9yZGVyX2lkGAEgASgJUgdvcmRlcklkEhUKBmtleV'
    '9pZBgCIAEoCVIFa2V5SWQSFgoGYW1vdW50GAMgASgDUgZhbW91bnQSGgoIY3VycmVuY3kYBCAB'
    'KAlSCGN1cnJlbmN5');

@$core.Deprecated('Use verifyPaymentRequestDescriptor instead')
const VerifyPaymentRequest$json = {
  '1': 'VerifyPaymentRequest',
  '2': [
    {'1': 'razorpay_order_id', '3': 1, '4': 1, '5': 9, '10': 'razorpayOrderId'},
    {
      '1': 'razorpay_payment_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'razorpayPaymentId'
    },
    {
      '1': 'razorpay_signature',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'razorpaySignature'
    },
  ],
};

/// Descriptor for `VerifyPaymentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List verifyPaymentRequestDescriptor = $convert.base64Decode(
    'ChRWZXJpZnlQYXltZW50UmVxdWVzdBIqChFyYXpvcnBheV9vcmRlcl9pZBgBIAEoCVIPcmF6b3'
    'JwYXlPcmRlcklkEi4KE3Jhem9ycGF5X3BheW1lbnRfaWQYAiABKAlSEXJhem9ycGF5UGF5bWVu'
    'dElkEi0KEnJhem9ycGF5X3NpZ25hdHVyZRgDIAEoCVIRcmF6b3JwYXlTaWduYXR1cmU=');

@$core.Deprecated('Use verifyPaymentResponseDescriptor instead')
const VerifyPaymentResponse$json = {
  '1': 'VerifyPaymentResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'plan', '3': 2, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'expires_at', '3': 3, '4': 1, '5': 3, '10': 'expiresAt'},
  ],
};

/// Descriptor for `VerifyPaymentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List verifyPaymentResponseDescriptor = $convert.base64Decode(
    'ChVWZXJpZnlQYXltZW50UmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxISCgRwbG'
    'FuGAIgASgJUgRwbGFuEh0KCmV4cGlyZXNfYXQYAyABKANSCWV4cGlyZXNBdA==');

@$core.Deprecated('Use getPlanStatusRequestDescriptor instead')
const GetPlanStatusRequest$json = {
  '1': 'GetPlanStatusRequest',
};

/// Descriptor for `GetPlanStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPlanStatusRequestDescriptor =
    $convert.base64Decode('ChRHZXRQbGFuU3RhdHVzUmVxdWVzdA==');

@$core.Deprecated('Use getPlanStatusResponseDescriptor instead')
const GetPlanStatusResponse$json = {
  '1': 'GetPlanStatusResponse',
  '2': [
    {'1': 'plan', '3': 1, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'expires_at', '3': 2, '4': 1, '5': 3, '10': 'expiresAt'},
  ],
};

/// Descriptor for `GetPlanStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPlanStatusResponseDescriptor = $convert.base64Decode(
    'ChVHZXRQbGFuU3RhdHVzUmVzcG9uc2USEgoEcGxhbhgBIAEoCVIEcGxhbhIdCgpleHBpcmVzX2'
    'F0GAIgASgDUglleHBpcmVzQXQ=');

@$core.Deprecated('Use getPaymentHistoryRequestDescriptor instead')
const GetPaymentHistoryRequest$json = {
  '1': 'GetPaymentHistoryRequest',
  '2': [
    {'1': 'limit', '3': 1, '4': 1, '5': 5, '10': 'limit'},
    {'1': 'offset', '3': 2, '4': 1, '5': 5, '10': 'offset'},
  ],
};

/// Descriptor for `GetPaymentHistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPaymentHistoryRequestDescriptor =
    $convert.base64Decode(
        'ChhHZXRQYXltZW50SGlzdG9yeVJlcXVlc3QSFAoFbGltaXQYASABKAVSBWxpbWl0EhYKBm9mZn'
        'NldBgCIAEoBVIGb2Zmc2V0');

@$core.Deprecated('Use getPaymentHistoryResponseDescriptor instead')
const GetPaymentHistoryResponse$json = {
  '1': 'GetPaymentHistoryResponse',
  '2': [
    {
      '1': 'payments',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.quiz.PaymentRecord',
      '10': 'payments'
    },
  ],
};

/// Descriptor for `GetPaymentHistoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPaymentHistoryResponseDescriptor =
    $convert.base64Decode(
        'ChlHZXRQYXltZW50SGlzdG9yeVJlc3BvbnNlEi8KCHBheW1lbnRzGAEgAygLMhMucXVpei5QYX'
        'ltZW50UmVjb3JkUghwYXltZW50cw==');

@$core.Deprecated('Use paymentRecordDescriptor instead')
const PaymentRecord$json = {
  '1': 'PaymentRecord',
  '2': [
    {'1': 'order_id', '3': 1, '4': 1, '5': 9, '10': 'orderId'},
    {'1': 'amount', '3': 2, '4': 1, '5': 3, '10': 'amount'},
    {'1': 'currency', '3': 3, '4': 1, '5': 9, '10': 'currency'},
    {'1': 'status', '3': 4, '4': 1, '5': 9, '10': 'status'},
    {'1': 'plan_duration', '3': 5, '4': 1, '5': 9, '10': 'planDuration'},
    {'1': 'created_at', '3': 6, '4': 1, '5': 3, '10': 'createdAt'},
  ],
};

/// Descriptor for `PaymentRecord`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paymentRecordDescriptor = $convert.base64Decode(
    'Cg1QYXltZW50UmVjb3JkEhkKCG9yZGVyX2lkGAEgASgJUgdvcmRlcklkEhYKBmFtb3VudBgCIA'
    'EoA1IGYW1vdW50EhoKCGN1cnJlbmN5GAMgASgJUghjdXJyZW5jeRIWCgZzdGF0dXMYBCABKAlS'
    'BnN0YXR1cxIjCg1wbGFuX2R1cmF0aW9uGAUgASgJUgxwbGFuRHVyYXRpb24SHQoKY3JlYXRlZF'
    '9hdBgGIAEoA1IJY3JlYXRlZEF0');

@$core.Deprecated('Use getTournamentListRequestDescriptor instead')
const GetTournamentListRequest$json = {
  '1': 'GetTournamentListRequest',
};

/// Descriptor for `GetTournamentListRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTournamentListRequestDescriptor =
    $convert.base64Decode('ChhHZXRUb3VybmFtZW50TGlzdFJlcXVlc3Q=');

@$core.Deprecated('Use getTournamentListResponseDescriptor instead')
const GetTournamentListResponse$json = {
  '1': 'GetTournamentListResponse',
  '2': [
    {
      '1': 'tournaments',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.quiz.TournamentInfo',
      '10': 'tournaments'
    },
  ],
};

/// Descriptor for `GetTournamentListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTournamentListResponseDescriptor =
    $convert.base64Decode(
        'ChlHZXRUb3VybmFtZW50TGlzdFJlc3BvbnNlEjYKC3RvdXJuYW1lbnRzGAEgAygLMhQucXVpei'
        '5Ub3VybmFtZW50SW5mb1ILdG91cm5hbWVudHM=');

@$core.Deprecated('Use tournamentInfoDescriptor instead')
const TournamentInfo$json = {
  '1': 'TournamentInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'start_time', '3': 3, '4': 1, '5': 3, '10': 'startTime'},
    {'1': 'end_time', '3': 4, '4': 1, '5': 3, '10': 'endTime'},
    {'1': 'status', '3': 5, '4': 1, '5': 9, '10': 'status'},
    {
      '1': 'participant_count',
      '3': 6,
      '4': 1,
      '5': 5,
      '10': 'participantCount'
    },
    {'1': 'required_plan', '3': 7, '4': 1, '5': 9, '10': 'requiredPlan'},
    {
      '1': 'prize_description',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'prizeDescription'
    },
  ],
};

/// Descriptor for `TournamentInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tournamentInfoDescriptor = $convert.base64Decode(
    'Cg5Ub3VybmFtZW50SW5mbxIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIdCg'
    'pzdGFydF90aW1lGAMgASgDUglzdGFydFRpbWUSGQoIZW5kX3RpbWUYBCABKANSB2VuZFRpbWUS'
    'FgoGc3RhdHVzGAUgASgJUgZzdGF0dXMSKwoRcGFydGljaXBhbnRfY291bnQYBiABKAVSEHBhcn'
    'RpY2lwYW50Q291bnQSIwoNcmVxdWlyZWRfcGxhbhgHIAEoCVIMcmVxdWlyZWRQbGFuEisKEXBy'
    'aXplX2Rlc2NyaXB0aW9uGAggASgJUhBwcml6ZURlc2NyaXB0aW9u');

@$core.Deprecated('Use joinTournamentRequestDescriptor instead')
const JoinTournamentRequest$json = {
  '1': 'JoinTournamentRequest',
  '2': [
    {'1': 'tournament_id', '3': 1, '4': 1, '5': 9, '10': 'tournamentId'},
  ],
};

/// Descriptor for `JoinTournamentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinTournamentRequestDescriptor = $convert.base64Decode(
    'ChVKb2luVG91cm5hbWVudFJlcXVlc3QSIwoNdG91cm5hbWVudF9pZBgBIAEoCVIMdG91cm5hbW'
    'VudElk');

@$core.Deprecated('Use joinTournamentResponseDescriptor instead')
const JoinTournamentResponse$json = {
  '1': 'JoinTournamentResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `JoinTournamentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinTournamentResponseDescriptor =
    $convert.base64Decode(
        'ChZKb2luVG91cm5hbWVudFJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3M=');

@$core.Deprecated('Use tournamentDescriptor instead')
const Tournament$json = {
  '1': 'Tournament',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'start_time', '3': 3, '4': 1, '5': 3, '10': 'startTime'},
    {'1': 'end_time', '3': 4, '4': 1, '5': 3, '10': 'endTime'},
    {'1': 'entry_deadline', '3': 5, '4': 1, '5': 3, '10': 'entryDeadline'},
    {'1': 'status', '3': 6, '4': 1, '5': 9, '10': 'status'},
    {'1': 'required_plan', '3': 7, '4': 1, '5': 9, '10': 'requiredPlan'},
    {
      '1': 'prize_description',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'prizeDescription'
    },
    {'1': 'prize_pool', '3': 9, '4': 3, '5': 3, '10': 'prizePool'},
    {
      '1': 'participant_count',
      '3': 10,
      '4': 1,
      '5': 5,
      '10': 'participantCount'
    },
  ],
};

/// Descriptor for `Tournament`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tournamentDescriptor = $convert.base64Decode(
    'CgpUb3VybmFtZW50Eg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEh0KCnN0YX'
    'J0X3RpbWUYAyABKANSCXN0YXJ0VGltZRIZCghlbmRfdGltZRgEIAEoA1IHZW5kVGltZRIlCg5l'
    'bnRyeV9kZWFkbGluZRgFIAEoA1INZW50cnlEZWFkbGluZRIWCgZzdGF0dXMYBiABKAlSBnN0YX'
    'R1cxIjCg1yZXF1aXJlZF9wbGFuGAcgASgJUgxyZXF1aXJlZFBsYW4SKwoRcHJpemVfZGVzY3Jp'
    'cHRpb24YCCABKAlSEHByaXplRGVzY3JpcHRpb24SHQoKcHJpemVfcG9vbBgJIAMoA1IJcHJpem'
    'VQb29sEisKEXBhcnRpY2lwYW50X2NvdW50GAogASgFUhBwYXJ0aWNpcGFudENvdW50');

@$core.Deprecated('Use getTournamentRequestDescriptor instead')
const GetTournamentRequest$json = {
  '1': 'GetTournamentRequest',
  '2': [
    {'1': 'tournament_id', '3': 1, '4': 1, '5': 9, '10': 'tournamentId'},
  ],
};

/// Descriptor for `GetTournamentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTournamentRequestDescriptor = $convert.base64Decode(
    'ChRHZXRUb3VybmFtZW50UmVxdWVzdBIjCg10b3VybmFtZW50X2lkGAEgASgJUgx0b3VybmFtZW'
    '50SWQ=');

@$core.Deprecated('Use getTournamentResponseDescriptor instead')
const GetTournamentResponse$json = {
  '1': 'GetTournamentResponse',
  '2': [
    {
      '1': 'tournament',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.quiz.Tournament',
      '10': 'tournament'
    },
  ],
};

/// Descriptor for `GetTournamentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTournamentResponseDescriptor = $convert.base64Decode(
    'ChVHZXRUb3VybmFtZW50UmVzcG9uc2USMAoKdG91cm5hbWVudBgBIAEoCzIQLnF1aXouVG91cm'
    '5hbWVudFIKdG91cm5hbWVudA==');

@$core.Deprecated('Use tournamentStandingEntryDescriptor instead')
const TournamentStandingEntry$json = {
  '1': 'TournamentStandingEntry',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {'1': 'score', '3': 3, '4': 1, '5': 3, '10': 'score'},
    {'1': 'rank', '3': 4, '4': 1, '5': 5, '10': 'rank'},
    {'1': 'plan', '3': 5, '4': 1, '5': 9, '10': 'plan'},
  ],
};

/// Descriptor for `TournamentStandingEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tournamentStandingEntryDescriptor = $convert.base64Decode(
    'ChdUb3VybmFtZW50U3RhbmRpbmdFbnRyeRIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSGgoIdX'
    'Nlcm5hbWUYAiABKAlSCHVzZXJuYW1lEhQKBXNjb3JlGAMgASgDUgVzY29yZRISCgRyYW5rGAQg'
    'ASgFUgRyYW5rEhIKBHBsYW4YBSABKAlSBHBsYW4=');

@$core.Deprecated('Use getTournamentLeaderboardRequestDescriptor instead')
const GetTournamentLeaderboardRequest$json = {
  '1': 'GetTournamentLeaderboardRequest',
  '2': [
    {'1': 'tournament_id', '3': 1, '4': 1, '5': 9, '10': 'tournamentId'},
  ],
};

/// Descriptor for `GetTournamentLeaderboardRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTournamentLeaderboardRequestDescriptor =
    $convert.base64Decode(
        'Ch9HZXRUb3VybmFtZW50TGVhZGVyYm9hcmRSZXF1ZXN0EiMKDXRvdXJuYW1lbnRfaWQYASABKA'
        'lSDHRvdXJuYW1lbnRJZA==');

@$core.Deprecated('Use getTournamentLeaderboardResponseDescriptor instead')
const GetTournamentLeaderboardResponse$json = {
  '1': 'GetTournamentLeaderboardResponse',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.quiz.TournamentStandingEntry',
      '10': 'entries'
    },
  ],
};

/// Descriptor for `GetTournamentLeaderboardResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTournamentLeaderboardResponseDescriptor =
    $convert.base64Decode(
        'CiBHZXRUb3VybmFtZW50TGVhZGVyYm9hcmRSZXNwb25zZRI3CgdlbnRyaWVzGAEgAygLMh0ucX'
        'Vpei5Ub3VybmFtZW50U3RhbmRpbmdFbnRyeVIHZW50cmllcw==');

@$core.Deprecated('Use getGlobalLeaderboardRequestDescriptor instead')
const GetGlobalLeaderboardRequest$json = {
  '1': 'GetGlobalLeaderboardRequest',
  '2': [
    {'1': 'time_filter', '3': 1, '4': 1, '5': 9, '10': 'timeFilter'},
  ],
};

/// Descriptor for `GetGlobalLeaderboardRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGlobalLeaderboardRequestDescriptor =
    $convert.base64Decode(
        'ChtHZXRHbG9iYWxMZWFkZXJib2FyZFJlcXVlc3QSHwoLdGltZV9maWx0ZXIYASABKAlSCnRpbW'
        'VGaWx0ZXI=');

@$core.Deprecated('Use getGlobalLeaderboardResponseDescriptor instead')
const GetGlobalLeaderboardResponse$json = {
  '1': 'GetGlobalLeaderboardResponse',
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

/// Descriptor for `GetGlobalLeaderboardResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGlobalLeaderboardResponseDescriptor =
    $convert.base64Decode(
        'ChxHZXRHbG9iYWxMZWFkZXJib2FyZFJlc3BvbnNlEjAKB2VudHJpZXMYASADKAsyFi5xdWl6Lk'
        'xlYWRlcmJvYXJkRW50cnlSB2VudHJpZXM=');

@$core.Deprecated('Use getCoinBalanceRequestDescriptor instead')
const GetCoinBalanceRequest$json = {
  '1': 'GetCoinBalanceRequest',
};

/// Descriptor for `GetCoinBalanceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCoinBalanceRequestDescriptor =
    $convert.base64Decode('ChVHZXRDb2luQmFsYW5jZVJlcXVlc3Q=');

@$core.Deprecated('Use getCoinBalanceResponseDescriptor instead')
const GetCoinBalanceResponse$json = {
  '1': 'GetCoinBalanceResponse',
  '2': [
    {'1': 'balance', '3': 1, '4': 1, '5': 3, '10': 'balance'},
  ],
};

/// Descriptor for `GetCoinBalanceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCoinBalanceResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRDb2luQmFsYW5jZVJlc3BvbnNlEhgKB2JhbGFuY2UYASABKANSB2JhbGFuY2U=');

@$core.Deprecated('Use coinLedgerEntryDescriptor instead')
const CoinLedgerEntry$json = {
  '1': 'CoinLedgerEntry',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'delta', '3': 2, '4': 1, '5': 3, '10': 'delta'},
    {'1': 'reason', '3': 3, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'ref_id', '3': 4, '4': 1, '5': 9, '10': 'refId'},
    {'1': 'balance_after', '3': 5, '4': 1, '5': 3, '10': 'balanceAfter'},
    {
      '1': 'created_at_unix_ms',
      '3': 6,
      '4': 1,
      '5': 3,
      '10': 'createdAtUnixMs'
    },
    {
      '1': 'metadata',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.quiz.CoinLedgerEntry.MetadataEntry',
      '10': 'metadata'
    },
  ],
  '3': [CoinLedgerEntry_MetadataEntry$json],
};

@$core.Deprecated('Use coinLedgerEntryDescriptor instead')
const CoinLedgerEntry_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `CoinLedgerEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List coinLedgerEntryDescriptor = $convert.base64Decode(
    'Cg9Db2luTGVkZ2VyRW50cnkSDgoCaWQYASABKAlSAmlkEhQKBWRlbHRhGAIgASgDUgVkZWx0YR'
    'IWCgZyZWFzb24YAyABKAlSBnJlYXNvbhIVCgZyZWZfaWQYBCABKAlSBXJlZklkEiMKDWJhbGFu'
    'Y2VfYWZ0ZXIYBSABKANSDGJhbGFuY2VBZnRlchIrChJjcmVhdGVkX2F0X3VuaXhfbXMYBiABKA'
    'NSD2NyZWF0ZWRBdFVuaXhNcxI/CghtZXRhZGF0YRgHIAMoCzIjLnF1aXouQ29pbkxlZGdlckVu'
    'dHJ5Lk1ldGFkYXRhRW50cnlSCG1ldGFkYXRhGjsKDU1ldGFkYXRhRW50cnkSEAoDa2V5GAEgAS'
    'gJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use getCoinLedgerRequestDescriptor instead')
const GetCoinLedgerRequest$json = {
  '1': 'GetCoinLedgerRequest',
  '2': [
    {'1': 'page_size', '3': 1, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'page_token', '3': 2, '4': 1, '5': 9, '10': 'pageToken'},
  ],
};

/// Descriptor for `GetCoinLedgerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCoinLedgerRequestDescriptor = $convert.base64Decode(
    'ChRHZXRDb2luTGVkZ2VyUmVxdWVzdBIbCglwYWdlX3NpemUYASABKAVSCHBhZ2VTaXplEh0KCn'
    'BhZ2VfdG9rZW4YAiABKAlSCXBhZ2VUb2tlbg==');

@$core.Deprecated('Use getCoinLedgerResponseDescriptor instead')
const GetCoinLedgerResponse$json = {
  '1': 'GetCoinLedgerResponse',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.quiz.CoinLedgerEntry',
      '10': 'entries'
    },
    {'1': 'next_page_token', '3': 2, '4': 1, '5': 9, '10': 'nextPageToken'},
  ],
};

/// Descriptor for `GetCoinLedgerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCoinLedgerResponseDescriptor = $convert.base64Decode(
    'ChVHZXRDb2luTGVkZ2VyUmVzcG9uc2USLwoHZW50cmllcxgBIAMoCzIVLnF1aXouQ29pbkxlZG'
    'dlckVudHJ5UgdlbnRyaWVzEiYKD25leHRfcGFnZV90b2tlbhgCIAEoCVINbmV4dFBhZ2VUb2tl'
    'bg==');

@$core.Deprecated('Use shopItemDescriptor instead')
const ShopItem$json = {
  '1': 'ShopItem',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'kind', '3': 2, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 4, '4': 1, '5': 9, '10': 'description'},
    {'1': 'price_coins', '3': 5, '4': 1, '5': 3, '10': 'priceCoins'},
    {'1': 'active', '3': 6, '4': 1, '5': 8, '10': 'active'},
    {
      '1': 'metadata',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.quiz.ShopItem.MetadataEntry',
      '10': 'metadata'
    },
  ],
  '3': [ShopItem_MetadataEntry$json],
};

@$core.Deprecated('Use shopItemDescriptor instead')
const ShopItem_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `ShopItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shopItemDescriptor = $convert.base64Decode(
    'CghTaG9wSXRlbRIOCgJpZBgBIAEoCVICaWQSEgoEa2luZBgCIAEoCVIEa2luZBISCgRuYW1lGA'
    'MgASgJUgRuYW1lEiAKC2Rlc2NyaXB0aW9uGAQgASgJUgtkZXNjcmlwdGlvbhIfCgtwcmljZV9j'
    'b2lucxgFIAEoA1IKcHJpY2VDb2lucxIWCgZhY3RpdmUYBiABKAhSBmFjdGl2ZRI4CghtZXRhZG'
    'F0YRgHIAMoCzIcLnF1aXouU2hvcEl0ZW0uTWV0YWRhdGFFbnRyeVIIbWV0YWRhdGEaOwoNTWV0'
    'YWRhdGFFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use getShopCatalogRequestDescriptor instead')
const GetShopCatalogRequest$json = {
  '1': 'GetShopCatalogRequest',
};

/// Descriptor for `GetShopCatalogRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getShopCatalogRequestDescriptor =
    $convert.base64Decode('ChVHZXRTaG9wQ2F0YWxvZ1JlcXVlc3Q=');

@$core.Deprecated('Use getShopCatalogResponseDescriptor instead')
const GetShopCatalogResponse$json = {
  '1': 'GetShopCatalogResponse',
  '2': [
    {
      '1': 'items',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.quiz.ShopItem',
      '10': 'items'
    },
  ],
};

/// Descriptor for `GetShopCatalogResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getShopCatalogResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRTaG9wQ2F0YWxvZ1Jlc3BvbnNlEiQKBWl0ZW1zGAEgAygLMg4ucXVpei5TaG9wSXRlbV'
        'IFaXRlbXM=');

@$core.Deprecated('Use getShopInventoryRequestDescriptor instead')
const GetShopInventoryRequest$json = {
  '1': 'GetShopInventoryRequest',
};

/// Descriptor for `GetShopInventoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getShopInventoryRequestDescriptor =
    $convert.base64Decode('ChdHZXRTaG9wSW52ZW50b3J5UmVxdWVzdA==');

@$core.Deprecated('Use getShopInventoryResponseDescriptor instead')
const GetShopInventoryResponse$json = {
  '1': 'GetShopInventoryResponse',
  '2': [
    {'1': 'owned_cosmetics', '3': 1, '4': 3, '5': 9, '10': 'ownedCosmetics'},
    {
      '1': 'equipped_cosmetic_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'equippedCosmeticId'
    },
    {
      '1': 'equipped_name_color',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'equippedNameColor'
    },
    {'1': 'reroll_charges', '3': 4, '4': 1, '5': 5, '10': 'rerollCharges'},
    {
      '1': 'streak_freeze_held',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'streakFreezeHeld'
    },
    {
      '1': 'streak_freeze_week_iso',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'streakFreezeWeekIso'
    },
    {'1': 'balance', '3': 7, '4': 1, '5': 3, '10': 'balance'},
  ],
};

/// Descriptor for `GetShopInventoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getShopInventoryResponseDescriptor = $convert.base64Decode(
    'ChhHZXRTaG9wSW52ZW50b3J5UmVzcG9uc2USJwoPb3duZWRfY29zbWV0aWNzGAEgAygJUg5vd2'
    '5lZENvc21ldGljcxIwChRlcXVpcHBlZF9jb3NtZXRpY19pZBgCIAEoCVISZXF1aXBwZWRDb3Nt'
    'ZXRpY0lkEi4KE2VxdWlwcGVkX25hbWVfY29sb3IYAyABKAlSEWVxdWlwcGVkTmFtZUNvbG9yEi'
    'UKDnJlcm9sbF9jaGFyZ2VzGAQgASgFUg1yZXJvbGxDaGFyZ2VzEiwKEnN0cmVha19mcmVlemVf'
    'aGVsZBgFIAEoCFIQc3RyZWFrRnJlZXplSGVsZBIzChZzdHJlYWtfZnJlZXplX3dlZWtfaXNvGA'
    'YgASgJUhNzdHJlYWtGcmVlemVXZWVrSXNvEhgKB2JhbGFuY2UYByABKANSB2JhbGFuY2U=');

@$core.Deprecated('Use purchaseShopItemRequestDescriptor instead')
const PurchaseShopItemRequest$json = {
  '1': 'PurchaseShopItemRequest',
  '2': [
    {'1': 'item_id', '3': 1, '4': 1, '5': 9, '10': 'itemId'},
    {'1': 'idempotency_key', '3': 2, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `PurchaseShopItemRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List purchaseShopItemRequestDescriptor =
    $convert.base64Decode(
        'ChdQdXJjaGFzZVNob3BJdGVtUmVxdWVzdBIXCgdpdGVtX2lkGAEgASgJUgZpdGVtSWQSJwoPaW'
        'RlbXBvdGVuY3lfa2V5GAIgASgJUg5pZGVtcG90ZW5jeUtleQ==');

@$core.Deprecated('Use purchaseShopItemResponseDescriptor instead')
const PurchaseShopItemResponse$json = {
  '1': 'PurchaseShopItemResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'ledger_entry_id', '3': 2, '4': 1, '5': 9, '10': 'ledgerEntryId'},
    {'1': 'new_balance', '3': 3, '4': 1, '5': 3, '10': 'newBalance'},
    {'1': 'error_code', '3': 4, '4': 1, '5': 9, '10': 'errorCode'},
  ],
};

/// Descriptor for `PurchaseShopItemResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List purchaseShopItemResponseDescriptor = $convert.base64Decode(
    'ChhQdXJjaGFzZVNob3BJdGVtUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxImCg'
    '9sZWRnZXJfZW50cnlfaWQYAiABKAlSDWxlZGdlckVudHJ5SWQSHwoLbmV3X2JhbGFuY2UYAyAB'
    'KANSCm5ld0JhbGFuY2USHQoKZXJyb3JfY29kZRgEIAEoCVIJZXJyb3JDb2Rl');

@$core.Deprecated('Use equipCosmeticRequestDescriptor instead')
const EquipCosmeticRequest$json = {
  '1': 'EquipCosmeticRequest',
  '2': [
    {'1': 'item_id', '3': 1, '4': 1, '5': 9, '10': 'itemId'},
  ],
};

/// Descriptor for `EquipCosmeticRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List equipCosmeticRequestDescriptor =
    $convert.base64Decode(
        'ChRFcXVpcENvc21ldGljUmVxdWVzdBIXCgdpdGVtX2lkGAEgASgJUgZpdGVtSWQ=');

@$core.Deprecated('Use equipCosmeticResponseDescriptor instead')
const EquipCosmeticResponse$json = {
  '1': 'EquipCosmeticResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'error_code', '3': 2, '4': 1, '5': 9, '10': 'errorCode'},
  ],
};

/// Descriptor for `EquipCosmeticResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List equipCosmeticResponseDescriptor = $convert.base64Decode(
    'ChVFcXVpcENvc21ldGljUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIdCgplcn'
    'Jvcl9jb2RlGAIgASgJUgllcnJvckNvZGU=');

@$core.Deprecated('Use consumeRerollRequestDescriptor instead')
const ConsumeRerollRequest$json = {
  '1': 'ConsumeRerollRequest',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'round_id', '3': 2, '4': 1, '5': 9, '10': 'roundId'},
  ],
};

/// Descriptor for `ConsumeRerollRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List consumeRerollRequestDescriptor = $convert.base64Decode(
    'ChRDb25zdW1lUmVyb2xsUmVxdWVzdBIXCgdyb29tX2lkGAEgASgJUgZyb29tSWQSGQoIcm91bm'
    'RfaWQYAiABKAlSB3JvdW5kSWQ=');

@$core.Deprecated('Use consumeRerollResponseDescriptor instead')
const ConsumeRerollResponse$json = {
  '1': 'ConsumeRerollResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {
      '1': 'charges_remaining',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'chargesRemaining'
    },
    {'1': 'error_code', '3': 3, '4': 1, '5': 9, '10': 'errorCode'},
  ],
};

/// Descriptor for `ConsumeRerollResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List consumeRerollResponseDescriptor = $convert.base64Decode(
    'ChVDb25zdW1lUmVyb2xsUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIrChFjaG'
    'FyZ2VzX3JlbWFpbmluZxgCIAEoBVIQY2hhcmdlc1JlbWFpbmluZxIdCgplcnJvcl9jb2RlGAMg'
    'ASgJUgllcnJvckNvZGU=');

@$core.Deprecated('Use sendFriendRequestRequestDescriptor instead')
const SendFriendRequestRequest$json = {
  '1': 'SendFriendRequestRequest',
  '2': [
    {'1': 'target_username', '3': 1, '4': 1, '5': 9, '10': 'targetUsername'},
    {
      '1': 'target_referral_code',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'targetReferralCode'
    },
  ],
};

/// Descriptor for `SendFriendRequestRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendFriendRequestRequestDescriptor = $convert.base64Decode(
    'ChhTZW5kRnJpZW5kUmVxdWVzdFJlcXVlc3QSJwoPdGFyZ2V0X3VzZXJuYW1lGAEgASgJUg50YX'
    'JnZXRVc2VybmFtZRIwChR0YXJnZXRfcmVmZXJyYWxfY29kZRgCIAEoCVISdGFyZ2V0UmVmZXJy'
    'YWxDb2Rl');

@$core.Deprecated('Use sendFriendRequestResponseDescriptor instead')
const SendFriendRequestResponse$json = {
  '1': 'SendFriendRequestResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'error_code', '3': 3, '4': 1, '5': 9, '10': 'errorCode'},
  ],
};

/// Descriptor for `SendFriendRequestResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendFriendRequestResponseDescriptor = $convert.base64Decode(
    'ChlTZW5kRnJpZW5kUmVxdWVzdFJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSHQ'
    'oKcmVxdWVzdF9pZBgCIAEoCVIJcmVxdWVzdElkEh0KCmVycm9yX2NvZGUYAyABKAlSCWVycm9y'
    'Q29kZQ==');

@$core.Deprecated('Use friendRequestDescriptor instead')
const FriendRequest$json = {
  '1': 'FriendRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'from_user_id', '3': 2, '4': 1, '5': 9, '10': 'fromUserId'},
    {'1': 'from_username', '3': 3, '4': 1, '5': 9, '10': 'fromUsername'},
    {'1': 'to_user_id', '3': 4, '4': 1, '5': 9, '10': 'toUserId'},
    {'1': 'to_username', '3': 5, '4': 1, '5': 9, '10': 'toUsername'},
    {'1': 'status', '3': 6, '4': 1, '5': 9, '10': 'status'},
    {'1': 'created_at_ms', '3': 7, '4': 1, '5': 3, '10': 'createdAtMs'},
    {'1': 'responded_at_ms', '3': 8, '4': 1, '5': 3, '10': 'respondedAtMs'},
  ],
};

/// Descriptor for `FriendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List friendRequestDescriptor = $convert.base64Decode(
    'Cg1GcmllbmRSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZBIgCgxmcm9tX3VzZXJfaWQYAiABKAlSCm'
    'Zyb21Vc2VySWQSIwoNZnJvbV91c2VybmFtZRgDIAEoCVIMZnJvbVVzZXJuYW1lEhwKCnRvX3Vz'
    'ZXJfaWQYBCABKAlSCHRvVXNlcklkEh8KC3RvX3VzZXJuYW1lGAUgASgJUgp0b1VzZXJuYW1lEh'
    'YKBnN0YXR1cxgGIAEoCVIGc3RhdHVzEiIKDWNyZWF0ZWRfYXRfbXMYByABKANSC2NyZWF0ZWRB'
    'dE1zEiYKD3Jlc3BvbmRlZF9hdF9tcxgIIAEoA1INcmVzcG9uZGVkQXRNcw==');

@$core.Deprecated('Use respondToFriendRequestRequestDescriptor instead')
const RespondToFriendRequestRequest$json = {
  '1': 'RespondToFriendRequestRequest',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'accept', '3': 2, '4': 1, '5': 8, '10': 'accept'},
  ],
};

/// Descriptor for `RespondToFriendRequestRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List respondToFriendRequestRequestDescriptor =
    $convert.base64Decode(
        'Ch1SZXNwb25kVG9GcmllbmRSZXF1ZXN0UmVxdWVzdBIdCgpyZXF1ZXN0X2lkGAEgASgJUglyZX'
        'F1ZXN0SWQSFgoGYWNjZXB0GAIgASgIUgZhY2NlcHQ=');

@$core.Deprecated('Use respondToFriendRequestResponseDescriptor instead')
const RespondToFriendRequestResponse$json = {
  '1': 'RespondToFriendRequestResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'error_code', '3': 2, '4': 1, '5': 9, '10': 'errorCode'},
  ],
};

/// Descriptor for `RespondToFriendRequestResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List respondToFriendRequestResponseDescriptor =
    $convert.base64Decode(
        'Ch5SZXNwb25kVG9GcmllbmRSZXF1ZXN0UmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2'
        'VzcxIdCgplcnJvcl9jb2RlGAIgASgJUgllcnJvckNvZGU=');

@$core.Deprecated('Use friendDescriptor instead')
const Friend$json = {
  '1': 'Friend',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {'1': 'online', '3': 3, '4': 1, '5': 8, '10': 'online'},
    {'1': 'friended_at_ms', '3': 4, '4': 1, '5': 3, '10': 'friendedAtMs'},
  ],
};

/// Descriptor for `Friend`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List friendDescriptor = $convert.base64Decode(
    'CgZGcmllbmQSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhoKCHVzZXJuYW1lGAIgASgJUgh1c2'
    'VybmFtZRIWCgZvbmxpbmUYAyABKAhSBm9ubGluZRIkCg5mcmllbmRlZF9hdF9tcxgEIAEoA1IM'
    'ZnJpZW5kZWRBdE1z');

@$core.Deprecated('Use getFriendsListRequestDescriptor instead')
const GetFriendsListRequest$json = {
  '1': 'GetFriendsListRequest',
};

/// Descriptor for `GetFriendsListRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getFriendsListRequestDescriptor =
    $convert.base64Decode('ChVHZXRGcmllbmRzTGlzdFJlcXVlc3Q=');

@$core.Deprecated('Use getFriendsListResponseDescriptor instead')
const GetFriendsListResponse$json = {
  '1': 'GetFriendsListResponse',
  '2': [
    {
      '1': 'friends',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.quiz.Friend',
      '10': 'friends'
    },
  ],
};

/// Descriptor for `GetFriendsListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getFriendsListResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRGcmllbmRzTGlzdFJlc3BvbnNlEiYKB2ZyaWVuZHMYASADKAsyDC5xdWl6LkZyaWVuZF'
        'IHZnJpZW5kcw==');

@$core.Deprecated('Use getFriendRequestsRequestDescriptor instead')
const GetFriendRequestsRequest$json = {
  '1': 'GetFriendRequestsRequest',
};

/// Descriptor for `GetFriendRequestsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getFriendRequestsRequestDescriptor =
    $convert.base64Decode('ChhHZXRGcmllbmRSZXF1ZXN0c1JlcXVlc3Q=');

@$core.Deprecated('Use getFriendRequestsResponseDescriptor instead')
const GetFriendRequestsResponse$json = {
  '1': 'GetFriendRequestsResponse',
  '2': [
    {
      '1': 'incoming',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.quiz.FriendRequest',
      '10': 'incoming'
    },
  ],
};

/// Descriptor for `GetFriendRequestsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getFriendRequestsResponseDescriptor =
    $convert.base64Decode(
        'ChlHZXRGcmllbmRSZXF1ZXN0c1Jlc3BvbnNlEi8KCGluY29taW5nGAEgAygLMhMucXVpei5Gcm'
        'llbmRSZXF1ZXN0UghpbmNvbWluZw==');

@$core.Deprecated('Use heartbeatRequestDescriptor instead')
const HeartbeatRequest$json = {
  '1': 'HeartbeatRequest',
};

/// Descriptor for `HeartbeatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heartbeatRequestDescriptor =
    $convert.base64Decode('ChBIZWFydGJlYXRSZXF1ZXN0');

@$core.Deprecated('Use heartbeatResponseDescriptor instead')
const HeartbeatResponse$json = {
  '1': 'HeartbeatResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `HeartbeatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heartbeatResponseDescriptor = $convert.base64Decode(
    'ChFIZWFydGJlYXRSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNz');

@$core.Deprecated('Use challengeFriendRequestDescriptor instead')
const ChallengeFriendRequest$json = {
  '1': 'ChallengeFriendRequest',
  '2': [
    {'1': 'friend_user_id', '3': 1, '4': 1, '5': 9, '10': 'friendUserId'},
  ],
};

/// Descriptor for `ChallengeFriendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List challengeFriendRequestDescriptor =
    $convert.base64Decode(
        'ChZDaGFsbGVuZ2VGcmllbmRSZXF1ZXN0EiQKDmZyaWVuZF91c2VyX2lkGAEgASgJUgxmcmllbm'
        'RVc2VySWQ=');

@$core.Deprecated('Use challengeFriendResponseDescriptor instead')
const ChallengeFriendResponse$json = {
  '1': 'ChallengeFriendResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'room_id', '3': 2, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'error_code', '3': 3, '4': 1, '5': 9, '10': 'errorCode'},
  ],
};

/// Descriptor for `ChallengeFriendResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List challengeFriendResponseDescriptor = $convert.base64Decode(
    'ChdDaGFsbGVuZ2VGcmllbmRSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEhcKB3'
    'Jvb21faWQYAiABKAlSBnJvb21JZBIdCgplcnJvcl9jb2RlGAMgASgJUgllcnJvckNvZGU=');

@$core.Deprecated('Use getNotificationPrefsRequestDescriptor instead')
const GetNotificationPrefsRequest$json = {
  '1': 'GetNotificationPrefsRequest',
};

/// Descriptor for `GetNotificationPrefsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getNotificationPrefsRequestDescriptor =
    $convert.base64Decode('ChtHZXROb3RpZmljYXRpb25QcmVmc1JlcXVlc3Q=');

@$core.Deprecated('Use getNotificationPrefsResponseDescriptor instead')
const GetNotificationPrefsResponse$json = {
  '1': 'GetNotificationPrefsResponse',
  '2': [
    {'1': 'muted_types', '3': 1, '4': 3, '5': 9, '10': 'mutedTypes'},
    {'1': 'timezone', '3': 2, '4': 1, '5': 9, '10': 'timezone'},
  ],
};

/// Descriptor for `GetNotificationPrefsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getNotificationPrefsResponseDescriptor =
    $convert.base64Decode(
        'ChxHZXROb3RpZmljYXRpb25QcmVmc1Jlc3BvbnNlEh8KC211dGVkX3R5cGVzGAEgAygJUgptdX'
        'RlZFR5cGVzEhoKCHRpbWV6b25lGAIgASgJUgh0aW1lem9uZQ==');

@$core.Deprecated('Use updateNotificationPrefsRequestDescriptor instead')
const UpdateNotificationPrefsRequest$json = {
  '1': 'UpdateNotificationPrefsRequest',
  '2': [
    {'1': 'muted_types', '3': 1, '4': 3, '5': 9, '10': 'mutedTypes'},
    {'1': 'timezone', '3': 2, '4': 1, '5': 9, '10': 'timezone'},
  ],
};

/// Descriptor for `UpdateNotificationPrefsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateNotificationPrefsRequestDescriptor =
    $convert.base64Decode(
        'Ch5VcGRhdGVOb3RpZmljYXRpb25QcmVmc1JlcXVlc3QSHwoLbXV0ZWRfdHlwZXMYASADKAlSCm'
        '11dGVkVHlwZXMSGgoIdGltZXpvbmUYAiABKAlSCHRpbWV6b25l');

@$core.Deprecated('Use updateNotificationPrefsResponseDescriptor instead')
const UpdateNotificationPrefsResponse$json = {
  '1': 'UpdateNotificationPrefsResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `UpdateNotificationPrefsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateNotificationPrefsResponseDescriptor =
    $convert.base64Decode(
        'Ch9VcGRhdGVOb3RpZmljYXRpb25QcmVmc1Jlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2'
        'Nlc3M=');

@$core.Deprecated('Use markNotificationOpenedRequestDescriptor instead')
const MarkNotificationOpenedRequest$json = {
  '1': 'MarkNotificationOpenedRequest',
  '2': [
    {'1': 'category', '3': 1, '4': 1, '5': 9, '10': 'category'},
  ],
};

/// Descriptor for `MarkNotificationOpenedRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markNotificationOpenedRequestDescriptor =
    $convert.base64Decode(
        'Ch1NYXJrTm90aWZpY2F0aW9uT3BlbmVkUmVxdWVzdBIaCghjYXRlZ29yeRgBIAEoCVIIY2F0ZW'
        'dvcnk=');

@$core.Deprecated('Use markNotificationOpenedResponseDescriptor instead')
const MarkNotificationOpenedResponse$json = {
  '1': 'MarkNotificationOpenedResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `MarkNotificationOpenedResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markNotificationOpenedResponseDescriptor =
    $convert.base64Decode(
        'Ch5NYXJrTm90aWZpY2F0aW9uT3BlbmVkUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2'
        'Vzcw==');

@$core.Deprecated('Use getUserAnalyticsRequestDescriptor instead')
const GetUserAnalyticsRequest$json = {
  '1': 'GetUserAnalyticsRequest',
};

/// Descriptor for `GetUserAnalyticsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUserAnalyticsRequestDescriptor =
    $convert.base64Decode('ChdHZXRVc2VyQW5hbHl0aWNzUmVxdWVzdA==');

@$core.Deprecated('Use getUserAnalyticsResponseDescriptor instead')
const GetUserAnalyticsResponse$json = {
  '1': 'GetUserAnalyticsResponse',
  '2': [
    {
      '1': 'topic_accuracy',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.quiz.TopicAccuracy',
      '10': 'topicAccuracy'
    },
    {
      '1': 'response_time',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.quiz.ResponseTimePercentiles',
      '10': 'responseTime'
    },
    {
      '1': 'rating_history',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.quiz.RatingPoint',
      '10': 'ratingHistory'
    },
    {'1': 'lifetime_matches', '3': 4, '4': 1, '5': 5, '10': 'lifetimeMatches'},
    {'1': 'lifetime_wins', '3': 5, '4': 1, '5': 5, '10': 'lifetimeWins'},
    {'1': 'has_data', '3': 6, '4': 1, '5': 8, '10': 'hasData'},
  ],
};

/// Descriptor for `GetUserAnalyticsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUserAnalyticsResponseDescriptor = $convert.base64Decode(
    'ChhHZXRVc2VyQW5hbHl0aWNzUmVzcG9uc2USOgoOdG9waWNfYWNjdXJhY3kYASADKAsyEy5xdW'
    'l6LlRvcGljQWNjdXJhY3lSDXRvcGljQWNjdXJhY3kSQgoNcmVzcG9uc2VfdGltZRgCIAEoCzId'
    'LnF1aXouUmVzcG9uc2VUaW1lUGVyY2VudGlsZXNSDHJlc3BvbnNlVGltZRI4Cg5yYXRpbmdfaG'
    'lzdG9yeRgDIAMoCzIRLnF1aXouUmF0aW5nUG9pbnRSDXJhdGluZ0hpc3RvcnkSKQoQbGlmZXRp'
    'bWVfbWF0Y2hlcxgEIAEoBVIPbGlmZXRpbWVNYXRjaGVzEiMKDWxpZmV0aW1lX3dpbnMYBSABKA'
    'VSDGxpZmV0aW1lV2lucxIZCghoYXNfZGF0YRgGIAEoCFIHaGFzRGF0YQ==');

@$core.Deprecated('Use topicAccuracyDescriptor instead')
const TopicAccuracy$json = {
  '1': 'TopicAccuracy',
  '2': [
    {'1': 'topic', '3': 1, '4': 1, '5': 9, '10': 'topic'},
    {'1': 'total', '3': 2, '4': 1, '5': 5, '10': 'total'},
    {'1': 'correct', '3': 3, '4': 1, '5': 5, '10': 'correct'},
    {'1': 'accuracy_pct', '3': 4, '4': 1, '5': 1, '10': 'accuracyPct'},
  ],
};

/// Descriptor for `TopicAccuracy`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List topicAccuracyDescriptor = $convert.base64Decode(
    'Cg1Ub3BpY0FjY3VyYWN5EhQKBXRvcGljGAEgASgJUgV0b3BpYxIUCgV0b3RhbBgCIAEoBVIFdG'
    '90YWwSGAoHY29ycmVjdBgDIAEoBVIHY29ycmVjdBIhCgxhY2N1cmFjeV9wY3QYBCABKAFSC2Fj'
    'Y3VyYWN5UGN0');

@$core.Deprecated('Use responseTimePercentilesDescriptor instead')
const ResponseTimePercentiles$json = {
  '1': 'ResponseTimePercentiles',
  '2': [
    {'1': 'p50_ms', '3': 1, '4': 1, '5': 1, '10': 'p50Ms'},
    {'1': 'p90_ms', '3': 2, '4': 1, '5': 1, '10': 'p90Ms'},
    {'1': 'p95_ms', '3': 3, '4': 1, '5': 1, '10': 'p95Ms'},
    {'1': 'p99_ms', '3': 4, '4': 1, '5': 1, '10': 'p99Ms'},
    {'1': 'sample_count', '3': 5, '4': 1, '5': 3, '10': 'sampleCount'},
  ],
};

/// Descriptor for `ResponseTimePercentiles`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List responseTimePercentilesDescriptor = $convert.base64Decode(
    'ChdSZXNwb25zZVRpbWVQZXJjZW50aWxlcxIVCgZwNTBfbXMYASABKAFSBXA1ME1zEhUKBnA5MF'
    '9tcxgCIAEoAVIFcDkwTXMSFQoGcDk1X21zGAMgASgBUgVwOTVNcxIVCgZwOTlfbXMYBCABKAFS'
    'BXA5OU1zEiEKDHNhbXBsZV9jb3VudBgFIAEoA1ILc2FtcGxlQ291bnQ=');

@$core.Deprecated('Use ratingPointDescriptor instead')
const RatingPoint$json = {
  '1': 'RatingPoint',
  '2': [
    {'1': 'unix_day', '3': 1, '4': 1, '5': 3, '10': 'unixDay'},
    {'1': 'rating', '3': 2, '4': 1, '5': 5, '10': 'rating'},
  ],
};

/// Descriptor for `RatingPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ratingPointDescriptor = $convert.base64Decode(
    'CgtSYXRpbmdQb2ludBIZCgh1bml4X2RheRgBIAEoA1IHdW5peERheRIWCgZyYXRpbmcYAiABKA'
    'VSBnJhdGluZw==');

@$core.Deprecated('Use getMonthlyRecapRequestDescriptor instead')
const GetMonthlyRecapRequest$json = {
  '1': 'GetMonthlyRecapRequest',
  '2': [
    {'1': 'year', '3': 1, '4': 1, '5': 5, '10': 'year'},
    {'1': 'month', '3': 2, '4': 1, '5': 5, '10': 'month'},
  ],
};

/// Descriptor for `GetMonthlyRecapRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMonthlyRecapRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRNb250aGx5UmVjYXBSZXF1ZXN0EhIKBHllYXIYASABKAVSBHllYXISFAoFbW9udGgYAi'
        'ABKAVSBW1vbnRo');

@$core.Deprecated('Use getMonthlyRecapResponseDescriptor instead')
const GetMonthlyRecapResponse$json = {
  '1': 'GetMonthlyRecapResponse',
  '2': [
    {'1': 'year', '3': 1, '4': 1, '5': 5, '10': 'year'},
    {'1': 'month', '3': 2, '4': 1, '5': 5, '10': 'month'},
    {'1': 'matches_played', '3': 3, '4': 1, '5': 5, '10': 'matchesPlayed'},
    {'1': 'wins', '3': 4, '4': 1, '5': 5, '10': 'wins'},
    {'1': 'win_rate', '3': 5, '4': 1, '5': 1, '10': 'winRate'},
    {'1': 'favorite_topic', '3': 6, '4': 1, '5': 9, '10': 'favoriteTopic'},
    {
      '1': 'longest_streak_lifetime',
      '3': 7,
      '4': 1,
      '5': 5,
      '10': 'longestStreakLifetime'
    },
    {'1': 'has_data', '3': 8, '4': 1, '5': 8, '10': 'hasData'},
  ],
};

/// Descriptor for `GetMonthlyRecapResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMonthlyRecapResponseDescriptor = $convert.base64Decode(
    'ChdHZXRNb250aGx5UmVjYXBSZXNwb25zZRISCgR5ZWFyGAEgASgFUgR5ZWFyEhQKBW1vbnRoGA'
    'IgASgFUgVtb250aBIlCg5tYXRjaGVzX3BsYXllZBgDIAEoBVINbWF0Y2hlc1BsYXllZBISCgR3'
    'aW5zGAQgASgFUgR3aW5zEhkKCHdpbl9yYXRlGAUgASgBUgd3aW5SYXRlEiUKDmZhdm9yaXRlX3'
    'RvcGljGAYgASgJUg1mYXZvcml0ZVRvcGljEjYKF2xvbmdlc3Rfc3RyZWFrX2xpZmV0aW1lGAcg'
    'ASgFUhVsb25nZXN0U3RyZWFrTGlmZXRpbWUSGQoIaGFzX2RhdGEYCCABKAhSB2hhc0RhdGE=');
