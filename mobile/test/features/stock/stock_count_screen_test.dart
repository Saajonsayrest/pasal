import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/features/stock/data/count_draft.dart';
import 'package:pasal_mobile/features/stock/presentation/stock_count_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'stock_fixtures.dart';

void main() {
  FakeApi countApi() => FakeApi()
    ..on(
      'GET',
      '/items',
      (q, b) => pagedJson([
        itemJson(id: 7, name: 'Rice 5kg', quantity: 12, sku: 'RICE-5'),
        itemJson(id: 8, name: 'Sugar 1kg', quantity: 3),
      ]),
    )
    ..on('GET', '/categories', (q, b) => pagedJson([]))
    ..on(
      'POST',
      '/stock-counts',
      (q, b) => {
        'data': [
          {'item_id': 7, 'item_name': 'Rice 5kg', 'system': 12, 'counted': 10, 'difference': -2},
        ],
        'items_changed': 1,
      },
    );

  testWidgets('loads the items, keeps the typed count as a draft and saves only the counted lines', (tester) async {
    final api = countApi();
    final container = await pumpApp(tester, const StockCountScreen(), api: api);

    expect(find.text('Rice 5kg'), findsOneWidget);
    expect(find.text('Sugar 1kg'), findsOneWidget);
    expect(find.text('System 12 pcs'), findsOneWidget);
    expect(find.text('Review count'), findsOneWidget);

    // TextFields: search (0), Rice count (1), Sugar count (2), note (3).
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.pumpAndSettle();

    expect(find.text('Review 1 differences'), findsOneWidget);
    expect(container.read(sharedPrefsProvider).getString(countDraftKey), contains('"7":"10"'));

    await tester.tap(find.text('Review 1 differences'));
    await tester.pumpAndSettle();
    expect(find.text('Check before saving'), findsOneWidget);
    expect(find.text('System 12 · counted 10'), findsOneWidget);

    await tester.tap(find.text('Save count'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /stock-counts'], [
      {
        'items': [
          {'item_id': 7, 'counted': 10},
        ],
      },
    ]);
    expect(api.keys['POST /stock-counts']!.single, isNotNull);
    expect(find.text('Count saved'), findsOneWidget);
    expect(find.text('1 items changed'), findsOneWidget);
    expect(container.read(sharedPrefsProvider).containsKey(countDraftKey), isFalse);
  });

  testWidgets('a count that is not a whole number blocks the review button', (tester) async {
    await pumpApp(tester, const StockCountScreen(), api: countApi());

    await tester.enterText(find.byType(TextField).at(1), '1.5');
    await tester.pumpAndSettle();

    expect(find.text('Counts must be whole numbers, 0 or more.'), findsOneWidget);
    await tester.tap(find.text('Review count'));
    await tester.pumpAndSettle();
    expect(find.text('Check before saving'), findsNothing);
  });
}
