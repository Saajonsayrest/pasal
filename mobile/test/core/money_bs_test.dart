import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/money.dart';

void main() {
  setUp(() {
    Lang.ne = false;
    Lang.bsDates = true;
  });

  group('money', () {
    test('shows rupees with Indian grouping and paisa only when needed', () {
      expect(rs(12400000), 'Rs 1,24,000');
      expect(rs(26633), 'Rs 266.33');
      expect(rs(100, paisa: true), 'Rs 1.00');
      expect(rs(-50000), '-Rs 500');
      expect(rs(null), 'Rs 0');
      expect(groupIndian(1234567), '12,34,567');
      expect(groupIndian(999), '999');
    });

    test('Nepali digits in Nepali mode', () {
      Lang.ne = true;
      expect(rs(12400000), 'Rs १,२४,०००');
    });

    test('turns typed text into whole paisa without float errors', () {
      expect(toPaisa('1,250.50'), 125050);
      expect(toPaisa('0.1'), 10);
      expect(toPaisa('19.99'), 1999);
      expect(toPaisa('Rs 5'), 500);
      expect(toPaisa(''), isNull);
      expect(toPaisa('1.234'), isNull);
      expect(toPaisa('abc'), isNull);
    });

    test('round trips and percent', () {
      expect(fromPaisa(125050), '1250.5');
      expect(fromPaisa(500), '5');
      expect(percentOf(10000, 13), 1300);
    });
  });

  group('Nepali calendar', () {
    test('matches the known dates', () {
      expect(bsToAd(2083, 7, 1), '2026-10-18');
      expect(adToBs('2026-10-26'), const Bs(2083, 7, 9));
      expect(bsToAd(2000, 1, 1), '1943-04-14');
    });

    test('gives the VAT month range', () {
      expect(daysInBsMonth(2083, 7), 30);
      expect(bsMonthRange(2083, 7), (from: '2026-10-18', to: '2026-11-16'));
      expect(periodLabel(2083, 7), '2083-07');
    });

    test('round trips every day of a year', () {
      for (var m = 1; m <= 12; m++) {
        for (var d = 1; d <= daysInBsMonth(2082, m); d++) {
          expect(adToBs(bsToAd(2082, m, d)), Bs(2082, m, d));
        }
      }
    });

    test('moves between months', () {
      expect(shiftMonth(2083, 1, -1), (year: 2082, month: 12));
      expect(shiftMonth(2083, 12, 1), (year: 2084, month: 1));
    });

    test('uses Nepal time for today', () {
      final now = DateTime.utc(2026, 10, 25, 20);
      expect(todayAd(now), '2026-10-26');
      expect(daysUntil('2026-10-27', now), 1);
      expect(adOfStamp('2026-10-25T20:00:00+00:00'), '2026-10-26');
    });

    test('formats dates and times', () {
      expect(formatBs('2026-10-26'), 'Kartik 9, 2083');
      expect(formatAd('2026-10-26'), '26 Oct 2026');
      expect(formatDate('2026-10-26'), 'Kartik 9, 2083');
      Lang.bsDates = false;
      expect(formatDate('2026-10-26'), '26 Oct 2026');
      expect(weekday('2026-10-26'), 'Monday');
      expect(formatTime('2026-10-26T07:26:03+00:00'), '1:11 PM');
    });

    test('refuses dates it cannot convert', () {
      expect(() => bsToAd(1999, 1, 1), throwsRangeError);
      expect(() => bsToAd(2083, 7, 31), throwsRangeError);
    });
  });
}
