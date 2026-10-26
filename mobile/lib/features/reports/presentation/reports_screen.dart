import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/reports/data/range.dart';
import 'package:pasal_mobile/features/reports/data/reports_repository.dart';
import 'package:pasal_mobile/features/reports/presentation/range_picker.dart';
import 'package:pasal_mobile/features/reports/presentation/report_widgets.dart';

/// H1. The reports home: profit for the picked dates, the money to collect and to pay, and a link to each report.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateRange _range = rangeFor(RangePreset.month);

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(summaryProvider(_range));

    return PageScaffold(
      title: context.tr('Reports', 'रिपोर्टहरू'),
      onRefresh: () async => ref.invalidate(summaryProvider(_range)),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RangePicker(value: _range, onChanged: (r) => setState(() => _range = r)),
          const SizedBox(height: 16),
          AsyncBody(
            value: summary,
            onRetry: () => ref.invalidate(summaryProvider(_range)),
            data: (s) => _SummaryBlock(summary: s),
          ),
          const SizedBox(height: 20),
          SectionTitle(context.tr('All reports', 'सबै रिपोर्ट')),
          const SizedBox(height: 8),
          ListCard(
            children: [
              ListRow(
                leading: const IconTile(Icons.bar_chart_rounded),
                title: context.tr('Sales chart', 'बिक्री चार्ट'),
                subtitle: context.tr('Sales per day', 'दिनअनुसार बिक्री'),
                onTap: () => context.push('/reports/sales'),
              ),
              ListRow(
                leading: const IconTile(Icons.trending_up_rounded),
                title: context.tr('Top and slow items', 'धेरै र कम बिक्ने सामान'),
                subtitle: context.tr('Best and slow sellers', 'धेरै बिक्ने र नबिक्ने'),
                onTap: () => context.push('/reports/items'),
              ),
              ListRow(
                leading: const IconTile(Icons.hourglass_bottom_rounded, tone: Tone.warn),
                title: context.tr('Credit age', 'उधारोको उमेर'),
                subtitle: context.tr('How old the credit is', 'उधारो कति दिन पुरानो'),
                onTap: () => context.push('/reports/credit-age'),
              ),
              ListRow(
                leading: const IconTile(Icons.badge_rounded),
                title: context.tr('Staff sales', 'कर्मचारीको बिक्री'),
                subtitle: context.tr('Sales per staff', 'कर्मचारीअनुसार बिक्री'),
                onTap: () => context.push('/reports/staff'),
              ),
              ListRow(
                leading: const IconTile(Icons.download_rounded),
                title: context.tr('Export', 'निर्यात'),
                subtitle: context.tr('CSV files for each list', 'हरेक सूचीको CSV फाइल'),
                onTap: () => context.push('/reports/export'),
              ),
              ListRow(
                leading: const IconTile(Icons.receipt_long_rounded, tone: Tone.info),
                title: context.tr('VAT this month', 'यो महिनाको भ्याट'),
                subtitle: context.tr('VAT to pay', 'भ्याट तिर्ने हिसाब'),
                onTap: () => context.push('/vat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.summary});

  final Summary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          tone: s.profit < 0 ? Tone.bad : Tone.primary,
          child: StatBlock(
            large: true,
            label: context.tr('Profit', 'नाफा'),
            value: context.rs(s.profit),
            sub: context.tr('Sales minus VAT, goods and expenses', 'बिक्रीबाट भ्याट, सामान र खर्च घटाएपछि'),
          ),
        ),
        const SizedBox(height: 12),
        PCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KvRow(context.tr('Sales', 'बिक्री'), context.rs(s.salesTotal)),
              KvRow(context.tr('Minus VAT collected', 'घटाउने: संकलन गरेको भ्याट'), context.rs(s.vatCollected)),
              KvRow(context.tr('Minus cost of goods', 'घटाउने: सामानको लागत'), context.rs(s.costOfGoods)),
              KvRow(context.tr('Minus expenses', 'घटाउने: खर्च'), context.rs(s.expensesTotal)),
              KvRow(context.tr('Profit', 'नाफा'), context.rs(s.profit), total: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PCard(
          onTap: () => context.go('/items'),
          child: Row(
            children: [
              const IconTile(Icons.inventory_2_rounded, tone: Tone.good),
              const SizedBox(width: 14),
              Expanded(
                child: StatBlock(
                  label: context.tr('Stock value today', 'आजको स्टकको मूल्य'),
                  value: context.rs(s.stockValue),
                  sub: context.tr('At buying price', 'खरिद मूल्यमा'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PCard(
                onTap: () => context.go('/customers'),
                child: StatBlock(
                  label: context.tr('To collect', 'उठाउन बाँकी'),
                  value: context.rs(s.owedToUs),
                  sub: context.tr('From customers', 'ग्राहकबाट'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PCard(
                onTap: () => context.push('/suppliers'),
                child: StatBlock(
                  label: context.tr('We owe', 'हामीले तिर्न बाँकी'),
                  value: context.rs(s.weOwe),
                  sub: context.tr('To suppliers', 'डिलरलाई'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'Stock value, to collect and we owe are as of today, not only for the dates you picked.',
            'स्टकको मूल्य, उठाउन बाँकी र हामीले तिर्न बाँकी आजको हिसाबमा हो, छानेका मितिमा मात्र होइन।',
          ),
          style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
