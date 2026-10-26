import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/features/items/presentation/adjust_stock_sheet.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'item_fixtures.dart';

void main() {
  testWidgets('a removal with a reason is saved once with a key', (tester) async {
    final api = FakeApi()..on('POST', '/stock-adjustments', (q, b) => {'data': itemJson(quantity: 11)});
    Item? saved;

    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: AdjustStockSheet(item: Item.fromJson(itemJson()), onSaved: (i) => saved = i),
        ),
      ),
      api: api,
    );
    await tester.tap(find.text('Damaged'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /stock-adjustments'], [
      {'item_id': 7, 'change': -1, 'note': 'Damaged'},
    ]);
    expect(api.keys['POST /stock-adjustments']?.single, isNotNull);
    expect(saved?.quantity, 11);
  });

  testWidgets('stock cannot go below zero', (tester) async {
    final api = FakeApi();

    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: AdjustStockSheet(item: Item.fromJson(itemJson(quantity: 0)), onSaved: (_) {}),
        ),
      ),
      api: api,
    );
    await tester.tap(find.text('Gift'));
    await tester.pump();

    expect(find.text('Stock cannot go below 0.'), findsOneWidget);
    expect(api.calls, isEmpty);
  });
}
