import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/settings/data/activity_repository.dart';
import 'package:pasal_mobile/features/settings/data/backup_repository.dart';
import 'package:pasal_mobile/features/settings/data/shop_repository.dart';
import 'package:pasal_mobile/features/settings/data/staff_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _business() => {
      'id': 1,
      'name': 'Himal Kirana Pasal',
      'pan': '600000001',
      'phone': null,
      'address': 'Baneshwor',
      'vat_rate': 13.0,
    };

Map<String, dynamic> _user(int id, String name, String role) => {
      'id': id,
      'name': name,
      'email': '${name.split(' ').first.toLowerCase()}@example.com',
      'role': role,
    };

Map<String, dynamic> _item(int id, String name, {int? categoryId, required int sellPrice, int? costPrice}) => {
      'id': id,
      'name': name,
      'sku': id == 1 ? 'SKU1' : null,
      'unit': 'pcs',
      'category_id': categoryId,
      'vat_applies': true,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'quantity': 10,
      'low_stock_at': 2,
      'is_low_stock': false,
      'photo_url': null,
    };

Map<String, dynamic> _sale() => {
      'id': 1,
      'bill_no': 'S-0413',
      'customer_id': 2,
      'customer': {'id': 2, 'name': 'Hari Thapa', 'phone': null, 'address': null, 'pan': null, 'credit_limit': null},
      'subtotal': 221500,
      'discount': 0,
      'total': 221500,
      'returned_total': 0,
      'paid': 100000,
      'balance': 121500,
      'cancelled_at': null,
      'vat_rate': 13,
      'taxable_amount': 196000,
      'vat_amount': 25480,
      'exempt_amount': 0,
      'sold_at': '2026-10-26T07:00:00+00:00',
      'sold_by': 'Asha',
    };

