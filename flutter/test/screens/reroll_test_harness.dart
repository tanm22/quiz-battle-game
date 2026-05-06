import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quiz_battle/providers/coins_state.dart';
import 'package:quiz_battle/services/coins_service.dart';
import 'package:quiz_battle/widgets/reroll_button.dart';

/// Wraps a [RerollButton] in a ProviderScope with [coinsServiceProvider]
/// overridden to [coinsService]. The inventory provider delegates to the
/// fake's [CoinsService.inventory] method so post-spend state changes are
/// visible to tests after `invalidateCoinState(ref)` re-runs the provider.
Widget wrap({required CoinsService coinsService}) {
  return ProviderScope(
    overrides: [
      coinsServiceProvider.overrideWithValue(coinsService),
      shopInventoryProvider.overrideWith((ref) async {
        return ref.read(coinsServiceProvider).inventory();
      }),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: Center(child: RerollButton(roomId: 'r1', roundId: '3')),
      ),
    ),
  );
}
