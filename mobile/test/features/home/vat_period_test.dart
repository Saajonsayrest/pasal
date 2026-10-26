import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/home/data/vat_period.dart';

void main() {
  // Kartik 1, 2083 is 18 Oct 2026. Kartik has 30 days, Ashoj has 31.
  test('on 26 Oct 2026 the VAT month is Ashoj, due 11 Nov, 16 days left', () {
    final p = nextVatPeriod(DateTime.utc(2026, 10, 26, 6));
    expect(p.year, 2083);
    expect(p.month, 6);
    expect(p.from, '2026-09-17');
    expect(p.to, '2026-10-17');
    expect(p.due, '2026-11-11');
    expect(p.daysLeft, 16);
  });

  test('after the due date passes the VAT month becomes Kartik', () {
    final p = nextVatPeriod(DateTime.utc(2026, 11, 15, 6));
    expect(p.month, 7);
    expect(p.from, '2026-10-18');
    expect(p.to, '2026-11-16');
    expect(p.due, '2026-12-11');
    expect(p.daysLeft, 26);
  });

  test('on the due date itself the previous month is still shown (0 days left)', () {
    final p = nextVatPeriod(DateTime.utc(2026, 11, 11, 6));
    expect(p.month, 6);
    expect(p.daysLeft, 0);
  });
}
