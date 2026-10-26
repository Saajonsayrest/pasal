import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/vat/presentation/vat_books_screen.dart';

import '../../../helpers/fake_api.dart';
import '../../../helpers/pump_app.dart';
import '../vat_fixtures.dart';

void main() {
  testWidgets('sales book lists the bills of the month with the totals', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/sales',
        (q, b) => pagedJson([
          saleJson(id: 31, billNo: 'S-0031', total: 11300, taxable: 10000, vat: 1300),
          saleJson(
            id: 32,
            billNo: 'S-0032',
            total: 2260,
            taxable: 2000,
            vat: 260,
            customer: {'id': 4, 'name': 'Hari', 'phone': null, 'address': null, 'pan': null},
          ),
        ]),
      );

    await pumpApp(tester, const VatBooksScreen(), api: api);

    expect(find.text('Showing 2 of 2 sales bills'), findsOneWidget);
    expect(find.text('S-0031 · Walk-in customer'), findsOneWidget);
    expect(find.text('S-0032 · Hari'), findsOneWidget);
    expect(find.text('135.60'), findsOneWidget); // total of both bills
    expect(find.text('15.60'), findsOneWidget); // VAT of both bills
  });

  testWidgets('purchase book lists the supplier bills with the VAT split', (tester) async {
    final api = FakeApi()
      ..on('GET', '/sales', (q, b) => pagedJson([]))
      ..on(
        'GET',
        '/purchases',
        (q, b) => pagedJson([
          purchaseJson(id: 12, billNo: 'INV-889', total: 1130000, vat: 130000, supplier: {'id': 3, 'name': 'Himal Traders', 'pan': '123456789'}),
        ]),
      );

    await pumpApp(tester, const VatBooksScreen(), api: api);
    await tester.tap(find.text('Purchase book'));
    await tester.pumpAndSettle();

    expect(find.text('INV-889 · Himal Traders'), findsOneWidget);
    expect(find.text('11,300.00'), findsWidgets); // the bill total and the totals line
    expect(find.text('10,000.00'), findsOneWidget); // taxable part without VAT
  });
}
