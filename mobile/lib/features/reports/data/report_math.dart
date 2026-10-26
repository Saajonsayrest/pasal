import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/utils/bs.dart';

/// How the sales chart groups the days: one bar per day, per week or per Nepali month.
enum ChartMode { day, week, month }

/// Sales and bills of one bar. [from] and [to] are AD dates, both days included.
class SalesBucket {
  SalesBucket({required this.from, required this.to, this.sales = 0, this.bills = 0});

  final String from;
  String to;
  int sales;
  int bills;
}

/// Up to 31 day bars. A longer range groups by week, and a very long one by month.
List<ChartMode> chartModes(int dayCount) => [
      if (dayCount <= 31) ChartMode.day,
      if ((dayCount / 7).ceil() <= 31) ChartMode.week,
      ChartMode.month,
    ];

/// Groups the days into bars. Weeks are counted from the first day of the range.
List<SalesBucket> salesBuckets(List<DayTotal> days, ChartMode mode) {
  final out = <SalesBucket>[];
  String? key;
  for (var i = 0; i < days.length; i++) {
    final d = days[i];
    final k = switch (mode) {
      ChartMode.day => d.date,
      ChartMode.week => '${i ~/ 7}',
      ChartMode.month => _bsMonthKey(d.date),
    };
    if (key == null || k != key) {
      out.add(SalesBucket(from: d.date, to: d.date));
      key = k;
    }
    final bucket = out.last;
    bucket.to = d.date;
    bucket.sales += d.sales;
    bucket.bills += d.bills;
  }
  return out;
}

String _bsMonthKey(String ad) {
  final b = adToBs(ad);
  return '${b.year}-${b.month}';
}

/// The day with the most sales. The first one wins a tie. Null when no day has sales.
DayTotal? bestDay(List<DayTotal> days) {
  DayTotal? best;
  for (final d in days) {
    if (d.sales > 0 && (best == null || d.sales > best.sales)) best = d;
  }
  return best;
}

/// The hours of the best-hours bars: 6am to 10pm.
List<HourTotal> bestHours(List<HourTotal> hours) => hours.where((h) => h.hour >= 6 && h.hour <= 22).toList();

/// Bills made outside the bar hours. They are counted, but not drawn.
int billsOutsideBestHours(List<HourTotal> hours) => hours.where((h) => h.hour < 6 || h.hour > 22).fold(0, (n, h) => n + h.bills);

/// The hour with the most sales over the whole day. Null when no hour has sales.
HourTotal? busiestHour(List<HourTotal> hours) {
  HourTotal? best;
  for (final h in hours) {
    if (h.sales > 0 && (best == null || h.sales > best.sales)) best = h;
  }
  return best;
}

/// Average bill in paisa, rounded half up. Whole numbers only.
int averageBill(int sales, int bills) => bills > 0 ? (sales * 2 + bills) ~/ (bills * 2) : 0;

/// A part of a whole, as a whole percent. 0 when the whole is 0.
int sharePercent(int part, int whole) => whole > 0 ? (part * 100 / whole).round() : 0;
