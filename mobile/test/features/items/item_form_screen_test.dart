import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/features/items/presentation/item_form_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'item_fixtures.dart';

final _routes = [
  GoRoute(path: '/items/:id', builder: (_, state) => Text('Item ${state.pathParameters['id']}')),
];

FakeApi _api() => FakeApi()
  ..on('GET', '/categories', (q, b) => pagedJson([categoryJson(1, 'Grocery')]))
  ..on('GET', '/items/suggest', (q, b) => {'data': <Map<String, dynamic>>[]});

void main() {
  testWidgets('a new item is saved with its prices in paisa', (tester) async {
    final api = _api()..on('POST', '/items', (q, b) => {'data': itemJson(id: 9, name: 'Sugar 1kg')});

    await pumpApp(tester, const ItemFormScreen(), api: api, routes: _routes);
    await tester.enterText(find.byType(TextField).at(0), 'Sugar 1kg');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).at(2), '115');
    await tester.enterText(find.byType(TextField).at(3), '86.50');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /items'], [
      {
        'name': 'Sugar 1kg',
        'sku': null,
        'unit': 'pcs',
        'vat_applies': true,
        'cost_price': 8650,
        'sell_price': 11500,
        'low_stock_at': 5,
        'category_id': null,
      },
    ]);
    expect(find.text('Item 9'), findsOneWidget);
  });

  testWidgets('an edit sends the changed selling price', (tester) async {
    final api = _api()
      ..on('GET', '/items/7', (q, b) => {'data': itemJson()})
      ..on('PATCH', '/items/7', (q, b) => {'data': itemJson(sellPrice: 12000)});

    await pumpApp(tester, const ItemFormScreen(id: 7), api: api, routes: _routes);
    await tester.enterText(find.byType(TextField).at(2), '120');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.bodies['PATCH /items/7']?.single, {
      'name': 'Rice 5kg',
      'sku': null,
      'unit': 'pcs',
      'vat_applies': true,
      'cost_price': 8650,
      'sell_price': 12000,
      'low_stock_at': 3,
      'category_id': null,
    });
  });

  testWidgets('a duplicate name offers the existing item', (tester) async {
    final api = _api()
      ..on(
        'POST',
        '/items',
        (q, b) => throw ApiException(
          422,
          'An item named "Rice 5kg" already exists. Use that item instead.',
          errors: {
            'name': ['An item named "Rice 5kg" already exists. Use that item instead.'],
          },
          body: {
            'existing_item': {'id': 7, 'name': 'Rice 5kg', 'deleted': false},
          },
        ),
      );

    await pumpApp(tester, const ItemFormScreen(), api: api, routes: _routes);
    await tester.enterText(find.byType(TextField).at(0), 'Rice 5kg');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).at(2), '115');
    await tester.enterText(find.byType(TextField).at(3), '86.50');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Rice 5kg already exists. Use that item instead?'), findsOneWidget);
    expect(find.text('Use'), findsOneWidget);
  });
}