void main() {
  group('shop', () {
    test('update sends the whole form and reads the business back', () async {
      final api = FakeApi()..on('PATCH', '/business', (q, b) => {'data': _business()});
      final shop = await ShopRepository(api).update(
        name: 'Himal Kirana Pasal',
        vatRate: 13,
        pan: '600000001',
        phone: null,
        address: 'Baneshwor',
      );

      expect(shop.name, 'Himal Kirana Pasal');
      expect(api.bodies['PATCH /business']!.single, {
        'name': 'Himal Kirana Pasal',
        'pan': '600000001',
        'phone': null,
        'address': 'Baneshwor',
        'vat_rate': 13.0,
      });
    });

    test('the bill footer is trimmed, and the default is used when it is blank', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(readBillFooter(prefs), defaultBillFooter);

      await writeBillFooter(prefs, '  Dhanyabad  ');
      expect(readBillFooter(prefs), 'Dhanyabad');

      await writeBillFooter(prefs, '   ');
      expect(prefs.getString(billFooterKey), defaultBillFooter);
    });
  });

  group('staff', () {
    test('list reads every page', () async {
      final api = FakeApi()
        ..on(
          'GET',
          '/users',
          (q, b) => pagedJson(
            [if (q!['page'] == 1) _user(1, 'Asha Shrestha', 'owner') else _user(5, 'Sita Gurung', 'staff')],
            page: q['page']! as int,
            lastPage: 2,
          ),
        );
      final users = await StaffRepository(api).list();

      expect(users.map((u) => u.name), ['Asha Shrestha', 'Sita Gurung']);
      expect(api.calls, ['GET /users', 'GET /users']);
    });

    test('update goes to the person and sends only what it is given', () async {
      final api = FakeApi()..on('PATCH', '/users/5', (q, b) => {'data': _user(5, 'Sita Devi', 'staff')});
      await StaffRepository(api).update(5, {'name': 'Sita Devi'});

      expect(api.bodies['PATCH /users/5']!.single, {'name': 'Sita Devi'});
    });
  });

  group('activity', () {
    test('sends the person and the page, and reads the events', () async {
      Object? seenQuery;
      final api = FakeApi()
        ..on('GET', '/activity', (q, b) {
          seenQuery = q;
          return {
            'data': [
              {'kind': 'sale', 'ref_id': 9, 'at': '2026-10-26T07:00:00+00:00', 'by': 'Sita', 'label': 'S-0413', 'amount': 221500},
            ],
            'meta': {'current_page': 2, 'last_page': 3, 'per_page': 30, 'total': 75},
          };
        });
      final page = await ActivityRepository(api).page((userId: 5, page: 2));

      expect(seenQuery, {'per_page': activityPerPage, 'page': 2, 'user_id': 5});
      expect(page.items.single.kind, 'sale');
      expect(page.items.single.label, 'S-0413');
      expect(page.meta.total, 75);
      expect(page.meta.hasMore, isTrue);
    });
  });

  group('backup CSV', () {
    test('items use category names, rupees and read every page', () async {
      final progress = <String>[];
      final api = FakeApi()
        ..on('GET', '/categories', (q, b) => pagedJson([{'id': 3, 'name': 'Grocery', 'icon': null, 'color': null}]))
        ..on(
          'GET',
          '/items',
          (q, b) => pagedJson(
            [
              if (q!['page'] == 1)
                _item(1, 'Basmati, 5kg', categoryId: 3, sellPrice: 210000, costPrice: 180000)
              else
                _item(2, 'Sugar', sellPrice: 11500),
            ],
            page: q['page']! as int,
            lastPage: 2,
          ),
        );
      final csv = await BackupRepository(api).build(
        ExportKind.items,
        onProgress: (kind, page, lastPage) => progress.add('${kind.name} $page/$lastPage'),
      );

      expect(csv.split('\n'), [
        'Name,SKU,Unit,Category,Sell price (Rs),Buying price (Rs),Stock,Low stock level,VAT applies',
        '"Basmati, 5kg",SKU1,pcs,Grocery,2100,1800,10,2,Yes',
        'Sugar,,pcs,,115,,10,2,Yes',
      ]);
      expect(progress, ['items 1/2', 'items 2/2']);
      expect(api.calls.where((c) => c == 'GET /items').length, 2);
    });

    test('sales show the bill, the day, the names and the rupee totals', () async {
      final api = FakeApi()
        ..on('GET', '/sales', (q, b) => pagedJson([_sale()]));
      final csv = await BackupRepository(api).build(ExportKind.sales);

      expect(csv.split('\n'), [
        'Bill no,Date (AD),Sold at (UTC),Customer,Subtotal (Rs),Discount (Rs),Total (Rs),Paid (Rs),Balance (Rs),Returned (Rs),VAT (Rs),Cancelled,Sold by',
        'S-0413,2026-10-26,2026-10-26T07:00:00+00:00,Hari Thapa,2215,0,2215,1000,1215,0,254.8,No,Asha',
      ]);
    });

    test('customers and suppliers leave an empty cell when there is no amount', () async {
      final api = FakeApi()
        ..on(
          'GET',
          '/customers',
          (q, b) => pagedJson([
            {'id': 1, 'name': 'Hari Thapa', 'phone': '9800000001', 'address': null, 'pan': null, 'credit_limit': null, 'owes': 634000},
          ]),
        )
        ..on(
          'GET',
          '/suppliers',
          (q, b) => pagedJson([
            {'id': 2, 'name': 'Dealer, Ltd', 'phone': null, 'address': null, 'pan': null, 'note': null, 'we_owe': 50000},
          ]),
        );
      final repo = BackupRepository(api);

      expect((await repo.build(ExportKind.customers)).split('\n').last, ['Hari Thapa', '9800000001', '', '', '', '6340'].join(','));
      expect((await repo.build(ExportKind.suppliers)).split('\n').last, '"Dealer, Ltd",,,,500');
    });

    test('expenses show the day in AD and the amount in rupees', () async {
      final api = FakeApi()
        ..on(
          'GET',
          '/expenses',
          (q, b) => pagedJson([
            {'id': 1, 'title': 'Shop rent', 'category': 'Rent', 'amount': 1500000, 'spent_at': '2026-10-20T00:00:00+00:00'},
          ]),
        );
      final csv = await BackupRepository(api).build(ExportKind.expenses);

      expect(csv.split('\n'), ['Date (AD),Title,Category,Amount (Rs)', '2026-10-20,Shop rent,Rent,15000']);
    });
  });
}
