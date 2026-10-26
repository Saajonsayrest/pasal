import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/reports/data/range.dart';
import 'package:pasal_mobile/features/reports/data/report_math.dart';
import 'package:pasal_mobile/features/reports/data/reports_repository.dart';
import 'package:pasal_mobile/features/reports/presentation/range_picker.dart';
import 'package:pasal_mobile/features/reports/presentation/report_widgets.dart';

/// H2. Sales as bars: per day, week or month, the best day and the busiest hours.
class SalesChartScreen extends ConsumerStatefulWidget {
  const SalesChartScreen({super.key});

  @override
  ConsumerState<SalesChartScreen> createState() => _SalesChartScreenState();
}

class _SalesChartScreenState extends ConsumerState<SalesChartScreen> {
  DateRange _range = rangeFor(RangePreset.month);
  ChartMode _mode = ChartMode.day;
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final daily = ref.watch(dailyReportProvider(_range));

    return PageScaffold(
      title: context.tr('Sales chart', 'बिक्री चार्ट'),
      onRefresh: () async => ref.invalidate(dailyReportProvider(_range)),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RangePicker(
            value: _range,
            onChanged: (r) {
              setState(() {
                _range = r;
                _picked = null;
              });
            },
          ),
          const SizedBox(height: 16),
          AsyncBody(
            value: daily,
            onRetry: () => ref.invalidate(dailyReportProvider(_range)),
            data: _content,
          ),
        ],
      ),
    );
  }

  Widget _content(DailyReport report) {
    if (report.bills == 0) {
      return SizedBox(
        height: 320,
        child: EmptyState(
          icon: Icons.bar_chart_rounded,
          title: context.tr('No sales in these dates', 'यो मितिमा बिक्री छैन'),
          text: context.tr('Pick other dates above.', 'माथि अर्को मिति छान्नुहोस्।'),
        ),
      );
    }

    final modes = chartModes(report.days.length);
    final mode = modes.contains(_mode) ? _mode : modes.first;
    final buckets = salesBuckets(report.days, mode);
    final picked = _picked;
    final sel = (picked != null && picked < buckets.length) ? picked : buckets.length - 1;
    final shown = buckets[sel];
    final best = bestDay(report.days);
    final hours = bestHours(report.hours);
    final busiest = busiestHour(report.hours);
    final outside = billsOutsideBestHours(report.hours);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardTitle(
                _titleOf(context, mode),
                trailing: Text(
                  context.tr('${context.num(report.bills)} bills', '${context.num(report.bills)} बिल'),
                  style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ),
              if (modes.length > 1)
                Seg<ChartMode>(
                  value: mode,
                  options: {for (final m in modes) m: _modeName(context, m)},
                  onChanged: (m) => setState(() {
                    _mode = m;
                    _picked = null;
                  }),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.rs(report.total),
                      style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(context.tr('Total', 'जम्मा'), style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 12),
              BarChart(
                height: 170,
                selected: sel,
                onSelected: (i) => setState(() => _picked = i),
                items: [for (final b in buckets) BarChartItem(label: _bucketLabel(b, mode), value: b.sales)],
              ),
              const SizedBox(height: 6),
              Text(
                mode == ChartMode.month
                    ? context.tr('Numbers are Nepali months (1 to 12). Tap a bar.', 'अंक नेपाली महिना हुन् (१ देखि १२)। बारमा थिच्नुहोस्।')
                    : context.tr('Numbers are days of the month (AD). Tap a bar.', 'अंक महिनाका दिन हुन् (AD)। बारमा थिच्नुहोस्।'),
                style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              KvRow(
                mode == ChartMode.day ? context.tr('Day', 'दिन') : context.tr('Period', 'अवधि'),
                _periodText(context, shown, mode),
              ),
              KvRow(context.tr('Total', 'जम्मा'), context.rs(shown.sales)),
              KvRow(context.tr('Bills', 'बिल'), context.num(shown.bills)),
              KvRow(context.tr('Average per bill', 'औसत बिल'), context.rs(averageBill(shown.sales, shown.bills))),
            ],
          ),
        ),
        if (best != null) ...[
          const SizedBox(height: 12),
          PCard(
            child: Row(
              children: [
                const IconTile(Icons.emoji_events_rounded, tone: Tone.good),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('Best day', 'सबैभन्दा राम्रो दिन'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        '${formatDate(best.date)} · ${formatDateSub(best.date)}',
                        style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(context.rs(best.sales), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        PCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardTitle(
                context.tr('Best hours', 'सबैभन्दा बढी बिक्री हुने समय'),
                trailing: Text(
                  context.tr('6am to 10pm', 'बिहान ६ देखि राति १० सम्म'),
                  style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ),
              BarChart(
                height: 120,
                items: [for (final h in hours) BarChartItem(label: _hourLabel(h.hour), value: h.sales)],
                selected: busiest == null ? null : hours.indexWhere((h) => h.hour == busiest.hour),
              ),
              if (busiest != null) ...[
                const SizedBox(height: 10),
                Text(context.tr('Busiest: ${_hourText(context, busiest.hour)}', 'सबैभन्दा व्यस्त: ${_hourText(context, busiest.hour)}')),
              ],
              if (outside > 0) ...[
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'Bills outside 6am to 10pm: ${context.num(outside)}. They are not in the bars.',
                    'बिहान ६ अघि वा राति १० पछिका बिल: ${context.num(outside)}। ती बारमा छैनन्।',
                  ),
                  style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _titleOf(BuildContext context, ChartMode mode) => switch (mode) {
        ChartMode.day => context.tr('Sales per day', 'दिनअनुसार बिक्री'),
        ChartMode.week => context.tr('Sales per week', 'हप्ताअनुसार बिक्री'),
        ChartMode.month => context.tr('Sales per month', 'महिनाअनुसार बिक्री'),
      };

  String _modeName(BuildContext context, ChartMode mode) => switch (mode) {
        ChartMode.day => context.tr('Day', 'दिन'),
        ChartMode.week => context.tr('Week', 'हप्ता'),
        ChartMode.month => context.tr('Month', 'महिना'),
      };

  /// The day of the month for day and week bars, the Nepali month number for month bars.
  String _bucketLabel(SalesBucket b, ChartMode mode) {
    if (mode == ChartMode.month) return digits(adToBs(b.from).month);
    return digits(int.parse(b.from.substring(8)));
  }

  String _periodText(BuildContext context, SalesBucket b, ChartMode mode) {
    if (mode == ChartMode.day) return formatDate(b.from);
    if (b.from == b.to) return formatDate(b.from);
    return context.tr('${formatDate(b.from)} to ${formatDate(b.to)}', '${formatDate(b.from)} देखि ${formatDate(b.to)} सम्म');
  }

  String _hourLabel(int hour) => digits(hour % 12 == 0 ? 12 : hour % 12);

  String _hourText(BuildContext context, int hour) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return context.tr('$h12${hour < 12 ? 'am' : 'pm'}', '${hour < 12 ? 'बिहान' : 'बेलुका'} ${digits(h12)} बजे');
  }
}
