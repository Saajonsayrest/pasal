import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/stock/data/stock_repository.dart';
import 'package:pasal_mobile/features/stock/data/stock_rules.dart';

/// D7. Items at or below their low level, grouped by category, with a suggested order amount. Owner only.
class LowStockScreen extends ConsumerStatefulWidget {
  const LowStockScreen({super.key});

  @override
  ConsumerState<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends ConsumerState<LowStockScreen> {
  /// Ticked items. Every item starts ticked.
  final Map<int, bool> _picked = {};
  final Map<int, TextEditingController> _orders = {};

  @override
  void dispose() {
    for (final box in _orders.values) {
      box.dispose();
    }
    super.dispose();
  }

  bool _isPicked(Item item) => _picked[item.id] ?? true;

  TextEditingController _orderBox(Item item) => _orders.putIfAbsent(item.id, () => TextEditingController(text: '${suggestedOrder(item)}'));

  /// The order amount in the box, or null when the box holds less than 1.
  int? _orderOf(Item item) {
    final text = _orders[item.id]?.text ?? '${suggestedOrder(item)}';
    final n = parseWhole(text);
    return n != null && n >= 1 ? n : null;
  }

  void _buy(LowStockGroup group) {
    final pairs = [
      for (final item in group.items)
        if (_isPicked(item) && _orderOf(item) != null) '${item.id}:${_orderOf(item)}',
    ];
    if (pairs.isEmpty) return;
    context.push('/purchases/new?items=${pairs.join(',')}');
  }

  @override
  Widget build(BuildContext context) {
    final low = ref.watch(lowStockProvider);
    final isOwner = ref.watch(sessionProvider).isOwner;

    return PageScaffold(
      title: context.tr('Low stock and reorder', 'कम स्टक र पुनः अर्डर'),
      scroll: false,
      body: AsyncBody(
        value: low,
        onRetry: () => ref.invalidate(lowStockProvider),
        data: (data) => _body(context, data, isOwner),
      ),
    );
  }

  Widget _body(BuildContext context, LowStockData data, bool isOwner) {
    if (data.items.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_rounded,
        title: context.tr('Nothing is low right now', 'अहिले कम स्टकको सामान छैन'),
        text: context.tr('Items show here when stock falls to the low level.', 'स्टक कम तहमा झर्दा सामान यहाँ देखिन्छ।'),
      );
    }

    final groups = groupLowStock(data.items, data.categories, noCategory: context.tr('No category', 'बिना वर्ग'));
    final ticked = <({Item item, int quantity})>[];
    for (final item in data.items) {
      final n = _orderOf(item);
      if (_isPicked(item) && n != null) ticked.add((item: item, quantity: n));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        HeroCard(
          tone: Tone.warn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatBlock(
                large: true,
                tone: Tone.warn,
                label: context.tr('Low stock items', 'कम स्टकका सामान'),
                value: context.num(data.items.length),
                sub: context.tr('${context.num(groups.length)} categories', '${context.num(groups.length)} वर्गबाट'),
              ),
              if (isOwner) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(context.tr('Buying cost of ticked items', 'चिनिएका सामानको खरिद मूल्य'), style: context.text.bodyMedium)),
                    Text(context.rs(orderCostPaisa(ticked)), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('Grouped by category. Items are not linked to a supplier yet.', 'वर्ग अनुसार समूहमा। सामान अहिले डिलरसँग जोडिएको छैन।'),
          style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              '${group.name} · ${context.tr('${context.num(group.items.length)} items', '${context.num(group.items.length)} सामान')}',
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ListCard(
            children: [for (final item in group.items) _row(context, item, group.icon)],
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: context.tr('Make purchase', 'खरिद गर्ने'),
            icon: Icons.shopping_bag_rounded,
            onPressed: group.items.any((i) => _isPicked(i) && _orderOf(i) != null) ? () => _buy(group) : null,
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, Item item, IconData icon) {
    final n = _orderOf(item);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
      child: Row(
        children: [
          Checkbox(
            value: _isPicked(item),
            onChanged: (v) => setState(() => _picked[item.id] = v ?? false),
          ),
          IconTile(icon, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  context.tr(
                    'Stock ${context.num(item.quantity)} · low level ${context.num(item.lowStockAt)}',
                    'स्टक ${context.num(item.quantity)} · कम तह ${context.num(item.lowStockAt)}',
                  ),
                  style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: stockFraction(item),
                  color: context.colors.warn,
                  backgroundColor: context.colors.warnSoft,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('Order', 'अर्डर'), style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant)),
              SizedBox(
                width: 88,
                child: Semantics(
                  label: context.tr('Order quantity for ${item.name}', '${item.name} को अर्डर संख्या'),
                  child: TextField(
                    controller: _orderBox(item),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              if (n == null) Text(context.tr('1 or more', '१ वा माथि'), style: context.text.labelSmall?.copyWith(color: context.colors.bad)),
            ],
          ),
        ],
      ),
    );
  }
}
