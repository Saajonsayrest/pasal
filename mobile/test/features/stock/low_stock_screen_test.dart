import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/features/stock/presentation/low_stock_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'stock_fixtures.dart';

FakeApi _lowApi() => FakeApi()
  ..on(
    'GET',
    '/items',
    (q, b) => pagedJson([
      itemJson(id: 5, name: 'Eggs tray', quantity: 4, lowStockAt: 10, categoryId: 2, costPrice: 45000),
      itemJson(id: 7, name: 'Rice 5kg', quantity: 3, lowStockAt: 3, costPrice: 90000),
    ]),
  )
  ..on('GET', '/categories', (q, b) => pagedJson([categoryJson(id: 2, name: 'Eggs', icon: 'egg', color: '#e0731a')]));

void main() {
  testWidgets('groups low items, suggests order amounts and totals the cost of ticked items', (tester) async {
    await pumpApp(tester, const LowStockScreen(), api: _lowApi());

    expect(find.text('Eggs · 1 items'), findsOneWidget);
    expect(find.text('No category · 1 items'), findsOneWidget);
    expect(find.text('Eggs tray'), findsOneWidget);
    expect(find.text('Stock 4 · low level 10'), findsOneWidget);
    expect(find.text('Make purchase'), findsNWidgets(2));
    // 16 eggs at Rs 450 and 3 bags of rice at Rs 900.
    expect(find.text('Rs 9,900'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    expect(find.text('Rs 7,200'), findsOneWidget);
  });

  testWidgets('Make purchase opens the purchase form with the ticked items and amounts', (tester) async {
    await pumpApp(
      tester,
      const LowStockScreen(),
      api: _lowApi(),
      routes: [
        GoRoute(path: '/purchases/new', builder: (_, state) => Text('NEW ${state.uri}')),
      ],
    );

    await tester.tap(find.text('Make purchase').first);
    await tester.pumpAndSettle();

    expect(find.text('NEW /purchases/new?items=5:16'), findsOneWidget);
  });
}
