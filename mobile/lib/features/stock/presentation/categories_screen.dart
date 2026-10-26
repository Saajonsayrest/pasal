import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/icon_names.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/stock/data/category_repository.dart';
import 'package:pasal_mobile/features/stock/presentation/category_form.dart';

/// D8. Categories with their icon, colour and item count. Add, edit or delete. Owner only.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Category? category) async {
    final action = await showPasalSheet<CategoryAction>(
      context,
      title: category == null ? context.tr('New category', 'नयाँ वर्ग') : context.tr('Edit category', 'वर्ग सच्याउने'),
      builder: (_) => CategoryForm(category: category),
    );
    if (action == null || !context.mounted) return;
    ref
      ..invalidate(categoriesProvider)
      ..invalidate(categoryItemCountsProvider);
    switch (action) {
      case CategoryAction.deleted:
        showToast(context, 'Category deleted. Items stay.', 'वर्ग मेटियो। सामान रहन्छन्।');
      case CategoryAction.saved when category == null:
        showToast(context, 'Category added', 'वर्ग थपियो');
      case CategoryAction.saved:
        showToast(context, 'Category saved', 'वर्ग सेभ भयो');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    final counts = ref.watch(categoryItemCountsProvider).value ?? const <int, int>{};

    return PageScaffold(
      title: context.tr('Categories', 'वर्गहरू'),
      scroll: false,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _open(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('Add', 'थप्ने')),
      ),
      body: AsyncBody(
        value: cats,
        onRetry: () => ref.invalidate(categoriesProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.category_rounded,
              title: context.tr('No categories yet', 'अहिलेसम्म वर्ग छैन'),
              text: context.tr('Add a category to group your items.', 'सामान समूहमा राख्न वर्ग थप्नुहोस्।'),
              actionLabel: context.tr('Add', 'थप्ने'),
              onAction: () => _open(context, ref, null),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              Text(
                context.tr('Use categories to group items. Pick an icon and colour for each.', 'सामानलाई समूहमा राख्न वर्ग प्रयोग गर्नुहोस्। हरेकको लागि आइकन र रंग छान्नुहोस्।'),
                style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ListCard(
                children: [for (final c in list) _row(context, ref, c, counts[c.id])],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Category c, int? count) {
    final tint = colorFromHex(c.color) ?? context.scheme.primary;
    return ListRow(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: tint.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(Radii.md)),
        child: Icon(symbolIcon(c.icon), color: tint),
      ),
      title: c.name,
      trailing: count == null
          ? null
          : PBadge(
              '${context.num(count)} ${context.plural(count, 'item', 'items', 'सामान')}',
            ),
      onTap: () => _open(context, ref, c),
    );
  }
}
