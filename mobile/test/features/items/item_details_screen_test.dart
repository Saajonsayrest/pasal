import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/features/items/presentation/item_details_screen.dart';
import 'package:pasal_mobile/features/selling/data/cart.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'item_fixtures.dart';

final _routes = [
  GoRoute(path: '/sell/checkout', builder: (_, _) => const Text('Checkout page')),
  GoRoute(path: '/items', builder: (_, _) => const Text('Items list')),
];

FakeApi _api() {
  final now = DateTime.now();
  return FakeApi()
    ..on('GET', '/items/7', (q, b) => {'data': itemJson(quantity: 3, isLowStock: true)})
    ..on('GET', '/categories', (q, b) => pagedJson([categoryJson(1, 'Grocery')]))
    ..on(
      'GET',
      '/items/7/stock-movements',
      (q, b) => pagedJson([
        movementJson(id: 1, change: -2, reason: 'sale', at: now.subtract(const Duration(days: 3))),
        movementJson(id: 2, change: 5, reason: 'adjust', at: now, note: 'Counted again'),
      ]),
    );
}

void main() {
  testWidgets('the owner sees the profit per piece, sales and stock history', (tester) async {
    await pumpApp(tester, const ItemDetailsScreen(id: 7), api: _api(), routes: _routes);

    expect(find.text('Rs 115'), findsOneWidget);
    expect(find.text('Rs 86.50'), findsOneWidget);
    expect(find.text('Rs 15.27 (15.0%)'), findsOneWidget);
    expect(find.text('Low stock'), findsWidgets);
    expect(find.text('2 pcs'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
    expect(find.text('Stock history'), findsOneWidget);
  });

  testWidgets('staff see the price but not the profit, the history or the owner buttons', (tester) async {
    final api = _api()..on('GET', '/items/7', (q, b) => {'data': itemJson(costPrice: null, quantity: 3, isLowStock: true)});
    await pumpApp(tester, const ItemDetailsScreen(id: 7), api: api, owner: false, routes: _routes);

    expect(find.text('Rs 115'), findsOneWidget);
    expect(find.text('Profit per piece'), findsNothing);
    expect(find.text('Stock history'), findsNothing);
    expect(find.text('Adjust stock'), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('Sell this puts the item in the cart and opens the checkout', (tester) async {
    final container = await pumpApp(tester, const ItemDetailsScreen(id: 7), api: _api(), routes: _routes);

    await tester.tap(find.text('Sell this'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout page'), findsOneWidget);
    final cart = container.read(cartProvider);
    expect(cart.lines.single.item.id, 7);
    expect(cart.lines.single.qty, 1);
  });

  testWidgets('delete asks first, then deletes and goes back to the list', (tester) async {
    final api = _api()..on('DELETE', '/items/7', (q, b) => {'message': 'Deleted.'});
    await pumpApp(tester, const ItemDetailsScreen(id: 7), api: api, routes: _routes);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('DELETE /items/7')));

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(api.calls, contains('DELETE /items/7'));
    expect(find.text('Items list'), findsOneWidget);
  });
}
