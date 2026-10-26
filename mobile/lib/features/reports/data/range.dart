import 'package:pasal_mobile/core/utils/bs.dart';

/// A date range as AD "YYYY-MM-DD" strings. Both days are included.
typedef DateRange = ({String from, String to});

/// The preset chips of the range picker. `custom` takes its dates from the two date boxes.
enum RangePreset { today, week, month, lastMonth, quarter, custom }

/// The dates of a preset, counted in shop days (Nepal). Pass [now] to count from another moment.
///
///   today: today only
///   week: the last 7 days, today included
///   month: this Nepali month, from its first day to today
///   lastMonth: the whole Nepali month before this one
///   quarter: from the first day of the Nepali month two months back, to today
///
/// Port of web/src/lib/range.ts. [RangePreset.custom] has no fixed dates and throws.
DateRange rangeFor(RangePreset preset, {DateTime? now}) {
  final today = todayAd(now);
  final bs = todayBs(now);
  switch (preset) {
    case RangePreset.today:
      return (from: today, to: today);
    case RangePreset.week:
      return (from: addDaysAd(today, -6), to: today);
    case RangePreset.month:
      return (from: bsMonthRange(bs.year, bs.month).from, to: today);
    case RangePreset.lastMonth:
      {
        final prev = shiftMonth(bs.year, bs.month, -1);
        final last = bsMonthRange(prev.year, prev.month);
        return (from: last.from, to: last.to);
      }
    case RangePreset.quarter:
      {
        final start = shiftMonth(bs.year, bs.month, -2);
        return (from: bsMonthRange(start.year, start.month).from, to: today);
      }
    case RangePreset.custom:
      throw ArgumentError.value(preset, 'preset', 'A custom range has no fixed dates');
  }
}
