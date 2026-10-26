import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/reports/data/range.dart';
import 'package:pasal_mobile/features/reports/data/reports_repository.dart';
import 'package:pasal_mobile/features/reports/presentation/range_picker.dart';

enum _Tab { top, slow }

enum _Sort { money, quantity }

/// H3. The best sellers (by money or by quantity) and the items in stock that sell the least.
class TopItemsScreen extends ConsumerStatefulWidget {
  const TopItemsScreen({super.key});

  @override
  ConsumerState<TopItemsScreen> createState() => _TopItemsScreenState();
}

class _TopItemsScreenState extends ConsumerState<TopItemsScreen> {
  DateRange _range = rangeFor(RangePreset.month);
  _Tab _tab = _Tab.top;
  _Sort _sort = _Sort.money;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsReportProvider(_range));

    return PageScaffold(
      title: context.tr('Top and slow items', 'धेरै र कम बिक्ने सामान'),
      onRefresh: () async => ref.invalidate(itemsReportProvider(_range)),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RangePicker(value: _range, onChanged: (r) => setState(() => _range = r)),
          const SizedBox(height: 16),
          Seg<_Tab>(
            value: _tab,
            options: {
              _Tab.top: context.tr('Top sellers', 'धेरै बिक्ने'),
              _Tab.slow: context.tr('Slow items', 'कम बिक्ने'),
            },
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 12),
          AsyncBody(
            value: items,
            onRetry: () => ref.invalidate(itemsReportProvider(_range)),
            data: (r) => _tab == _Tab.top ? _topBody(r) : _slowBody(r),
          ),
        ],
      ),
    );
  }

  Widget _topBody(ItemsReport report) {
    final rows = [...report.top]
      ..sort((a, b) => _sort == _Sort.money ? b.revenue.compareTo(a.revenue) : b.quantity.compareTo(a.quantity));
    if (rows.isEmpty) {
      return _empty(Icons.trending_up_rounded, context.tr('No sales in these dates', 'यो मितिमा बिक्री छैन'), context.tr('Pick other dates above.', 'माथि अर्को मिति छान्नुहोस्।'));
    }
    final peak = rows.fold<int>(1, (m, r) => math.max(m, _sort == _Sort.money ? r.revenue : r.quantity));
    final topTotal = report.top.fold<int>(0, (n, r) => n + r.revenue);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChipsRow<_Sort>(
          value: _sort,
          onChanged: (s) => setState(() => _sort = s),
          options: {
            _Sort.money: context.tr('By money', 'रकमअनुसार'),
            _Sort.quantity: context.tr('By quantity', 'संख्याअनुसार'),
          },
        ),
        const SizedBox(height: 12),
        PCard(
          child: StatBlock(
            label: context.tr('Top ${context.num(rows.length)} items sold', 'शीर्ष ${context.num(rows.length)} सामानको बिक्री'),
            value: context.rs(topTotal),
            sub: context.tr('Sales from these items in the dates you picked', 'छानेका मितिमा यी सामानको बिक्री'),
          ),
        ),
        const SizedBox(height: 12),
        ListCard(
          children: [
            for (var i = 0; i < rows.length; i++)
              _RankRow(
                rank: context.num(i + 1),
                name: rows[i].name,
                detail: context.tr(
                  '${context.num(rows[i].quantity)} ${rows[i].unit} sold',
                  '${context.num(rows[i].quantity)} ${rows[i].unit} बिक्यो',
                ),
                amount: context.rs(rows[i].revenue),
                fraction: (_sort == _Sort.money ? rows[i].revenue : rows[i].quantity) / peak,
              ),
          ],
        ),
      ],
    );
  }

  Widget _slowBody(ItemsReport report) {
    final slow = report.slow;
    if (slow.isEmpty) {
      return _empty(Icons.inventory_2_rounded, context.tr('No stock to check', 'जाँच गर्ने स्टक छैन'), context.tr('Items in stock show here.', 'स्टकमा भएका सामान यहाँ देखिन्छन्।'));
    }
    final stuck = slow.fold<int>(0, (n, r) => n + r.stockValue);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCard(
          child: StatBlock(
            label: context.tr('Stock value stuck', 'अड्किएको स्टकको मूल्य'),
            value: context.rs(stuck),
            sub: context.tr(
              '${context.num(slow.length)} items in stock that sold the least',
              'कम बिक्ने ${context.num(slow.length)} सामान स्टकमा छन्',
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListCard(
          children: [
            for (final r in slow)
              ListRow(
                leading: const IconTile(Icons.inventory_2_rounded),
                title: r.name,
                subtitle: context.tr(
                  '${context.num(r.inStock)} ${r.unit} left · ${context.num(r.sold)} sold',
                  '${context.num(r.inStock)} ${r.unit} बाँकी · ${context.num(r.sold)} बिक्यो',
                ),
                chevron: false,
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(context.rs(r.stockValue), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    if (r.sold == 0) ...[
                      const SizedBox(height: 4),
                      PBadge(context.tr('Not sold', 'बिक्री भएन'), tone: Tone.warn),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _empty(IconData icon, String title, String text) => SizedBox(
        height: 320,
        child: EmptyState(icon: icon, title: title, text: text),
      );
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.name, required this.detail, required this.amount, required this.fraction});

  final String rank;
  final String name;
  final String detail;
  final String amount;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(rank, textAlign: TextAlign.center, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(detail, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: fraction.clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(99),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(amount, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
