import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quiz_battle/proto/quiz.pb.dart';
import 'package:quiz_battle/providers/coins_state.dart';
import 'package:quiz_battle/services/coins_service.dart';

import 'package:quiz_battle/widgets/reroll_button.dart';

/// A minimal scaffold that hosts a [RerollButton] inside a ProviderScope
/// with the inventory provider seeded to [charges] and the
/// [coinsServiceProvider] overridden with [coinsService]. Mirrors the
/// gameplay screen's reroll-button surface without dragging the full
/// match state in.
Widget wrap({required CoinsService coinsService, required int charges}) {
  final inv = GetShopInventoryResponse()
    ..rerollCharges = charges
    ..balance = Int64(500);
  return ProviderScope(
    overrides: [
      coinsServiceProvider.overrideWithValue(coinsService),
      shopInventoryProvider.overrideWith((ref) async => inv),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: Center(child: RerollButton(roomId: 'r1', roundId: '3')),
      ),
    ),
  );
}
