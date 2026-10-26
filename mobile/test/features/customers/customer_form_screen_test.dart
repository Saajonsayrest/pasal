import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/features/customers/presentation/customer_form_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'customer_fixtures.dart';

final _ledgerRoute = GoRoute(path: '/customers/:id', builder: (_, state) => Text('ledger ${state.pathParameters['id']}'));

/// Lets the toast timer finish, so the test does not end with a pending timer.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

/// Field order on the form: name, phone, address, PAN, and the credit limit (owner only).
Future<void> _fill(WidgetTester tester, {required String name, String? phone, String? limit}) async {
  await tester.enterText(find.byType(TextField).at(0), name);
  if (phone != null) await tester.enterText(find.byType(TextField).at(1), phone);
  if (limit != null) await tester.enterText(find.byType(TextField).at(4), limit);
}

void main() {
  testWidgets('the owner adds a customer with a credit limit and lands on the new ledger', (tester) async {
    final api = FakeApi()..on('POST', '/customers', (q, b) => {'data': customerJson(id: 7, name: 'Sita Gurung', owes: null, creditLimit: 500000)});
    await pumpApp(tester, const CustomerFormScreen(), api: api, routes: [_ledgerRoute], size: testCanvas);

    await _fill(tester, name: 'Sita Gurung', phone: '9800000007', limit: '5000');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(api.bodies['POST /customers']!.single, {
      'name': 'Sita Gurung',
      'phone': '9800000007',
      'address': null,
      'pan': null,
      'credit_limit': 500000,
    });
    expect(find.text('ledger 7'), findsOneWidget);
  });

  testWidgets('staff do not see the credit limit and it is not sent', (tester) async {
    final api = FakeApi()..on('POST', '/customers', (q, b) => {'data': customerJson(id: 8, name: 'Ram Karki', owes: null)});
    await pumpApp(tester, const CustomerFormScreen(), api: api, owner: false, routes: [_ledgerRoute], size: testCanvas);

    expect(find.text('Credit limit'), findsNothing);
    await _fill(tester, name: 'Ram Karki');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect((api.bodies['POST /customers']!.single as Map).containsKey('credit_limit'), isFalse);
  });

  testWidgets('a name is required and nothing is sent without one', (tester) async {
    final api = FakeApi();
    await pumpApp(tester, const CustomerFormScreen(), api: api, routes: [_ledgerRoute], size: testCanvas);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Type the customer name.'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('a 422 shows the message under the field', (tester) async {
    final api = FakeApi()..on('POST', '/customers', (q, b) => throw validation({'phone': ['This phone is already used.']}));
    await pumpApp(tester, const CustomerFormScreen(), api: api, routes: [_ledgerRoute], size: testCanvas);

    await _fill(tester, name: 'Sita Gurung', phone: '9800000007');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('This phone is already used.'), findsOneWidget);
  });

  testWidgets('after an add from the checkout the screen goes back to the checkout with the new customer', (tester) async {
    final api = FakeApi()..on('POST', '/customers', (q, b) => {'data': customerJson(id: 7, name: 'Sita Gurung', owes: null)});
    final checkout = GoRoute(path: '/sell/checkout', builder: (_, state) => Text('checkout ${state.uri.queryParameters['customer']}'));
    await pumpApp(tester, const CustomerFormScreen(afterCheckout: true), api: api, routes: [checkout, _ledgerRoute], size: testCanvas);

    await _fill(tester, name: 'Sita Gurung');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(find.text('checkout 7'), findsOneWidget);
  });

  testWidgets('edit loads the customer and saves the change', (tester) async {
    final api = FakeApi()
      ..on('GET', '/customers/4', (q, b) => {'data': customerJson(owes: 1500000, creditLimit: 1000000)})
      ..on('PATCH', '/customers/4', (q, b) => {'data': customerJson(name: 'Hari K. Thapa', owes: 1500000)});
    await pumpApp(tester, const CustomerFormScreen(customerId: 4), api: api, routes: [_ledgerRoute], size: testCanvas);

    expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, 'Hari Thapa');

    await _fill(tester, name: 'Hari K. Thapa');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect((api.bodies['PATCH /customers/4']!.single as Map)['name'], 'Hari K. Thapa');
    expect(find.text('ledger 4'), findsOneWidget);
  });

  testWidgets('delete asks first, then removes the customer and goes back to the list', (tester) async {
    final api = FakeApi()
      ..on('GET', '/customers/4', (q, b) => {'data': customerJson(owes: 1500000)})
      ..on('DELETE', '/customers/4', (q, b) => {'message': 'Deleted.'});
    final list = GoRoute(path: '/customers', builder: (_, _) => const Text('customer list'));
    await pumpApp(tester, const CustomerFormScreen(customerId: 4), api: api, routes: [_ledgerRoute, list], size: testCanvas);

    await tester.tap(find.text('Delete customer'));
    await tester.pumpAndSettle();
    expect(api.calls, ['GET /customers/4']);

    await tester.tap(find.text('Delete'));
    await _settle(tester);

    expect(api.calls, contains('DELETE /customers/4'));
    expect(find.text('customer list'), findsOneWidget);
  });
}
