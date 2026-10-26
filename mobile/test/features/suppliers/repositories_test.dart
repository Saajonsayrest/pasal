import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/features/suppliers/data/purchase_repository.dart';
import 'package:pasal_mobile/features/suppliers/data/supplier_repository.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'suppliers_fixtures.dart';

void main() {
  group('SupplierRepository', () {
    test('the list sends the search and the owed filter, and reads the totals', () async {
      Query? seen;
      final api = FakeApi()
        ..on('GET', '/suppliers', (q, b) {
          seen = q;
          return pagedJson([supplierJson(3, 'Himal Traders', weOwe: 630000)], summary: {'owed_total': 634000});
        });

      final list = await SupplierRepository(api).list((search: 'him', owedOnly: true));

      expect(seen?['search'], 'him');
      expect(seen?['owed'], true);
      expect(seen?['per_page'], 50);
      expect(list.owedTotal, 634000);
      expect(list.suppliers.single.weOwe, 630000);
    });

    test('the owed filter is left out when off', () async {
      Query? seen;
      final api = FakeApi()
        ..on('GET', '/suppliers', (q, b) {
          seen = q;
          return pagedJson([]);
        });

      await SupplierRepository(api).list((search: '', owedOnly: false));

      expect(seen?.containsKey('owed'), isTrue);
      expect(seen?['owed'], isNull);
    });

    test('paying a supplier sends the supplier, amount, method and key', () async {
      final api = FakeApi()..on('POST', '/payments', (q, b) => {'data': <Object>[], 'owes_left': 0});

      final left = await SupplierRepository(api).payOldestFirst(supplierId: 3, amount: 1130000, method: 'cash', key: 'key-1');

      expect(left, 0);
      expect(api.bodies['POST /payments']!.single, {'supplier_id': 3, 'amount': 1130000, 'method': 'cash'});
      expect(api.keys['POST /payments']!.single, 'key-1');
    });

    test('a supplier save uses POST for a new one and PATCH for an edit', () async {
      final api = FakeApi()
        ..on('POST', '/suppliers', (q, b) => {'data': supplierJson(9, 'Everest Traders')})
        ..on('PATCH', '/suppliers/9', (q, b) => {'data': supplierJson(9, 'Everest')});
      final repo = SupplierRepository(api);

      expect((await repo.save(null, {'name': 'Everest Traders'})).id, 9);
      expect((await repo.save(9, {'name': 'Everest'})).name, 'Everest');
      expect(api.calls, containsAll(['POST /suppliers', 'PATCH /suppliers/9']));
    });
  });

  group('PurchaseRepository', () {
    test('a month filter sends the Nepali month dates, the default does not', () async {
      final seen = <Query?>[];
      final api = FakeApi()
        ..on('GET', '/purchases', (q, b) {
          seen.add(q);
          return pagedJson([purchaseJson(12, total: 1130000, paid: 500000)]);
        });
      final repo = PurchaseRepository(api);
      final month = bsMonthRange(todayBs().year, todayBs().month);

      await repo.page((search: '', filter: 'month', supplierId: null, page: 1));
      await repo.page((search: '', filter: 'all', supplierId: 3, page: 2));

      expect(seen[0]?['from'], month.from);
      expect(seen[0]?['to'], month.to);
      expect(seen[1]?['from'], isNull);
      expect(seen[1]?['supplier_id'], 3);
      expect(seen[1]?['page'], 2);
      expect(seen[1]?['per_page'], 20);
    });

    test('the summary adds this month and the open bills', () async {
      final api = FakeApi()
        ..on('GET', '/purchases', (q, b) {
          if (q?['unpaid'] == true) return pagedJson([purchaseJson(12, total: 1130000, paid: 500000)]);
          return pagedJson([purchaseJson(12, total: 1130000, paid: 500000), purchaseJson(13, total: 200000, paid: 200000)]);
        });

      final summary = await PurchaseRepository(api).summary();

      expect(summary.monthTotal, 1330000);
      expect(summary.monthCount, 2);
      expect(summary.owed, 630000);
      expect(summary.openCount, 1);
    });

    test('a new purchase sends the body and the key', () async {
      final body = {
        'supplier_id': 3,
        'bill_no': null,
        'bill_date': '2026-10-26',
        'vat_amount': 0,
        'paid': 0,
        'method': 'cash',
        'note': null,
        'items': [
          {'item_id': 7, 'quantity': 100, 'unit_cost': 10000},
        ],
      };
      final api = FakeApi()..on('POST', '/purchases', (q, b) => {'data': purchaseJson(12, total: 1000000, paid: 0)});

      final saved = await PurchaseRepository(api).create(body, 'key-2');

      expect(saved.id, 12);
      expect(api.bodies['POST /purchases']!.single, body);
      expect(api.keys['POST /purchases']!.single, 'key-2');
    });

    test('a 422 keeps the field message for the form', () async {
      final api = FakeApi()
        ..on('POST', '/payments', (q, b) => throw validation({'amount': ['Only 500.00 is left on this bill.']}));

      await expectLater(
        PurchaseRepository(api).payBill(purchaseId: 12, amount: 99999900, method: 'cash', key: 'k'),
        throwsA(isA<ApiException>().having((e) => e.field('amount'), 'amount', 'Only 500.00 is left on this bill.')),
      );
    });
  });
}
