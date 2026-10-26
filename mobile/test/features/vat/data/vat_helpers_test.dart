import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/features/vat/data/vat_helpers.dart';

import '../vat_fixtures.dart';

VatFiling _filing({required String period, int payable = 520000, int paid = 0, String? filedOn, String periodTo = '2026-10-17'}) =>
    VatFiling.fromJson(filingJson(id: 1, period: period, payable: payable, paid: paid, filedOn: filedOn, periodTo: periodTo));

void main() {
  group('periods', () {
    test('parsePeriod reads year and month', () {
      final p = parsePeriod('2083-07');
      expect(p?.year, 2083);
      expect(p?.month, 7);
    });

    test('parsePeriod rejects other labels and months out of range', () {
      expect(parsePeriod('2082/83'), isNull);
      expect(parsePeriod('2083-13'), isNull);
      expect(parsePeriod('2083-00'), isNull);
      expect(parsePeriod('Ashar 2082'), isNull);
    });

    test('periodTitle shows the month name, and keeps other labels', () {
      expect(periodTitle('2083-07'), 'Kartik 2083');
      expect(periodTitle('2082/83'), '2082/83');
    });
  });

  group('due date', () {
    test('is the last day of the period plus 25 days (docs example)', () {
      expect(dueDate('2026-11-16'), '2026-12-11');
    });

    test('counts whole days from today (Nepal date)', () {
      // 2026-11-01 00:00 UTC is 05:45 in Nepal on the same day.
      expect(dueInDays('2026-11-16', DateTime.utc(2026, 11, 1)), 40);
    });

    test('is negative after the due date', () {
      expect(dueInDays('2026-11-16', DateTime.utc(2026, 12, 20)), -9);
    });
  });

  group('filing money', () {
    test('remainingToPay subtracts what was paid and never goes below zero', () {
      expect(remainingToPay(_filing(period: '2083-05', payable: 520000, paid: 100000)), 420000);
      expect(remainingToPay(_filing(period: '2083-05', payable: 520000, paid: 600000)), 0);
    });

    test('filingStatus is not filed without a filed date', () {
      expect(filingStatus(_filing(period: '2083-05')), FilingStatus.notFiled);
    });

    test('filingStatus is paid once the payable amount is paid', () {
      expect(filingStatus(_filing(period: '2083-05', filedOn: '2026-11-01', paid: 520000)), FilingStatus.paid);
    });

    test('filingStatus is filed when filed but not fully paid', () {
      expect(filingStatus(_filing(period: '2083-05', filedOn: '2026-11-01', paid: 1000)), FilingStatus.filed);
    });

    test('filingStatus is filed, not paid, for a zero payable return', () {
      expect(filingStatus(_filing(period: '2083-05', payable: 0, filedOn: '2026-11-01')), FilingStatus.filed);
    });

    test('stillToPay adds the unpaid part of every row', () {
      final rows = [
        _filing(period: '2083-06', payable: 520000, paid: 100000),
        _filing(period: '2083-05', payable: 300000),
        _filing(period: '2083-04', payable: 1000, paid: 5000),
      ];
      expect(stillToPay(rows), 420000 + 300000);
    });

    test('oldestUnpaid is the last unpaid row, because rows come newest first', () {
      final rows = [
        _filing(period: '2083-06', payable: 100),
        _filing(period: '2083-05', payable: 200),
        _filing(period: '2083-04', payable: 300, paid: 300),
      ];
      expect(oldestUnpaid(rows)?.period, '2083-05');
    });

    test('oldestUnpaid is null when nothing is owed', () {
      expect(oldestUnpaid([_filing(period: '2083-04', payable: 300, paid: 300)]), isNull);
    });

    test('filingForPeriod finds a saved month or returns null', () {
      final rows = [_filing(period: '2083-06'), _filing(period: '2083-05')];
      expect(filingForPeriod(rows, '2083-05')?.period, '2083-05');
      expect(filingForPeriod(rows, '2083-01'), isNull);
    });
  });

  group('errorText', () {
    test('is null without an error', () {
      expect(errorText(null), isNull);
    });

    test('is the general message when there are no field errors', () {
      expect(errorText(ApiException(500, 'Something went wrong.')), 'Something went wrong.');
    });

    test('is the first field message that is not shown inline', () {
      final e = ApiException(422, 'Invalid', errors: {
        'paid_amount': ['Too much paid.'],
        'receipt_no': ['Receipt is used.'],
      });
      expect(errorText(e, shown: ['paid_amount']), 'Receipt is used.');
    });

    test('is null when every message is shown inline', () {
      final e = ApiException(422, 'Invalid', errors: {
        'paid_amount': ['Too much paid.'],
      });
      expect(errorText(e, shown: ['paid_amount']), isNull);
    });
  });

  group('plainAmount', () {
    test('groups the rupees in the Indian way and keeps two decimals', () {
      expect(plainAmount(124000050), '12,40,000.50');
      expect(plainAmount(0), '0.00');
      expect(plainAmount(5), '0.05');
    });

    test('keeps the minus sign', () {
      expect(plainAmount(-5), '-0.05');
      expect(plainAmount(-124000050), '-12,40,000.50');
    });

    test('has no grouping when asked (CSV)', () {
      expect(plainAmount(124000050, grouped: false), '1240000.50');
    });
  });

  group('blankToNull', () {
    test('turns empty or spaces into null and trims the rest', () {
      expect(blankToNull('   '), isNull);
      expect(blankToNull(' R-1 '), 'R-1');
    });
  });

  group('RequestKey', () {
    test('keeps the same key for the same inputs (a retry)', () {
      final key = RequestKey();
      final first = key.forInputs(('2083-07', '2026-10-17', 0));
      expect(key.forInputs(('2083-07', '2026-10-17', 0)), first);
      expect(first.length, 36);
    });

    test('makes a new key when the inputs change', () {
      final key = RequestKey();
      final first = key.forInputs({'paid': 1});
      expect(key.forInputs({'paid': 2}), isNot(first));
    });

    test('makes a new key after reset, even for the same inputs', () {
      final key = RequestKey();
      final first = key.forInputs({'paid': 1});
      key.reset();
      expect(key.forInputs({'paid': 1}), isNot(first));
    });
  });

  group('book totals', () {
    test('salesTotals adds taxable, VAT, exempt and total', () {
      final sales = [
        Sale.fromJson(saleJson(id: 1, billNo: 'S-1', total: 11300, taxable: 10000, vat: 1300)),
        Sale.fromJson(saleJson(id: 2, billNo: 'S-2', total: 2000, taxable: 0, vat: 0, exempt: 2000)),
      ];
      final t = salesTotals(sales);
      expect(t.taxable, 10000);
      expect(t.vat, 1300);
      expect(t.exempt, 2000);
      expect(t.total, 13300);
    });

    test('purchaseTotals takes the taxable part as the total without VAT', () {
      final purchases = [Purchase.fromJson(purchaseJson(id: 1, billNo: 'INV-1', total: 1130000, vat: 130000))];
      final t = purchaseTotals(purchases);
      expect(t.taxable, 1000000);
      expect(t.vat, 130000);
      expect(t.total, 1130000);
    });
  });
}
