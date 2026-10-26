import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/features/selling/data/cart.dart';
import 'package:pasal_mobile/features/selling/presentation/checkout_screen.dart';
import 'package:pasal_mobile/features/selling/presentation/sell_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'selling_fixtures.dart';

void main() {
  testWidgets('the sell tab loads the items and adds one to the cart', (tester) async {
    final api = FakeApi()
      ..on('GET', '/categories', (q, b) => pagedJson([{'id': 1, 'name': 'Grocery', 'icon': null, 'color': null}]))
      ..on(
        'GET',
        '/items',
        (q, b) => pagedJson([
          itemJson(7, 'Rice 5kg', 11300, sku: 'RICE-5'),
          itemJson(9, 'Milk 500ml', 5000, qty: 0, vat: false),
        ]),
      );

    await pumpApp(tester, const SellScreen(), api: api);

    expect(find.text('Rice 5kg'), findsOneWidget);
    expect(find.text('Grocery'), findsOneWidget);
    expect(find.text('No stock'), findsOneWidget);

    await tester.tap(find.text('Rice 5kg'));
    await tester.pumpAndSettle();

    expect(find.text('1 items'), findsOneWidget);
    expect(find.text('Checkout'), findsOneWidget);
  });

  testWidgets('checkout saves the cart with the key and opens the bill', (tester) async {
    final api = FakeApi()..on('POST', '/sales', (q, b) => {'data': saleJson(id: 31, billNo: 'S-0031', paid: 11300, balance: 0)});
    final container = await pumpApp(
      tester,
      const CheckoutScreen(),
      api: api,
      routes: [GoRoute(path: '/sales/:id/bill', builder: (_, _) => const Text('bill page'))],
    );

    container.read(cartProvider.notifier).add(riceItem());
    await tester.pumpAndSettle();
    expect(find.text('Finish sale'), findsOneWidget);

    await tester.tap(find.text('Finish sale'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /sales']!.single, {
      'paid': 11300,
      'discount': 0,
      'method': 'cash',
      'items': [
        {'item_id': 7, 'quantity': 1},
      ],
    });
    expect(api.keys['POST /sales']!.single, isNotNull);
    expect(find.text('bill page'), findsOneWidget);
    expect(container.read(cartProvider).lines, isEmpty);
  });

  testWidgets('checkout shows the stock message from the server under the cart', (tester) async {
    final api = FakeApi()
      ..on('POST', '/sales', (q, b) => throw validation({'items.0.quantity': ['Only 2 Rice 5kg left.']}, message: 'Not enough stock.'));
    final container = await pumpApp(tester, const CheckoutScreen(), api: api);

    container.read(cartProvider.notifier).add(riceItem());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish sale'));
    await tester.pumpAndSettle();

    expect(find.text('Only 2 Rice 5kg left.'), findsOneWidget);
    expect(container.read(cartProvider).count, 1);
  });
}
