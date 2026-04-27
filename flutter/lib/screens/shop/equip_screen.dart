import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../proto/quiz.pb.dart';
import '../../providers/coins_state.dart';
import '../../theme/app_theme.dart';

/// Manages cosmetics the user already owns. Two sections — Avatar Frames
/// and Name Colors — list owned items and let the user tap one to equip
/// it. Tapping calls `EquipCosmetic` and invalidates
/// [shopInventoryProvider] so the UI rerenders with the new equipped
/// state. Re-tapping the already-equipped item is a no-op success on the
/// server side.
///
/// Items the user does not own are not shown here — that's the shop's
/// job. If the user owns nothing yet, both sections show an
/// encouragement to visit the shop.
class EquipScreen extends ConsumerWidget {
  const EquipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(shopCatalogProvider);
    final inventory = ref.watch(shopInventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equip Cosmetics'),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load cosmetics: $e',
                style: const TextStyle(color: AppColors.danger)),
          ),
        ),
        data: (allItems) {
          return inventory.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load inventory: $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
            ),
            data: (inv) {
              final owned = inv.ownedCosmetics.toSet();
              final frames = allItems
                  .where(
                      (it) => it.kind == 'cosmetic.avatar_frame' && owned.contains(it.id))
                  .toList();
              final colors = allItems
                  .where(
                      (it) => it.kind == 'cosmetic.name_color' && owned.contains(it.id))
                  .toList();
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _Section(
                    title: 'Avatar Frames',
                    emptyHint: 'You don\'t own any frames yet — find one in the shop.',
                    items: frames,
                    equippedId: inv.equippedCosmeticId,
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: 'Name Colors',
                    emptyHint: 'No name colors yet — pick one up from the shop.',
                    items: colors,
                    equippedId: inv.equippedNameColor,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Section extends ConsumerWidget {
  const _Section({
    required this.title,
    required this.emptyHint,
    required this.items,
    required this.equippedId,
  });

  final String title;
  final String emptyHint;
  final List<ShopItem> items;
  final String equippedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(emptyHint,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        // Stable key per item id — _EquipTile carries per-row state
        // (`_busy`) so if a future change ever sorts/filters this list,
        // Flutter must re-associate state to the right row by id rather
        // than positional index.
        for (final it in items)
          _EquipTile(
            key: ValueKey(it.id),
            item: it,
            equipped: it.id == equippedId,
          ),
      ],
    );
  }
}

class _EquipTile extends ConsumerStatefulWidget {
  const _EquipTile({super.key, required this.item, required this.equipped});

  final ShopItem item;
  final bool equipped;

  @override
  ConsumerState<_EquipTile> createState() => _EquipTileState();
}

class _EquipTileState extends ConsumerState<_EquipTile> {
  bool _busy = false;

  Future<void> _equip() async {
    setState(() => _busy = true);
    try {
      final r = await ref.read(coinsServiceProvider).equip(widget.item.id);
      if (!mounted) return;
      if (r.success) {
        ref.invalidate(shopInventoryProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t equip: ${r.errorCode}')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error — try again')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.equipped ? AppColors.success : AppColors.text;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: widget.equipped ? AppColors.success : AppColors.border,
          width: widget.equipped ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          widget.equipped ? Icons.check_circle : Icons.brush,
          color: color,
        ),
        title: Text(
          widget.item.name,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          widget.item.description,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                widget.equipped ? 'Equipped' : 'Equip',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
        onTap: widget.equipped || _busy ? null : _equip,
      ),
    );
  }
}
