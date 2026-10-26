import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/reports/data/range.dart';

// 2026-10-26 at 11:45 in Nepal is Kartik 9, 2083 (BS).
final _oct26 = DateTime.utc(2026, 10, 26, 6);

void main() {
  group('rangeFor', () {
    test('today is the shop day only', () {
      expect(rangeFor(RangePreset.today, now: _oct26), (from: '2026-10-26', to: '2026-10-26'));
    });

    test('last 7 days includes today', () {
      expect(rangeFor(RangePreset.week, now: _oct26), (from: '2026-10-20', to: '2026-10-26'));
    });

    test('this month starts on the first Nepali day and ends today', () {
      expect(rangeFor(RangePreset.month, now: _oct26), (from: '2026-10-18', to: '2026-10-26'));
    });

    test('last month is the whole Nepali month before (Ashoj 2083)', () {
      expect(rangeFor(RangePreset.lastMonth, now: _oct26), (from: '2026-09-17', to: '2026-10-17'));
    });

    test('last 3 months starts two Nepali months back (Bhadra 2083)', () {
      expect(rangeFor(RangePreset.quarter, now: _oct26), (from: '2026-08-17', to: '2026-10-26'));
    });

    test('last month wraps to the previous BS year in Baisakh', () {
      // 2026-04-20 is Baisakh 7, 2083. Chaitra 2082 runs 2026-03-15 to 2026-04-13.
      expect(rangeFor(RangePreset.lastMonth, now: DateTime.utc(2026, 4, 20, 6)), (from: '2026-03-15', to: '2026-04-13'));
    });

    test('uses the shop day, not the UTC day', () {
      // 2026-10-25 18:30 UTC is 2026-10-26 00:15 in Nepal.
      expect(rangeFor(RangePreset.today, now: DateTime.utc(2026, 10, 25, 18, 30)), (from: '2026-10-26', to: '2026-10-26'));
    });

    test('every fixed preset starts on or before its end', () {
      for (final preset in [RangePreset.today, RangePreset.week, RangePreset.month, RangePreset.lastMonth, RangePreset.quarter]) {
        final r = rangeFor(preset, now: _oct26);
        expect(r.from.compareTo(r.to) <= 0, isTrue, reason: preset.name);
      }
    });

    test('custom has no fixed dates', () {
      expect(() => rangeFor(RangePreset.custom, now: _oct26), throwsArgumentError);
    });
  });
}
