import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/features/suppliers/data/purchase_math.dart';
import 'package:pasal_mobile/features/suppliers/data/save_key.dart';

LedgerPurchase _bill(int id, String boughtAt, int balance) => LedgerPurchase(
      id: id,
      billNo: 'INV-$id',
      boughtAt: boughtAt,
      total: balance,
      paid: 0,
      balance: balance,
    );

void main() {
  group('typed amounts and quantities', () {
    test('optional money: empty is 0, text is paisa, junk is null', () {
      expect(optionalPaisa(''), 0);
      expect(optionalPaisa('  '), 0);
      expect(optionalPaisa('12.5'), 1250);
      expect(optionalPaisa('abc'), isNull);
    });

    test('quantity must be whole and from 1 to 1,000,000', () {
      expect(parseQuantity('1'), 1);
      expect(parseQuantity('1000000'), 1000000);
      expect(parseQuantity('0'), isNull);
      expect(parseQuantity('1000001'), isNull);
      expect(parseQuantity('1.5'), isNull);
      expect(parseQuantity(''), isNull);
    });

    test('unit cost is paisa from the rupee text', () {
      expect(parseUnitCost('100.50'), 10050);
      expect(parseUnitCost('100'), 10000);
      expect(parseUnitCost(''), isNull);
    });

    test('line total is quantity times unit cost, null when a part is missing', () {
      expect(lineTotalPaisa(100, 10000), 1000000);
      expect(lineTotalPaisa(null, 10000), isNull);
      expect(lineTotalPaisa(2, null), isNull);
    });
  });

  group('paying oldest bills first', () {
    final bills = [
      _bill(12, '2026-10-24T07:26:03.000000Z', 630000),
      _bill(11, '2026-10-01T07:26:03.000000Z', 500000),
    ];

    test('the oldest bill is paid first, then the next one', () {
      final steps = planOldestFirst(bills, 800000);
      expect(steps.map((s) => s.bill.id).toList(), [11, 12]);
      expect(steps.map((s) => s.take).toList(), [500000, 300000]);
    });

    test('a payment of everything clears every bill', () {
      final steps = planOldestFirst(bills, 1130000);
      expect(steps.fold<int>(0, (sum, s) => sum + s.take), 1130000);
    });

    test('nothing to pay gives no steps, and paid bills are skipped', () {
      expect(planOldestFirst(bills, 0), isEmpty);
      final paid = [_bill(1, '2026-01-01T00:00:00+00:00', 0), ...bills];
      expect(openBillsOldestFirst(paid).map((b) => b.id).toList(), [11, 12]);
    });
  });

  group('days and lookups', () {
    test('days ago is never negative', () {
      expect(daysAgo('2020-01-01T00:00:00+00:00'), greaterThan(0));
      expect(daysAgo('2999-01-01T00:00:00+00:00'), 0);
    });

    test('findFirst returns the first match or null', () {
      expect(findFirst([1, 2, 3], (x) => x > 1), 2);
      expect(findFirst([1, 2, 3], (x) => x > 5), isNull);
    });
  });

  group('SaveKey', () {
    test('the same body keeps the key, a changed body gets a new key', () {
      final key = SaveKey();
      final first = key.forBody('{"a":1}');
      expect(key.forBody('{"a":1}'), first);
      expect(key.forBody('{"a":2}'), isNot(first));
    });

    test('a save that went through gets a new key next time', () {
      final key = SaveKey();
      final first = key.forBody('{"a":1}');
      key.reset();
      expect(key.forBody('{"a":1}'), isNot(first));
    });
  });
}
