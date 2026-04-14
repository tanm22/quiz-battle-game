// This is a generated file - do not edit.
//
// Generated from quiz.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class MatchmakingStatus extends $pb.ProtobufEnum {
  static const MatchmakingStatus QUEUED =
      MatchmakingStatus._(0, _omitEnumNames ? '' : 'QUEUED');
  static const MatchmakingStatus ALREADY_IN_QUEUE =
      MatchmakingStatus._(1, _omitEnumNames ? '' : 'ALREADY_IN_QUEUE');

  static const $core.List<MatchmakingStatus> values = <MatchmakingStatus>[
    QUEUED,
    ALREADY_IN_QUEUE,
  ];

  static final $core.List<MatchmakingStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static MatchmakingStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MatchmakingStatus._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
