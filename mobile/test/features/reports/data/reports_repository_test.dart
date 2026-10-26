import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/reports/data/export_tables.dart';
import 'package:pasal_mobile/features/reports/data/reports_repository.dart';

import '../../../helpers/fake_api.dart';

const _range = (from: '2026-10-01', to: '2026-10-31');

Map<String, dynamic> _sale(int id, String soldAt) => {
      'id': id,
      'bill_no': 'S-00$id',
      'customer': null,
      'subtotal': 11300,
      'discount': 0,
      'total': 11300,
      'returned_total': 0,
      'paid': 0,
      'balance': 11300,
      'cancelled_at': null,
      'vat_rate': 13,
      'taxable_amount': 10000,
      'vat_amount': 1300,
      'exempt_amount': 0,
      'sold_at': soldAt,
      'sold_by': 'Asha',
    };

void main() {
  test('exportCsv reads every page of a dated list with the range', () async {
    final queries = <Map<String, Object?>?>[];
    final api = FakeApi()
      ..on('GET', '/sales', (q, b) {
        queries.add(q);
        final page = q!['page'] as int;
        return pagedJson(
          [_sale(page, '2026-10-0${page + 1}T07:26:03+00:00')],
          page: page,
          lastPage: 2,
        );
      });

    final files = await ReportsRepository(api).exportCsv(range: _range, sets: {ExportSet.sales});

    expect(files.length, 1);
    expect(files.single.name, 'pasal-sales-2026-10-01-to-2026-10-31.csv');
    expect(files.single.text.split('\r\n').length, 3);
    expect(queries.map((q) => q!['page']), [1, 2]);
    expect(queries.first, containsPair('from', '2026-10-01'));
    expect(queries.first, containsPair('to', '2026-10-31'));
    expect(queries.first, containsPair('per_page', 50));
  });

  test('expenses stop paging once a page reaches a day before the range', () async {
    final api = FakeApi()
      ..on('GET', '/expenses', (q, b) {
        final page = q!['page'] as int;
        final rows = page == 1
            ? [
                {'id': 2, 'title': 'Inside', 'category': null, 'amount': 100, 'spent_at': '2026-10-20'},
                {'id': 3, 'title': 'Before', 'category': null, 'amount': 100, 'spent_at': '2026-09-20'},
              ]
            : [
                {'id': 4, 'title': 'Older', 'category': null, 'amount': 100, 'spent_at': '2026-08-01'},
              ];
        return pagedJson(rows, page: page, lastPage: 3);
      });

    final files = await ReportsRepository(api).exportCsv(range: _range, sets: {ExportSet.expenses});

    expect(api.calls.where((c) => c == 'GET /expenses').length, 1);
    expect(files.single.text, contains('Inside'));
    expect(files.single.text, isNot(contains('Before')));
  });

  test('items and customers ignore the date range and export every row', () async {
    final api = FakeApi()
      ..on(
        'GET',
        '/items',
        (q, b) => pagedJson([
          {
            'id': 7,
            'name': 'Rice 5kg',
            'sku': 'R5',
            'unit': 'pcs',
            'vat_applies': false,
            'cost_price': 10000,
            'sell_price': 11300,
            'quantity': 4,
            'low_stock_at': 2,
            'is_low_stock': false,
          },
        ]),
      )
      ..on('GET', '/customers', (q, b) => pagedJson([]));

    final files = await ReportsRepository(api).exportCsv(range: _range, sets: {ExportSet.items, ExportSet.customers});

    expect(files.map((f) => f.name.split('-').take(2).join('-')), ['pasal-items', 'pasal-customers']);
    expect(files.first.text, contains('Rice 5kg,R5,pcs,113,100,4,2,No'));
    expect(files.last.text, 'Name,Phone,Address,PAN,Credit limit,Owes,Last sale (AD),Last sale (BS)');
  });

  test('summary sends the dates and reads the unwrapped answer', () async {
    Map<String, Object?>? seen;
    final api = FakeApi()
      ..on(
        'GET',
        '/reports/summary',
        (q, b) {
          seen = q;
          return {
            'from': '2026-10-01',
            'to': '2026-10-31',
            'sales_total': 10000,
            'vat_collected': 1150,
            'cost_of_goods': 6000,
            'expenses_total': 1500,
            'profit': 1350,
            'stock_value': 24000,
            'owed_to_us': 0,
            'we_owe': 0,
          };
        },
      );

    final s = await ReportsRepository(api).summary(_range);

    expect(seen, {'from': '2026-10-01', 'to': '2026-10-31'});
    expect(s.profit, 1350);
  });

  test('staff sales reads the wrapped data list', () async {
    final api = FakeApi()
      ..on(
        'GET',
        '/reports/staff',
        (q, b) => {
          'data': [
            {'user_id': 1, 'name': 'Asha', 'bills': 2, 'sales': 2000, 'discount': 50},
            {'user_id': null, 'name': 'Deleted user', 'bills': 1, 'sales': 500, 'discount': 0},
          ],
        },
      );

    final rows = await ReportsRepository(api).staff(_range);

    expect(rows.map((r) => r.name), ['Asha', 'Deleted user']);
    expect(rows.last.userId, isNull);
  });
}
