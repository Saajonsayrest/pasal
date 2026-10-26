import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/features/stock/presentation/stock_history_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'stock_fixtures.dart';

Json _page({required List<Json> rows, String? next}) => {
      'item': {'id': 7, 'name': 'Rice 5kg', 'quantity': 12},
      'data': rows,
      'links': {'next': next, 'prev': null},
      'meta': {'current_page': 1, 'per_page': 30, 'total': rows.length},
    };

void main() {
  testWidgets('shows the item, its stock and every change, and filters by kind', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/items/7/stock-movements',
        (q, b) => _page(rows: [
          movementJson(id: 41, change: -3, reason: 'sale', refType: 'sale', refId: 9, by: 'Sita'),
          movementJson(id: 40, change: 10, reason: 'purchase', refType: 'purchase', refId: 4, by: 'Hari'),
          movementJson(id: 39, change: -1, reason: 'adjust', note: 'damaged', by: 'Asha'),
        ]),
      );

    await pumpApp(tester, const StockHistoryScreen(itemId: 7), api: api);

    expect(find.text('Rice 5kg'), findsOneWidget);
    expect(find.text('Stock now 12'), findsOneWidget);
    expect(find.text('Sale'), findsOneWidget);
    expect(find.text('Purchase'), findsOneWidget);
    expect(find.text('Adjusted by hand'), findsOneWidget);
    expect(find.text('-3'), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);

    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();

    expect(find.text('Sale'), findsOneWidget);
    expect(find.text('Purchase'), findsNothing);
    expect(find.text('Adjusted by hand'), findsNothing);
  });

  testWidgets('Load more asks for the next page and appends it', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/items/7/stock-movements',
        (q, b) => q?['page'] == 2
            ? _page(rows: [movementJson(id: 1, change: 5, reason: 'count')])
            : _page(rows: [movementJson(id: 2, change: -2, reason: 'sale')], next: 'more'),
      );

    await pumpApp(tester, const StockHistoryScreen(itemId: 7), api: api);
    expect(find.text('Stock count'), findsNothing);

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Stock count'), findsOneWidget);
    expect(find.text('Sale'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
    expect(api.calls, ['GET /items/7/stock-movements', 'GET /items/7/stock-movements']);
  });
}
