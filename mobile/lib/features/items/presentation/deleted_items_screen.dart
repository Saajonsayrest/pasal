import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/items/data/item_providers.dart';
import 'package:pasal_mobile/features/items/presentation/item_widgets.dart';

/// D9. Deleted items. The owner can bring one back with its stock history (owner only).
class DeletedItemsScreen extends ConsumerStatefulWidget {
  const DeletedItemsScreen({super.key});

  @override
  ConsumerState<DeletedItemsScreen> createState() => _DeletedItemsScreenState();
}

class _DeletedItemsScreenState extends ConsumerState<DeletedItemsScreen> {
  final Set<int> _busy = {};
  final Map<int, String> _rowError = {};

  Future<void> _refresh() async {
    ref.invalidate(deletedItemsProvider);
    try {
      await ref.read(deletedItemsProvider.future);
    } catch (_) {
      // The error view on the screen shows the problem and offers a retry.
    }
  }

  Future<void> _restore(Item item) async {
    setState(() {
      _busy.add(item.id);
      _rowError.remove(item.id);
    });
    try {
      await ref.read(itemRepositoryProvider).restore(item.id);
      if (!mounted) return;
      ref.invalidate(deletedItemsProvider);
      ref.invalidate(itemListProvider);
      ref.invalidate(lowStockCountProvider);
      showToast(context, 'Restored: ${item.name}', 'फिर्ता ल्याइयो: ${item.name}');
    } on ApiException catch (e) {
      if (mounted) setState(() => _rowError[item.id] = e.field('name') ?? e.message);
    } finally {
      if (mounted) {
        setState(() => _busy.remove(item.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deleted = ref.watch(deletedItemsProvider);
    final categories = ref.watch(itemCategoriesProvider).value ?? const <Category>[];

    return PageScaffold(
      title: context.tr('Deleted items', 'हटाइएका सामान'),
      onRefresh: _refresh,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AlertBox(
            context.tr(
              'Deleted items stay in old bills. Restoring brings back their history.',
              'हटाइएका सामान पुराना बिलमा रहन्छन्। फिर्ता ल्याउँदा तिनको इतिहास पनि आउँछ।',
            ),
            tone: Tone.info,
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 12),
          AsyncBody(
            value: deleted,
            onRetry: () => ref.invalidate(deletedItemsProvider),
            data: (items) {
              if (items.isEmpty) {
                return SizedBox(
                  height: 360,
                  child: EmptyState(
                    icon: Icons.delete_sweep_rounded,
                    title: context.tr('No deleted items', 'हटाइएका सामान छैनन्'),
                    text: context.tr(
                      'Items you delete will show here. You can bring them back.',
                      'हटाएका सामान यहाँ देखिन्छन्। तिनलाई फिर्ता ल्याउन सकिन्छ।',
                    ),
                  ),
                );
              }
              return ListCard(
                children: [for (final it in items) _row(it, categories)],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row(Item it, List<Category> categories) {
    final category = categoryNameOf(categories, it.categoryId);
    final error = _rowError[it.id];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ItemThumb(photoUrl: it.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  [if (category.isNotEmpty) category, context.rs(it.sellPrice)].join(' · '),
                  style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(error, style: context.text.bodySmall?.copyWith(color: context.colors.bad)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _busy.contains(it.id) ? null : () => _restore(it),
            icon: const Icon(Icons.restore_rounded),
            label: Text(context.tr('Restore', 'फिर्ता ल्याउने')),
          ),
        ],
      ),
    );
  }
}
