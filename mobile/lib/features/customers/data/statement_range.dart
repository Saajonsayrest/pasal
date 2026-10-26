import 'package:pasal_mobile/core/utils/bs.dart';

enum StatementPreset { month, last, three, year, all }

/// AD days (Nepal, both included) for a statement preset. [earliest] is the first day with any record,
/// used by [StatementPreset.all]. Pass [now] to count from another moment.
({String from, String to}) statementRange(StatementPreset preset, {required String earliest, DateTime? now}) {
  final today = todayAd(now);
  final bs = todayBs(now);
  switch (preset) {
    case StatementPreset.month:
      return (from: bsMonthRange(bs.year, bs.month).from, to: today);
    case StatementPreset.last:
      final prev = shiftMonth(bs.year, bs.month, -1);
      return bsMonthRange(prev.year, prev.month);
    case StatementPreset.three:
      final start = shiftMonth(bs.year, bs.month, -2);
      return (from: bsMonthRange(start.year, start.month).from, to: today);
    case StatementPreset.year:
      return (from: bsToAd(bs.year, 1, 1), to: today);
    case StatementPreset.all:
      return (from: earliest, to: today);
  }
}
