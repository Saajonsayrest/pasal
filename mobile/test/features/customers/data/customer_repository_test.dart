import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/features/customers/data/customer_repository.dart';

import '../../../helpers/fake_api.dart';
import '../../../helpers/pump_app.dart';
import '../customer_fixtures.dart';

void main() {
  test('ledger reads the customer, the owed amount and the lines', () async {
    final api = FakeApi()..on('GET', '/customers/4/ledger', (q, b) => ledgerJson());
    final ledger = await CustomerRepository(api).ledger(4);

    expect(api.calls, ['GET /customers/4/ledger']);
    expect(ledger.customer.name, 'Hari Thapa');
    expect(ledger.owes, 1500000);
    expect(ledger.creditLimit, 1000000);
    expect(ledger.sales.length, 2);
    expect(ledger.payments.single.amount, 500000);
  });

  test('create posts the body and returns the saved customer', () async {
    final api = FakeApi()..on('POST', '/customers', (q, b) => {'data': customerJson(id: 7, name: 'Sita Gurung', owes: null)});
    final saved = await CustomerRepository(api).create({'name': 'Sita Gurung', 'credit_limit': 500000});

    expect(saved.id, 7);
    expect(api.bodies['POST /customers']!.single, {'name': 'Sita Gurung', 'credit_limit': 500000});
  });

  test('update patches the customer', () async {
    final api = FakeApi()..on('PATCH', '/customers/4', (q, b) => {'data': customerJson(name: 'Hari K. Thapa', owes: null)});
    final saved = await CustomerRepository(api).update(4, {'name': 'Hari K. Thapa'});

    expect(saved.name, 'Hari K. Thapa');
    expect(api.bodies['PATCH /customers/4']!.single, {'name': 'Hari K. Thapa'});
  });

  test('delete calls the delete route', () async {
    final api = FakeApi()..on('DELETE', '/customers/4', (q, b) => {'message': 'Deleted.'});
    await CustomerRepository(api).delete(4);
    expect(api.calls, ['DELETE /customers/4']);
  });

  test('takePayment posts the amount, the method and the key, and returns what is still owed', () async {
    final api = FakeApi()..on('POST', '/payments', (q, b) => {'data': [], 'owes_left': 0});
    final owesLeft = await CustomerRepository(api).takePayment(customerId: 4, amount: 1500000, method: 'cash', key: 'key-1');

    expect(owesLeft, 0);
    expect(api.bodies['POST /payments']!.single, {'customer_id': 4, 'amount': 1500000, 'method': 'cash'});
    expect(api.keys['POST /payments']!.single, 'key-1');
  });

  test('a failed payment throws the API error', () async {
    final api = FakeApi()..on('POST', '/payments', (q, b) => throw validation({'amount': ['Only 5000.00 is left.']}));
    await expectLater(
      CustomerRepository(api).takePayment(customerId: 4, amount: 9000000, method: 'cash', key: 'k'),
      throwsA(isA<ApiException>().having((e) => e.field('amount'), 'amount', 'Only 5000.00 is left.')),
    );
  });
}
