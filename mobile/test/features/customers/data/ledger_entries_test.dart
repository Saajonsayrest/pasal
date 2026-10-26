import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/features/customers/data/ledger_entries.dart';
import 'package:pasal_mobile/features/customers/data/statement.dart';
import 'package:pasal_mobile/features/customers/data/statement_range.dart';

import '../customer_fixtures.dart';

CustomerLedger _ledger({List<Json>? sales, List<Json>? payments}) {
  final base = ledgerJson();
  return CustomerLedger.fromJson({
    ...base,
    'sales': sales ?? base['sales'],
    'payments': payments ?? base['payments'],
  });
}

CustomerLedger _sample() => CustomerLedger.fromJson(ledgerJson());

Json _sale(int id, String at, int total, {int returned = 0, int balance = 0, String? cancelledAt}) => {
      'id': id,
      'bill_no': 'S-00$id',
      'sold_at': at,
      'total': total,
      'returned_total': returned,
      'paid': 0,
      'balance': balance,
      'cancelled_at': cancelledAt,
    };

Json _payment(int id, String direction, int amount, {int? saleId, String at = '2026-10-10T04:00:00+00:00', String method = 'esewa'}) => {
      'id': id,
      'direction': direction,
      'sale_id': saleId,
      'purchase_id': null,
      'amount': amount,
      'method': method,
      'paid_at': at,
      'party': null,
    };

void main() {
  group('customerEntries', () {
    test('turns bills and payments into lines, leaving out supplier payments', () {
      final entries = customerEntries(_sample());
      expect(entries.map((e) => e.key), ['sale-31', 'sale-32', 'pay-9']);
      expect(entries[2].kind, EntryKind.received);
      expect(entries[2].billNo, 'S-0031');
      expect(entries[2].delta, -500000);
    });

    test('a refund adds to what the customer owes and an outgoing payment is skipped', () {
      final entries = customerEntries(_ledger(sales: [], payments: [_payment(1, 'refund', 20000), _payment(2, 'out', 99900)]));
      expect(entries.length, 1);
      expect(entries.single.kind, EntryKind.refund);
      expect(entries.single.delta, 20000);
    });

    test('a bill counts after returns in the statement amount', () {
      final ledger = _ledger(
        sales: [_sale(5, '2026-10-02T04:00:00+00:00', 10000, returned: 2500, balance: 7500)],
        payments: [],
      );
      final bill = customerEntries(ledger).single;
      expect(bill.amount, 10000);
      expect(bill.delta, 7500);
      expect(bill.netAmount, 7500);
    });

    test('earliestDay is the first Nepal day with a record', () {
      expect(earliestDay(_sample()), '2026-10-01');
    });
  });

  group('buildStatement', () {
    test('runs the balance from the opening amount and adds up the period', () {
      final statement = buildStatement(_sample(), from: '2026-10-01', to: '2026-10-31');
      expect(statement.opening, 0);
      expect(statement.rows.map((r) => r.balance), [1130000, 630000, 1500000]);
      expect(statement.totalGiven, 2000000);
      expect(statement.totalReceived, 500000);
      expect(statement.closing, 1500000);
      expect(statement.truncated, isFalse);
    });

    test('lines before the period form the opening balance', () {
      final statement = buildStatement(_sample(), from: '2026-10-10', to: '2026-10-31');
      expect(statement.opening, 630000);
      expect(statement.rows.map((r) => r.entry.key), ['sale-32']);
      expect(statement.closing, 1500000);
    });

    test('a period with no lines closes at the opening balance', () {
      final statement = buildStatement(_sample(), from: '2026-11-01', to: '2026-11-30');
      expect(statement.rows, isEmpty);
      expect(statement.opening, 1500000);
      expect(statement.closing, 1500000);
    });

    test('is marked truncated when the server sent the full 200 records', () {
      final many = [for (var i = 1; i <= 200; i++) _sale(i, '2026-10-02T04:00:00+00:00', 100, balance: 100)];
      final statement = buildStatement(_ledger(sales: many, payments: []), from: '2026-10-01', to: '2026-10-31');
      expect(statement.truncated, isTrue);
    });
  });

  group('statementRange', () {
    // Kartik 9, 2083 (AD 26 Oct 2026). Kartik 1 is AD 18 Oct 2026, as in lib/core/utils/bs.dart.
    final now = DateTime.utc(2026, 10, 26, 6);

    test('this month starts on the first day of the Nepali month and ends today', () {
      final r = statementRange(StatementPreset.month, earliest: '2026-01-01', now: now);
      expect(r.from, '2026-10-18');
      expect(r.to, '2026-10-26');
    });

    test('last month is the whole Nepali month before', () {
      final r = statementRange(StatementPreset.last, earliest: '2026-01-01', now: now);
      expect(r.from, bsToAd(2083, 6, 1));
      expect(r.to, '2026-10-17');
    });

    test('last 3 months starts two Nepali months back', () {
      final r = statementRange(StatementPreset.three, earliest: '2026-01-01', now: now);
      expect(r.from, bsMonthRange(2083, 5).from);
      expect(r.to, '2026-10-26');
    });

    test('this year starts on Baisakh 1', () {
      final r = statementRange(StatementPreset.year, earliest: '2026-01-01', now: now);
      expect(r.from, bsToAd(2083, 1, 1));
    });

    test('all starts on the earliest record', () {
      final r = statementRange(StatementPreset.all, earliest: '2026-03-03', now: now);
      expect(r.from, '2026-03-03');
      expect(r.to, '2026-10-26');
    });
  });
}
