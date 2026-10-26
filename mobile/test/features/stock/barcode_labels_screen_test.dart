import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/stock/presentation/barcode_labels_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'stock_fixtures.dart';

void main() {
  testWidgets('ticks items, adds copies and previews one label per copy', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/items',
        (q, b) => pagedJson([
          itemJson(id: 7, name: 'Rice 5kg', sellPrice: 100000, sku: 'RICE-5'),
          itemJson(id: 8, name: 'Sugar 1kg', sellPrice: 12000),
        ]),
      );
    await pumpApp(tester, const BarcodeLabelsScreen(), api: api);

    expect(find.text('Rice 5kg'), findsOneWidget);
    expect(find.text('Share label list as text'), findsOneWidget);
    expect(find.text('Tick items above to make labels.'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('1 labels'), findsOneWidget);

    await tester.tap(find.byTooltip('More copies'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More copies'));
    await tester.pumpAndSettle();

    expect(find.text('3 labels'), findsOneWidget);
    expect(find.text('Rs 1,000'), findsNWidgets(3));
    expect(find.text('RICE-5'), findsNWidgets(3));
    expect(find.text('Himal Kirana Pasal'), findsNWidgets(3));
  });
}
