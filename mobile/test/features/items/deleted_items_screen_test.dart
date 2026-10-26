import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/items/presentation/deleted_items_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'item_fixtures.dart';

void main() {
  testWidgets('lists deleted items and restores one', (tester) async {
    final api = FakeApi()
      ..on('GET', '/items', (q, b) => pagedJson([itemJson(name: 'Old Biscuit', categoryId: 1)]))
      ..on('GET', '/categories', (q, b) => pagedJson([categoryJson(1, 'Snacks')]))
      ..on('POST', '/items/7/restore', (q, b) => {'data': itemJson(name: 'Old Biscuit')});

    await pumpApp(tester, const DeletedItemsScreen(), api: api);

    expect(find.text('Old Biscuit'), findsOneWidget);
    expect(find.text('Snacks · Rs 115'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(api.calls, contains('POST /items/7/restore'));
    expect(find.text('Restored: Old Biscuit'), findsOneWidget);
  });
}
