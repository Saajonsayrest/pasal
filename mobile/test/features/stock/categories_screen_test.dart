import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/stock/presentation/categories_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'stock_fixtures.dart';

FakeApi _categoriesApi() => FakeApi()
  ..on(
    'GET',
    '/categories',
    (q, b) => pagedJson([
      categoryJson(id: 1, name: 'Grocery', icon: 'store', color: '#1f8a63'),
      categoryJson(id: 2, name: 'Eggs', icon: 'egg', color: '#e0731a'),
    ]),
  )
  ..on(
    'GET',
    '/items',
    (q, b) => pagedJson([
      itemJson(id: 1, name: 'Rice', categoryId: 1),
      itemJson(id: 2, name: 'Dal', categoryId: 1),
      itemJson(id: 3, name: 'Eggs tray', categoryId: 2),
    ]),
  );

void main() {
  testWidgets('lists the categories with their item counts', (tester) async {
    await pumpApp(tester, const CategoriesScreen(), api: _categoriesApi());

    expect(find.text('Grocery'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets('adding a category sends the name with the default icon and colour', (tester) async {
    final api = _categoriesApi()
      ..on('POST', '/categories', (q, b) => {'data': categoryJson(id: 3, name: 'Spices', icon: 'category', color: '#1f8a63')});
    await pumpApp(tester, const CategoriesScreen(), api: api);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Spices');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /categories'], [
      {'name': 'Spices', 'icon': 'category', 'color': '#1f8a63'},
    ]);
    expect(find.text('Category added'), findsOneWidget);
  });

  testWidgets('editing a category puts the new name, icon and colour', (tester) async {
    final api = _categoriesApi()
      ..on('PUT', '/categories/2', (q, b) => {'data': categoryJson(id: 2, name: 'Eggs and dairy', icon: 'egg', color: '#2563eb')});
    await pumpApp(tester, const CategoriesScreen(), api: api);

    await tester.tap(find.text('Eggs'));
    await tester.pumpAndSettle();
    expect(find.text('Edit category'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Eggs and dairy');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.bodies['PUT /categories/2'], [
      {'name': 'Eggs and dairy', 'icon': 'egg', 'color': '#e0731a'},
    ]);
  });
}
