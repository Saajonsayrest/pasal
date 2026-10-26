import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/reports/data/range.dart';
import 'package:pasal_mobile/features/reports/data/report_math.dart';
import 'package:pasal_mobile/features/reports/data/reports_repository.dart';
import 'package:pasal_mobile/features/reports/presentation/range_picker.dart';
import 'package:pasal_mobile/features/reports/presentation/report_widgets.dart';

/// H5. Sales per staff member for the picked dates, highest first.
class StaffSalesScreen extends ConsumerStatefulWidget {
  const StaffSalesScreen({super.key});

  @override
  ConsumerState<StaffSalesScreen> createState() => _StaffSalesScreenState();
}

class _StaffSalesScreenState extends ConsumerState<StaffSalesScreen> {
  DateRange _range = rangeFor(RangePreset.month);

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffSalesProvider(_range));

    return PageScaffold(
      title: context.tr('Staff sales', 'कर्मचारीको बिक्री'),
      onRefresh: () async => ref.invalidate(staffSalesProvider(_range)),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RangePicker(value: _range, onChanged: (r) => setState(() => _range = r)),
          const SizedBox(height: 16),
          AsyncBody(
            value: staff,
            onRetry: () => ref.invalidate(staffSalesProvider(_range)),
            data: _content,
          ),
        ],
      ),
    );
  }

  Widget _content(List<StaffSales> rows) {
    if (rows.isEmpty) {
      return SizedBox(
        height: 320,
        child: EmptyState(
          icon: Icons.badge_rounded,
          title: context.tr('No sales in these dates', 'यो मितिमा बिक्री छैन'),
          text: context.tr('Pick other dates above.', 'माथि अर्को मिति छान्नुहोस्।'),
        ),
      );
    }
    final totalSales = rows.fold<int>(0, (n, r) => n + r.sales);
    final totalBills = rows.fold<int>(0, (n, r) => n + r.bills);
    final totalDiscount = rows.fold<int>(0, (n, r) => n + r.discount);
    final peak = rows.fold<int>(1, (m, r) => math.max(m, r.sales));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          tone: Tone.neutral,
          child: StatBlock(
            large: true,
            label: context.tr('Total sales', 'जम्मा बिक्री'),
            value: context.rs(totalSales),
            sub: context.tr('${context.num(totalBills)} bills', '${context.num(totalBills)} बिल'),
          ),
        ),
        const SizedBox(height: 12),
        PCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KvRow(context.tr('Average bill', 'औसत बिल'), context.rs(averageBill(totalSales, totalBills))),
              KvRow(context.tr('Discount given', 'दिएको छुट'), context.rs(totalDiscount)),
            ],
          ),
        ),
        for (final r in rows) ...[
          const SizedBox(height: 12),
          _StaffCard(row: r, totalSales: totalSales, peak: peak),
        ],
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.row, required this.totalSales, required this.peak});

  final StaffSales row;
  final int totalSales;
  final int peak;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final share = sharePercent(r.sales, totalSales);
    return PCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AvatarCircle(r.name, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text(r.name, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              Text(context.rs(r.sales), style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (r.sales / peak).clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('${context.num(share)}% of total sales', 'कुल बिक्रीको ${context.num(share)}%'),
            style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          KvRow(context.tr('Bills', 'बिल'), context.num(r.bills)),
          KvRow(context.tr('Average bill', 'औसत बिल'), context.rs(averageBill(r.sales, r.bills))),
          KvRow(context.tr('Discount given', 'दिएको छुट'), context.rs(r.discount)),
        ],
      ),
    );
  }
}
