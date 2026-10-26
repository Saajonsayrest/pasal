import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/items/presentation/items_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'item_fixtures.dart';

void main() {
  testWidgets('shows the stock value, the low stock count and each item', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/items',
        (q, b) => q?['low_stock'] == 1
            ? pagedJson([itemJson(id: 8, name: 'Sugar 1kg', quantity: 3, isLowStock: true, sellPrice: 11500, categoryId: 1)])
            : pagedJson([
                itemJson(categoryId: 1),
                itemJson(id: 8, name: 'Sugar 1kg', quantity: 3, isLowStock: true, sellPrice: 11500, categoryId: 1),
              ]),
      )
      ..on('GET', '/categories', (q, b) => pagedJson([categoryJson(1, 'Grocery')]))
      ..on('GET', '/reports/summary', (q, b) => summaryJson(stockValue: 38400000));

    await pumpApp(tester, const ItemsScreen(), api: api);

    expect(find.text('Rs 3,84,000'), findsOneWidget);
    expect(find.text('Low stock (1)'), findsOneWidget);
    expect(find.text('Rice 5kg'), findsOneWidget);
    expect(find.text('Sugar 1kg'), findsOneWidget);
    expect(find.text('3 pcs · Grocery'), findsOneWidget);
    expect(find.text('Rs 115'), findsNWidgets(2));
  });

  testWidgets('a search sends the typed text to the server', (tester) async {
    final searches = <Object?>[];
    final api = FakeApi()
      ..on('GET', '/items', (q, b) {
        searches.add(q?['search']);
        return pagedJson([]);
      })
      ..on('GET', '/categories', (q, b) => pagedJson([]))
      ..on('GET', '/reports/summary', (q, b) => summaryJson());

    await pumpApp(tester, const ItemsScreen(), api: api);
    await tester.enterText(find.byType(TextField).first, 'sug');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(searches, contains('sug'));
  });

  testWidgets('shows an empty state with an add button for the owner', (tester) async {
    final api = FakeApi()
      ..on('GET', '/items', (q, b) => pagedJson([]))
      ..on('GET', '/categories', (q, b) => pagedJson([]))
      ..on('GET', '/reports/summary', (q, b) => summaryJson());

    await pumpApp(tester, const ItemsScreen(), api: api);

    expect(find.text('No items yet'), findsOneWidget);
    expect(find.text('Add item'), findsWidgets);
  });
}
