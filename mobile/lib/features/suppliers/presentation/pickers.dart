import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/features/suppliers/data/purchase_repository.dart';

/// The answer of [showSupplierPicker]. A null supplier means "All suppliers" (only when asked for).
typedef SupplierPick = ({Supplier? supplier});

/// Bottom sheet to choose one supplier from [suppliers].
Future<SupplierPick?> showSupplierPicker(BuildContext context, {required List<Supplier> suppliers, bool allowAll = false}) {
  return showPasalSheet<SupplierPick>(
    context,
    title: context.tr('Choose supplier', 'डिलर छान्नुहोस्'),
    builder: (ctx) => _SupplierPicker(suppliers: suppliers, allowAll: allowAll),
  );
}

class _SupplierPicker extends StatefulWidget {
  const _SupplierPicker({required this.suppliers, required this.allowAll});

  final List<Supplier> suppliers;
  final bool allowAll;

  @override
  State<_SupplierPicker> createState() => _SupplierPickerState();
}

class _SupplierPickerState extends State<_SupplierPicker> {
  String _term = '';

  @override
  Widget build(BuildContext context) {
    final q = _term.toLowerCase();
    final matches = widget.suppliers.where((s) => s.name.toLowerCase().contains(q) || (s.phone ?? '').contains(q)).toList();
    const all = (supplier: null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (v) => setState(() => _term = v.trim()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: context.tr('Search supplier name or phone', 'डिलरको नाम वा फोन खोज्नुहोस्'),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.suppliers.isEmpty)
          EmptyState(
            icon: Icons.storefront_rounded,
            title: context.tr('No supplier found', 'डिलर भेटिएन'),
            text: context.tr('Add the supplier first from the Suppliers screen.', 'पहिले डिलर स्क्रिनबाट डिलर थप्नुहोस्।'),
          )
        else
          ListCard(
            children: [
              if (widget.allowAll)
                ListRow(
                  leading: const IconTile(Icons.all_inclusive_rounded, tone: Tone.neutral),
                  title: context.tr('All suppliers', 'सबै डिलर'),
                  chevron: false,
                  onTap: () => Navigator.of(context).pop<SupplierPick>(all),
                ),
              for (final s in matches)
                ListRow(
                  leading: AvatarCircle(s.name, tone: Tone.info),
                  title: s.name,
                  subtitle: s.phone,
                  amount: (s.weOwe ?? 0) > 0 ? context.rs(s.weOwe) : null,
                  amountTone: Tone.warn,
                  chevron: false,
                  onTap: () => Navigator.of(context).pop<SupplierPick>((supplier: s)),
                ),
              if (matches.isEmpty && _term.isNotEmpty)
                ListRow(title: context.tr('No supplier found', 'डिलर भेटिएन'), chevron: false),
            ],
          ),
      ],
    );
  }
}

/// Bottom sheet to add an item to a bill. Returns the item picked, or null. [added] marks items already on the bill.
Future<Item?> showItemPicker(BuildContext context, {required Set<int> added}) {
  return showPasalSheet<Item>(
    context,
    title: context.tr('Add item', 'सामान थप्ने'),
    builder: (ctx) => _ItemPicker(added: added),
  );
}

class _ItemPicker extends ConsumerStatefulWidget {
  const _ItemPicker({required this.added});

  final Set<int> added;

  @override
  ConsumerState<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends ConsumerState<_ItemPicker> {
  final _debounce = Debouncer();
  String _term = '';

  @override
  void dispose() {
    _debounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemSearchProvider(_term));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (v) => _debounce.run(() => setState(() => _term = v.trim())),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: context.tr('Search item to add', 'थप्न सामान खोज्नुहोस्'),
          ),
        ),
        const SizedBox(height: 12),
        if (items.hasError && !items.hasValue)
          ErrorView(error: items.error!, onRetry: () => ref.invalidate(itemSearchProvider(_term)))
        else if (!items.hasValue)
          const SkeletonList(rows: 4)
        else if (items.requireValue.isEmpty)
          EmptyState(
            icon: Icons.inventory_2_rounded,
            title: context.tr('No item found', 'सामान भेटिएन'),
            text: context.tr('Try another word, or add the item first.', 'अर्को शब्द खोज्नुहोस्, वा पहिले सामान थप्नुहोस्।'),
          )
        else
          ListCard(
            children: [
              for (final item in items.requireValue)
                ListRow(
                  title: item.name,
                  subtitle: context.tr('${context.num(item.quantity)} ${item.unit} in stock', 'स्टकमा ${context.num(item.quantity)} ${item.unit}'),
                  trailing: widget.added.contains(item.id) ? PBadge(context.tr('Added', 'थपियो'), tone: Tone.good) : null,
                  chevron: false,
                  onTap: () => Navigator.of(context).pop<Item>(item),
                ),
            ],
          ),
      ],
    );
  }
}
