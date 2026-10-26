import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/customers/data/allocation.dart';

const _bills = [
  OpenBill(id: 3, billNo: 'S-0412', balance: 124000, soldAt: '2026-10-26T07:26:03+00:00'),
  OpenBill(id: 1, billNo: 'S-0301', balance: 300000, soldAt: '2026-09-18T04:00:00+00:00'),
  OpenBill(id: 2, billNo: 'S-0377', balance: 210000, soldAt: '2026-10-14T04:00:00+00:00'),
  OpenBill(id: 4, billNo: 'S-0400', balance: 0, soldAt: '2026-09-01T04:00:00+00:00'),
];

void main() {
  group('allocateOldestFirst', () {
    test('pays the oldest bill first and skips bills with no balance', () {
      final result = allocateOldestFirst(_bills, 400000);
      expect(result.allocations.map((a) => a.bill.billNo), ['S-0301', 'S-0377']);
      expect(result.allocations.map((a) => a.pays), [300000, 100000]);
      expect(result.leftover, 0);
    });

    test('marks only the fully paid bills as paid off', () {
      final result = allocateOldestFirst(_bills, 400000);
      expect(result.allocations.map((a) => a.paidOff), [true, false]);
    });

    test('pays every open bill when the amount equals the total owed', () {
      final result = allocateOldestFirst(_bills, 634000);
      expect(result.allocations.every((a) => a.paidOff), isTrue);
      expect(result.allocations.fold<int>(0, (sum, a) => sum + a.pays), 634000);
      expect(result.leftover, 0);
    });

    test('returns the amount above the total owed as leftover', () {
      final result = allocateOldestFirst(_bills, 700000);
      expect(result.allocations.length, 3);
      expect(result.leftover, 66000);
    });

    test('returns nothing for zero or negative amounts', () {
      expect(allocateOldestFirst(_bills, 0).allocations, isEmpty);
      expect(allocateOldestFirst(_bills, -500).allocations, isEmpty);
    });

    test('does not change the order of the list it is given', () {
      final before = _bills.map((b) => b.id).toList();
      allocateOldestFirst(_bills, 100);
      expect(_bills.map((b) => b.id).toList(), before);
    });

    test('breaks a tie on the sale date by the lower id', () {
      const same = [
        OpenBill(id: 9, billNo: 'S-0009', balance: 500, soldAt: '2026-10-01T04:00:00+00:00'),
        OpenBill(id: 7, billNo: 'S-0007', balance: 500, soldAt: '2026-10-01T04:00:00+00:00'),
      ];
      final result = allocateOldestFirst(same, 500);
      expect(result.allocations.single.bill.billNo, 'S-0007');
    });
  });
}
