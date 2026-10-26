import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/features/selling/presentation/cancel_sale_screen.dart';
import 'package:pasal_mobile/features/selling/presentation/sale_details_screen.dart';
import 'package:pasal_mobile/features/selling/presentation/sale_return_screen.dart';
import 'package:pasal_mobile/features/selling/presentation/sales_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'selling_fixtures.dart';

void main() {
  testWidgets('the sales list shows the net total and each bill', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/sales',
        (q, b) => pagedJson([
          saleJson(customer: customerJson()),
          saleJson(id: 32, billNo: 'S-0032', total: 5000, paid: 5000, balance: 0),
        ]),
      );

    await pumpApp(tester, const SalesScreen(), api: api);

    expect(find.text('Rs 163'), findsOneWidget);
    expect(find.text('Hari'), findsOneWidget);
    expect(find.text('Walk-in customer'), findsOneWidget);
    expect(find.text('To collect Rs 63'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
  });

  testWidgets('sale details lists the payments and takes a payment for the balance', (tester) async {
    final api = FakeApi()
      ..on('GET', '/sales/31', (q, b) => {'data': saleJson(customer: customerJson(), payments: [paymentJson(amount: 5000)])})
      ..on('POST', '/payments', (q, b) => {'data': paymentJson(amount: 6300), 'balance_left': 0});

    await pumpApp(tester, const SaleDetailsScreen(saleId: 31), api: api);

    expect(find.text('Received · Cash'), findsOneWidget);

    await tester.tap(find.text('Take payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /payments']!.single, {'sale_id': 31, 'amount': 6300, 'method': 'cash'});
    expect(api.keys['POST /payments']!.single, isNotNull);
  });

  testWidgets('owner returns one item and the return is sent with the key', (tester) async {
    final api = FakeApi()
      ..on('GET', '/sales/31', (q, b) => {'data': saleJson(customer: customerJson(), items: [lineJson(qty: 2, price: 5650)])})
      ..on('POST', '/sales/31/returns', (q, b) => {'data': returnJson(total: 5650), 'sale_balance': 5650, 'sale_cancelled': false});

    await pumpApp(
      tester,
      const SaleReturnScreen(saleId: 31),
      api: api,
      routes: [GoRoute(path: '/sales/:id', builder: (_, _) => const Text('details page'))],
    );

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Rs 56.50'), findsWidgets);

    await tester.tap(find.text('Save return'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /sales/31/returns']!.single, {
      'items': [
        {'sale_item_id': 52, 'quantity': 1},
      ],
      'restock': true,
    });
    expect(api.keys['POST /sales/31/returns']!.single, isNotNull);
    expect(find.text('details page'), findsOneWidget);
  });

  testWidgets('owner cancels a sale only after a reason and the confirm switch', (tester) async {
    final api = FakeApi()
      ..on('GET', '/sales/31', (q, b) => {'data': saleJson(customer: customerJson(), items: [lineJson(qty: 1)])})
      ..on('POST', '/sales/31/cancel', (q, b) => {'data': returnJson(refunded: 5000, kind: 'cancel'), 'sale_balance': 0, 'sale_cancelled': true});

    await pumpApp(
      tester,
      const CancelSaleScreen(saleId: 31),
      api: api,
      routes: [GoRoute(path: '/sales/:id', builder: (_, _) => const Text('details page'))],
    );

    final cancelButton = find.widgetWithText(FilledButton, 'Cancel sale');
    await tester.enterText(find.byType(TextField), 'Customer left');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(cancelButton).onPressed, isNull);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    expect(api.bodies['POST /sales/31/cancel']!.single, {'restock': true, 'note': 'Customer left'});
    expect(api.keys['POST /sales/31/cancel']!.single, isNotNull);
    expect(find.text('details page'), findsOneWidget);
  });
}
