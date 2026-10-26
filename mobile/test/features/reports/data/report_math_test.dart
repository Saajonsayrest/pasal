import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/features/reports/data/report_math.dart';

DayTotal _day(String date, int sales, [int bills = 1]) => DayTotal(date: date, bills: bills, sales: sales);

HourTotal _hour(int hour, int sales, [int bills = 1]) => HourTotal(hour: hour, bills: bills, sales: sales);

void main() {
  group('chartModes', () {
    test('short ranges offer day, week and month', () {
      expect(chartModes(10), [ChartMode.day, ChartMode.week, ChartMode.month]);
    });

    test('31 days is the last range with day bars', () {
      expect(chartModes(31), [ChartMode.day, ChartMode.week, ChartMode.month]);
      expect(chartModes(32), [ChartMode.week, ChartMode.month]);
    });

    test('a very long range offers only month bars', () {
      expect(chartModes(300), [ChartMode.month]);
    });
  });

  group('salesBuckets', () {
    final days = [
      _day('2026-10-17', 500000, 2),
      _day('2026-10-18', 1200000, 3),
      _day('2026-10-19', 0, 0),
    ];

    test('day mode gives one bar per day', () {
      final buckets = salesBuckets(days, ChartMode.day);
      expect(buckets.length, 3);
      expect(buckets[1].from, '2026-10-18');
      expect(buckets[1].sales, 1200000);
      expect(buckets[1].bills, 3);
    });

    test('week mode groups every 7 days from the start of the range', () {
      final nine = [for (var i = 0; i < 9; i++) _day('2026-10-${(17 + i).toString().padLeft(2, '0')}', 100)];
      final buckets = salesBuckets(nine, ChartMode.week);
      expect(buckets.length, 2);
      expect(buckets[0].from, '2026-10-17');
      expect(buckets[0].to, '2026-10-23');
      expect(buckets[0].sales, 700);
      expect(buckets[1].from, '2026-10-24');
      expect(buckets[1].to, '2026-10-25');
      expect(buckets[1].sales, 200);
    });

    test('month mode groups by Nepali month', () {
      // 2026-10-30 is Kartik 13. 2026-11-17 is Mangsir 1 2083.
      final across = [_day('2026-10-30', 100), _day('2026-11-17', 200), _day('2026-11-18', 300)];
      final buckets = salesBuckets(across, ChartMode.month);
      expect(buckets.length, 2);
      expect(buckets[0].sales, 100);
      expect(buckets[1].from, '2026-11-17');
      expect(buckets[1].to, '2026-11-18');
      expect(buckets[1].sales, 500);
    });
  });

  test('bestDay is the top day with sales, and the first one wins a tie', () {
    expect(bestDay([_day('2026-10-17', 500), _day('2026-10-18', 900), _day('2026-10-19', 900)])?.date, '2026-10-18');
    expect(bestDay([_day('2026-10-17', 0)]), isNull);
  });

  test('best hours are 6am to 10pm, and bills outside them are counted', () {
    final hours = [_hour(5, 0, 1), _hour(6, 100, 2), _hour(22, 50, 3), _hour(23, 0, 4)];
    expect(bestHours(hours).map((h) => h.hour), [6, 22]);
    expect(billsOutsideBestHours(hours), 5);
  });

  test('busiestHour ignores hours without sales', () {
    expect(busiestHour([_hour(9, 0), _hour(17, 300), _hour(18, 300)])?.hour, 17);
    expect(busiestHour([_hour(9, 0)]), isNull);
  });

  test('averageBill rounds half up in whole paisa', () {
    expect(averageBill(10, 4), 3);
    expect(averageBill(9, 4), 2);
    expect(averageBill(0, 0), 0);
  });

  test('sharePercent is a whole percent of the whole', () {
    expect(sharePercent(1, 3), 33);
    expect(sharePercent(2, 3), 67);
    expect(sharePercent(1, 0), 0);
  });
}
