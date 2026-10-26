import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/launch.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/stock/data/stock_repository.dart';

/// D10. Pick items and copies, see the label preview, share the list as text. Printing is not on the phone yet. Owner only.
class BarcodeLabelsScreen extends ConsumerStatefulWidget {
  const BarcodeLabelsScreen({super.key});

  @override
  ConsumerState<BarcodeLabelsScreen> createState() => _BarcodeLabelsScreenState();
}

class _BarcodeLabelsScreenState extends ConsumerState<BarcodeLabelsScreen> {
  final _search = TextEditingController();
  bool _large = false;
  String _query = '';

  /// Chosen items and how many labels each one gets (1 to 99).
  final Map<int, int> _copies = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(Item item) {
    setState(() {
      if (_copies.containsKey(item.id)) {
        _copies.remove(item.id);
      } else {
        _copies[item.id] = 1;
      }
    });
  }

  void _setCopies(Item item, int n) {
    setState(() => _copies[item.id] = n < 1 ? 1 : (n > 99 ? 99 : n));
  }

  String _shareText(List<Item> labels) => [
        for (final item in labels)
          [item.name, context.rs(item.sellPrice), if (item.sku != null) item.sku!].join(', '),
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(allItemsProvider);
    final shop = ref.watch(sessionProvider).business?.name ?? 'PASAL';
    final all = items.value ?? const <Item>[];
    final labels = [
      for (final item in all)
        if (_copies.containsKey(item.id)) ...List.filled(_copies[item.id]!, item),
    ];

    return PageScaffold(
      title: context.tr('Barcode labels', 'बारकोड लेबल'),
      scroll: false,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr(
              'Printing is not on the phone yet. Share the list and print it from a computer.',
              'फोनबाट प्रिन्ट गर्ने सुविधा अझै छैन। सूची पठाएर कम्प्युटरबाट छाप्नुहोस्।',
            ),
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: context.tr('Share label list as text', 'लेबलको सूची टेक्स्टमा पठाउने'),
            icon: Icons.share_rounded,
            onPressed: labels.isEmpty ? null : () => shareText(_shareText(labels)),
          ),
        ],
      ),
      body: AsyncBody(
        value: items,
        onRetry: () => ref.invalidate(allItemsProvider),
        data: (list) => _body(context, list, labels, shop),
      ),
    );
  }

  Widget _body(BuildContext context, List<Item> all, List<Item> labels, String shop) {
    final visible = all.where((i) {
      final q = _query.trim().toLowerCase();
      return q.isEmpty || i.name.toLowerCase().contains(q) || (i.sku ?? '').toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(context.tr('Label size', 'लेबलको साइज'), style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Seg<String>(
          value: _large ? 'large' : 'small',
          onChanged: (v) => setState(() => _large = v == 'large'),
          options: {
            'small': context.tr('Small · 38 × 25 mm', 'सानो · ३८ × २५ मिमि'),
            'large': context.tr('Large · 50 × 30 mm', 'ठूलो · ५० × ३० मिमि'),
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: context.tr('Search item name or code', 'सामानको नाम वा कोड खोज्नुहोस्'),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),
        Text(context.tr('Items to print', 'लेबल छाप्ने सामान'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          PCard(child: Text(context.tr('No items match', 'मेल खाने सामान भेटिएन'), style: context.text.bodyMedium))
        else
          ListCard(children: [for (final item in visible) _row(context, item)]),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Text(context.tr('Label preview', 'लेबल नमुना'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
            Text(
              context.tr('${context.num(labels.length)} labels', '${context.num(labels.length)} लेबल'),
              style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (labels.isEmpty)
          PCard(child: Text(context.tr('Tick items above to make labels.', 'लेबल बनाउन माथि सामान छान्नुहोस्।'), style: context.text.bodyMedium))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in labels) _Sticker(shop: shop, item: item, large: _large, price: context.rs(item.sellPrice)),
            ],
          ),
      ],
    );
  }

  Widget _row(BuildContext context, Item item) {
    final n = _copies[item.id];
    final sku = item.sku == null ? '' : ' · ${item.sku}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
      child: Row(
        children: [
          Checkbox(value: n != null, onChanged: (_) => _toggle(item)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '${context.rs(item.sellPrice)}$sku',
                  style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (n != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: context.tr('Fewer copies', 'कम प्रति'),
                  onPressed: () => _setCopies(item, n - 1),
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 28,
                  child: Text(context.num(n), textAlign: TextAlign.center, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: context.tr('More copies', 'थप प्रति'),
                  onPressed: () => _setCopies(item, n + 1),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One printed label. Black on white, like the sticker.
class _Sticker extends StatelessWidget {
  const _Sticker({required this.shop, required this.item, required this.large, required this.price});

  final String shop;
  final Item item;
  final bool large;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: large ? 200 : 152,
      height: large ? 120 : 100,
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black26),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(shop, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.black54)),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: large ? 12 : 11, fontWeight: FontWeight.w600, color: Colors.black)),
          if (item.sku != null)
            Text(
              item.sku!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: large ? 20 : 17, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.black),
            ),
          Text(price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
        ],
      ),
    );
  }
}
