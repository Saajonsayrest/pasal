import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/vat/data/vat_repository.dart';

import '../../../helpers/fake_api.dart';
import '../vat_fixtures.dart';

void main() {
  test('preview sends the range and the opening carry, and reads the answer without a data wrapper', () async {
    Map<String, Object?>? query;
    final api = FakeApi()
      ..on('GET', '/vat/preview', (q, b) {
        query = q;
        return previewJson();
      });

    final preview = await VatRepository(api).preview((from: '2026-10-17', to: '2026-11-16', openingCarry: 500));

    expect(query, {'from': '2026-10-17', 'to': '2026-11-16', 'opening_carry': 500});
    expect(preview.payable, 520000);
    expect(preview.dueDate, '2026-12-11');
  });

  test('saveComputed sends only the period, the dates and the opening carry, with the key', () async {
    final api = FakeApi()..on('POST', '/vat/filings', (q, b) => {'data': filingJson(id: 9, period: '2083-07')});

    final saved = await VatRepository(api).saveComputed(
      period: '2083-07',
      from: '2026-10-17',
      to: '2026-11-16',
      openingCarry: 0,
      key: 'key-1',
    );

    expect(saved.id, 9);
    expect(api.bodies['POST /vat/filings']!.single, {'period': '2083-07', 'from': '2026-10-17', 'to': '2026-11-16', 'opening_carry': 0});
    expect(api.keys['POST /vat/filings']!.single, 'key-1');
  });

  test('saveManual sends all the typed amounts as paisa with manual true', () async {
    final api = FakeApi()..on('POST', '/vat/filings', (q, b) => {'data': filingJson(id: 4, period: '2083-05', source: 'manual')});

    final saved = await VatRepository(api).saveManual(
      const ManualReturn(
        period: '2083-05',
        from: '2026-08-17',
        to: '2026-09-16',
        salesTaxable: 100000000,
        salesExempt: 0,
        outputVat: 13000000,
        purchasesTaxable: 60000000,
        inputVat: 7800000,
        carryIn: 0,
        payable: 5200000,
        carryOut: 0,
        paidAmount: 5200000,
        filedOn: '2026-09-30',
        receiptNo: 'R-123',
      ),
      key: 'key-2',
    );

    expect(saved.source, 'manual');
    final body = api.bodies['POST /vat/filings']!.single! as Map<String, Object?>;
    expect(body['manual'], true);
    expect(body['sales_taxable'], 100000000);
    expect(body['paid_amount'], 5200000);
    expect(body['receipt_no'], 'R-123');
    expect(api.keys['POST /vat/filings']!.single, 'key-2');
  });

  test('updateMarks patches only the editable fields, with nulls for empty ones', () async {
    final api = FakeApi()..on('PATCH', '/vat/filings/3', (q, b) => {'data': filingJson(id: 3, period: '2083-06', paid: 50000)});

    await VatRepository(api).updateMarks(3, const FilingMarks(paidAmount: 50000));

    expect(api.bodies['PATCH /vat/filings/3']!.single, {
      'filed_on': null,
      'paid_amount': 50000,
      'paid_on': null,
      'receipt_no': null,
      'note': null,
    });
  });

  test('salesPage sends the range and the page, and allSales walks every page', () async {
    final pages = <Object?>[];
    final api = FakeApi()
      ..on('GET', '/sales', (q, b) {
        pages.add(q?['page']);
        final page = (q?['page'] as int?) ?? 1;
        return {
          'data': [
            {
              'id': page,
              'bill_no': 'S-$page',
              'subtotal': 100,
              'discount': 0,
              'total': 100,
              'returned_total': 0,
              'paid': 0,
              'balance': 100,
              'vat_rate': 13.0,
              'taxable_amount': 88,
              'vat_amount': 12,
              'exempt_amount': 0,
              'sold_at': '2026-10-26T07:26:03+00:00',
            },
          ],
          'meta': {'current_page': page, 'last_page': 2, 'per_page': 50, 'total': 2},
        };
      });
    final repo = VatRepository(api);
    const range = (from: '2026-10-17', to: '2026-11-16');

    final first = await repo.salesPage(range);
    expect(first.items.single.billNo, 'S-1');
    expect(api.calls.last, 'GET /sales');

    final all = await repo.allSales(range);
    expect(all.map((s) => s.billNo), ['S-1', 'S-2']);
    expect(pages, [1, 1, 2]);
  });
}
