import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/features/customers/presentation/take_payment_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'customer_fixtures.dart';

final _ledgerRoute = GoRoute(path: '/customers/:id', builder: (_, state) => Text('ledger ${state.pathParameters['id']}'));

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  // Let the toast timer finish so the test does not end with a pending timer.
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the open bills oldest first and pays the full amount with a key', (tester) async {
    final api = FakeApi()
      ..on('GET', '/customers/4/ledger', (q, b) => ledgerJson())
      ..on('POST', '/payments', (q, b) => {'data': <Object>[], 'owes_left': 0});

    await pumpApp(tester, const TakePaymentScreen(customerId: 4), api: api, routes: [_ledgerRoute], size: testCanvas);

    expect(find.text('Oldest bills are paid first'), findsOneWidget);
    expect(find.text('S-0031'), findsWidgets);
    expect(find.text('The money will be used like this'), findsOneWidget);
    expect(find.text('Rs 15,000'), findsWidgets);

    await tester.tap(find.text('Save payment'));
    await _settle(tester);

    expect(api.bodies['POST /payments']!.single, {'customer_id': 4, 'amount': 1500000, 'method': 'cash'});
    expect(api.keys['POST /payments']!.single, isNotNull);
    expect(find.text('ledger 4'), findsOneWidget);
  });

  testWidgets('a retry of the same tap sends the same key', (tester) async {
    var calls = 0;
    final api = FakeApi()
      ..on('GET', '/customers/4/ledger', (q, b) => ledgerJson())
      ..on('POST', '/payments', (q, b) {
        calls++;
        if (calls == 1) throw ApiException(500, 'Something went wrong.');
        return {'data': <Object>[], 'owes_left': 0};
      });

    await pumpApp(tester, const TakePaymentScreen(customerId: 4), api: api, routes: [_ledgerRoute], size: testCanvas);

    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong.'), findsOneWidget);

    await tester.tap(find.text('Save payment'));
    await _settle(tester);

    final keys = api.keys['POST /payments']!;
    expect(keys.length, 2);
    expect(keys[1], keys[0]);
  });

  testWidgets('a new method gets a new key', (tester) async {
    var calls = 0;
    final api = FakeApi()
      ..on('GET', '/customers/4/ledger', (q, b) => ledgerJson())
      ..on('POST', '/payments', (q, b) {
        calls++;
        if (calls == 1) throw ApiException(500, 'Something went wrong.');
        return {'data': <Object>[], 'owes_left': 0};
      });

    await pumpApp(tester, const TakePaymentScreen(customerId: 4), api: api, routes: [_ledgerRoute], size: testCanvas);

    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('QR'));
    await tester.tap(find.text('QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save payment'));
    await _settle(tester);

    final keys = api.keys['POST /payments']!;
    final bodies = api.bodies['POST /payments']!;
    expect(bodies.last, {'customer_id': 4, 'amount': 1500000, 'method': 'qr'});
    expect(keys[1], isNot(keys[0]));
  });

  testWidgets('an amount above the owed total shows an error and cannot be saved', (tester) async {
    final api = FakeApi()..on('GET', '/customers/4/ledger', (q, b) => ledgerJson());
    await pumpApp(tester, const TakePaymentScreen(customerId: 4), api: api, routes: [_ledgerRoute], size: testCanvas);

    // The keypad starts at 15000. Typing 1 makes it 150001.
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.text('The amount is more than Hari Thapa owes (Rs 15,000).'), findsOneWidget);
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(api.calls, ['GET /customers/4/ledger']);
  });
}
