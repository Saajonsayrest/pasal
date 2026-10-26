import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/stock/data/stock_repository.dart';

enum _Filter { all, sales, purchases, adjust, returns }

const _reasonsByFilter = <_Filter, List<String>>{
  _Filter.sales: ['sale'],
  _Filter.purchases: ['purchase'],
  _Filter.adjust: ['adjust', 'count'],
  _Filter.returns: ['sale_return', 'sale_cancel'],
};

/// D5. Every stock change of one item, newest first, with filter chips and "Load more". Owner only.
class StockHistoryScreen extends ConsumerStatefulWidget {
  const StockHistoryScreen({required this.itemId, super.key});

  final int itemId;

  @override
  ConsumerState<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends ConsumerState<StockHistoryScreen> {
  _Filter _filter = _Filter.all;

  /// How many pages the person has asked for. Each page is its own provider, so a loaded page is cached.
  int _pages = 1;

  ({int itemId, int page}) _query(int page) => (itemId: widget.itemId, page: page);

  void _reload() => ref.invalidate(stockHistoryPageProvider);

  String _reasonLabel(String reason) {
    return switch (reason) {
      'sale' => context.tr('Sale', 'बिक्री'),
      'sale_return' => context.tr('Sale return', 'बिक्री फिर्ता'),
      'sale_cancel' => context.tr('Sale cancelled', 'बिक्री रद्द'),
      'purchase' => context.tr('Purchase', 'खरिद'),
      'adjust' => context.tr('Adjusted by hand', 'हातले समायोजन'),
      _ => context.tr('Stock count', 'स्टक गणना'),
    };
  }

  String? _billLink(StockMovement m) {
    final id = m.refId;
    if (id == null) return null;
    if (m.refType == 'sale') return '/sales/$id';
    if (m.refType == 'purchase') return '/purchases/$id';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final first = ref.watch(stockHistoryPageProvider(_query(1)));
    final more = [for (var p = 2; p <= _pages; p++) ref.watch(stockHistoryPageProvider(_query(p)))];

    return PageScaffold(
      title: context.tr('Stock history', 'स्टक इतिहास'),
      scroll: false,
      body: AsyncBody(
        value: first,
        onRetry: _reload,
        data: (page) => _content(context, page, more),
      ),
    );
  }

  Widget _content(BuildContext context, StockHistoryPage first, List<AsyncValue<StockHistoryPage>> more) {
    final loaded = [first, for (final m in more) if (m.hasValue) m.requireValue];
    AsyncValue<StockHistoryPage>? failed;
    for (final m in more) {
      if (m.hasError && !m.hasValue) failed = m;
    }
    final movements = [for (final page in loaded) ...page.movements];
    final shown = _filter == _Filter.all ? movements : movements.where((m) => _reasonsByFilter[_filter]!.contains(m.reason)).toList();
    final hasMore = loaded.last.hasMore && failed == null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        PCard(
          child: Row(
            children: [
              const IconTile(Icons.inventory_2_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(first.item.name, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      context.tr('Stock now ${context.num(first.item.quantity)}', 'अहिले स्टक ${context.num(first.item.quantity)}'),
                      style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ChipsRow<_Filter>(
          value: _filter,
          onChanged: (v) => setState(() => _filter = v),
          options: {
            _Filter.all: context.tr('All', 'सबै'),
            _Filter.sales: context.tr('Sales', 'बिक्री'),
            _Filter.purchases: context.tr('Purchases', 'खरिद'),
            _Filter.adjust: context.tr('Adjustments', 'समायोजन'),
            _Filter.returns: context.tr('Returns', 'फिर्ता'),
          },
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          SizedBox(
            height: 320,
            child: EmptyState(
              icon: Icons.history_rounded,
              title: context.tr('No stock changes yet', 'अहिलेसम्म स्टक परिवर्तन छैन'),
              text: context.tr('Sales, purchases and stock counts show here.', 'बिक्री, खरिद र स्टक गणना यहाँ देखिन्छ।'),
            ),
          )
        else
          ListCard(
            children: [
              for (final m in shown)
                ListRow(
                  leading: IconTile(
                    m.change > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    tone: m.change > 0 ? Tone.good : Tone.warn,
                  ),
                  title: _reasonLabel(m.reason),
                  subtitle: [
                    if (m.by != null) '${m.by} · ',
                    formatDate(m.at),
                    ' ',
                    formatTime(m.at),
                    if (m.note != null) '\n${m.note}',
                  ].join(),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${m.change > 0 ? '+' : '-'}${context.num(m.change.abs())}',
                        style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: toneColors(context, m.change > 0 ? Tone.good : Tone.warn).fg),
                      ),
                      Text(
                        m.change > 0 ? context.tr('Added', 'थपियो') : context.tr('Taken out', 'निकालियो'),
                        style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  onTap: _billLink(m) == null ? null : () => context.push(_billLink(m)!),
                  chevron: _billLink(m) != null,
                ),
            ],
          ),
        if (failed != null) ...[
          const SizedBox(height: 12),
          ErrorView(error: failed.error!, onRetry: _reload),
        ],
        if (hasMore) ...[
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => setState(() => _pages++),
            child: Text(context.tr('Load more', 'अरू हेर्ने')),
          ),
        ],
      ],
    );
  }
}
