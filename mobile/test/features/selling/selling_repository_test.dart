import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/features/selling/data/selling_repository.dart';

import '../../helpers/fake_api.dart';
import 'selling_fixtures.dart';

void main() {
  test('findBySku picks the exact code, not a name match', () async {
    final api = FakeApi()
      ..on(
        'GET',
        '/items',
        (q, b) => pagedJson([
          itemJson(1, 'Rice 5kg sack', 100000, sku: 'RICE-50'),
          itemJson(7, 'Rice 5kg', 11300, sku: 'RICE-5'),
        ]),
      );
    final repo = SellingRepository(api);

    final found = await repo.findBySku('RICE-5');
    expect(found?.id, 7);
    expect(api.calls, ['GET /items']);

    expect(await repo.findBySku('NOPE'), isNull);
  });

  test('findBySku checks the items already on screen before asking the server', () async {
    final api = FakeApi();
    final repo = SellingRepository(api);
    final known = [Item.fromJson(itemJson(7, 'Rice 5kg', 11300, sku: 'RICE-5'))];

    final found = await repo.findBySku('RICE-5', known: known);
    expect(found?.id, 7);
    expect(api.calls, isEmpty);
  });

  test('createSale sends the body and the Idempotency-Key', () async {
    final api = FakeApi()..on('POST', '/sales', (q, b) => {'data': saleJson()});
    final repo = SellingRepository(api);
    final body = {
      'paid': 5000,
      'discount': 0,
      'method': 'cash',
      'items': [
        {'item_id': 7, 'quantity': 1},
      ],
    };

    final sale = await repo.createSale(body, 'key-1');

    expect(sale.id, 31);
    expect(api.bodies['POST /sales']!.single, body);
    expect(api.keys['POST /sales']!.single, 'key-1');
  });

  test('takePayment posts sale id, amount and method, and returns the balance left', () async {
    final api = FakeApi()..on('POST', '/payments', (q, b) => {'data': paymentJson(amount: 6300), 'balance_left': 0});
    final repo = SellingRepository(api);

    final left = await repo.takePayment(saleId: 31, amount: 6300, method: 'qr', key: 'k2');

    expect(left, 0);
    expect(api.bodies['POST /payments']!.single, {'sale_id': 31, 'amount': 6300, 'method': 'qr'});
    expect(api.keys['POST /payments']!.single, 'k2');
  });

  test('cancelSale reads the refund and the sale state from the answer', () async {
    final api = FakeApi()
      ..on('POST', '/sales/31/cancel', (q, b) => {'data': returnJson(refunded: 5000, kind: 'cancel'), 'sale_balance': 0, 'sale_cancelled': true});
    final repo = SellingRepository(api);

    final outcome = await repo.cancelSale(31, {'restock': true, 'note': 'Left'}, 'k3');

    expect(outcome.refunded, 5000);
    expect(outcome.saleBalance, 0);
    expect(outcome.saleCancelled, isTrue);
  });
}
