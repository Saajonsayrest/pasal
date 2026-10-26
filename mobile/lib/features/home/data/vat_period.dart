import 'package:pasal_mobile/core/utils/bs.dart';

/// VAT is due this many days after the last day of the period (VAT Act 2052, section 18).
const vatDueDays = 25;

/// One Nepali VAT month: its first and last AD day, the day the return is due and the days left.
class VatPeriod {
  const VatPeriod({
    required this.year,
    required this.month,
    required this.from,
    required this.to,
    required this.due,
    required this.daysLeft,
  });

  final int year;
  final int month;
  final String from;
  final String to;
  final String due;

  /// Negative when the due date has passed.
  final int daysLeft;
}

VatPeriod _period(int year, int month, DateTime now) {
  final range = bsMonthRange(year, month);
  final due = addDaysAd(range.to, vatDueDays);
  return VatPeriod(year: year, month: month, from: range.from, to: range.to, due: due, daysLeft: daysUntil(due, now));
}

/// The VAT month whose payment date is still ahead. That is the last Nepali month, until its due
/// date has passed. The current month is always at least 25 days from its due date.
VatPeriod nextVatPeriod([DateTime? now]) {
  final clock = now ?? DateTime.now();
  final today = todayBs(clock);
  final last = shiftMonth(today.year, today.month, -1);
  final previous = _period(last.year, last.month, clock);
  return previous.daysLeft >= 0 ? previous : _period(today.year, today.month, clock);
}
