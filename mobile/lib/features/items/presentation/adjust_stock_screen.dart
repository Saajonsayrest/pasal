import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/items/data/item_providers.dart';
import 'package:pasal_mobile/features/items/presentation/adjust_stock_sheet.dart';
import 'package:pasal_mobile/features/items/presentation/item_widgets.dart';

/// D4. Adjust stock for one item on its own page (owner only). The item details screen uses the same form in a sheet.
class AdjustStockScreen extends ConsumerWidget {
  const AdjustStockScreen({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemDetailProvider(id));
    return PageScaffold(
      title: context.tr('Adjust stock', 'स्टक मिलाउने'),
      body: AsyncBody(
        value: item,
        onRetry: () => ref.invalidate(itemDetailProvider(id)),
        data: (i) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PCard(
              child: Row(
                children: [
                  ItemThumb(photoUrl: i.photoUrl, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(i.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(context.num(i.quantity), style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text(i.unit, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PCard(
              child: AdjustStockSheet(item: i, onSaved: (_) => context.go('/items/$id')),
            ),
          ],
        ),
      ),
    );
  }
}
