import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/features/suppliers/presentation/new_purchase_screen.dart';
import 'package:pasal_mobile/features/suppliers/presentation/pay_supplier_screen.dart';
import 'package:pasal_mobile/features/suppliers/presentation/purchases_screen.dart';
import 'package:pasal_mobile/features/suppliers/presentation/supplier_form_screen.dart';
import 'package:pasal_mobile/features/suppliers/presentation/suppliers_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'suppliers_fixtures.dart';

void main() {
  testWidgets('the suppliers list shows what we owe and each supplier', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/suppliers',
        (q, b) => pagedJson(
          [supplierJson(3, 'Himal Traders', weOwe: 630000, phone: '9800000003'), supplierJson(4, 'Sita Traders', weOwe: 0)],
          summary: {'owed_total': 634000},
        ),
      );

    await pumpApp(tester, const SuppliersScreen(), api: api);

    expect(find.text('Rs 6,340'), findsOneWidget);
    expect(find.text('Himal Traders'), findsOneWidget);
    expect(find.text('Sita Traders'), findsOneWidget);
    expect(find.text('Rs 6,300'), findsOneWidget);
    expect(find.text('Paid up'), findsOneWidget);
  });

  testWidgets('the purchases list shows this month, what we owe and each bill', (tester) async {
    final api = FakeApi()
      ..on('GET', '/purchases', (q, b) => pagedJson([purchaseJson(12, billNo: 'INV-889', total: 1130000, paid: 500000)]));

    await pumpApp(tester, const PurchasesScreen(), api: api);

    expect(find.text('Rs 11,300'), findsNWidgets(2)); // this month's card and the bill row
    expect(find.text('Rs 6,300'), findsOneWidget); // still to pay
    expect(find.textContaining('INV-889'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('a new supplier is saved with the typed name and empty optional fields', (tester) async {
    final api = FakeApi()..on('POST', '/suppliers', (q, b) => {'data': supplierJson(9, 'Everest Traders')});

    await pumpApp(
      tester,
      const SupplierFormScreen(),
      api: api,
      routes: [GoRoute(path: '/suppliers/:id', builder: (_, _) => const Text('ledger page'))],
    );
    await tester.enterText(find.byType(TextField).first, 'Everest Traders');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /suppliers']!.single, {
      'name': 'Everest Traders',
      'phone': null,
      'address': null,
      'pan': null,
      'note': null,
    });
    expect(find.text('ledger page'), findsOneWidget);
  });

  testWidgets('save stays off until a supplier and an item are chosen', (tester) async {
    final api = FakeApi()..on('GET', '/suppliers', (q, b) => pagedJson([]));

    await pumpApp(tester, const NewPurchaseScreen(), api: api);

    final button = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Save purchase'), matching: find.byWidgetPredicate((w) => w is FilledButton)),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Pick a supplier'), findsOneWidget);
  });

  testWidgets('a purchase from a ledger link is saved with its items and the bill date', (tester) async {
    final api = FakeApi()
      ..on('GET', '/suppliers', (q, b) => pagedJson([supplierJson(3, 'Himal Traders', weOwe: 630000)]))
      ..on('GET', '/items/7', (q, b) => {'data': itemJson(7, 'Rice 5kg')})
      ..on('POST', '/purchases', (q, b) => {'data': purchaseJson(12, total: 1000000, paid: 0)});

    await pumpApp(
      tester,
      const NewPurchaseScreen(supplierId: 3, prefillItems: '7:100'),
      api: api,
      routes: [GoRoute(path: '/purchases/:id', builder: (_, _) => const Text('bill page'))],
    );

    expect(find.text('Rice 5kg'), findsOneWidget);
    expect(find.text('Himal Traders'), findsOneWidget);

    await tester.tap(find.text('Save purchase'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /purchases']!.single, {
      'supplier_id': 3,
      'bill_no': null,
      'bill_date': todayAd(),
      'vat_amount': 0,
      'paid': 0,
      'method': 'cash',
      'note': null,
      'items': [
        {'item_id': 7, 'quantity': 100, 'unit_cost': 10000},
      ],
    });
    expect(api.keys['POST /purchases']!.single, isNotNull);
    expect(find.text('bill page'), findsOneWidget);
  });

  testWidgets('paying a supplier shows the oldest bill first and sends the whole amount', (tester) async {
    final api = FakeApi()
      ..on('GET', '/suppliers/3/ledger', (q, b) => ledgerJson())
      ..on('POST', '/payments', (q, b) => {'data': <Object>[], 'owes_left': 0});

    await pumpApp(
      tester,
      const PaySupplierScreen(id: 3),
      api: api,
      routes: [GoRoute(path: '/suppliers/:id', builder: (_, _) => const Text('ledger page'))],
    );

    expect(find.text('Rs 11,300'), findsWidgets);
    expect(find.text('INV-700'), findsWidgets); // the oldest bill, first in the list
    expect(find.text('Rs 5,000 paid off'), findsOneWidget);

    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /payments']!.single, {'supplier_id': 3, 'amount': 1130000, 'method': 'cash'});
    expect(api.keys['POST /payments']!.single, isNotNull);
    expect(find.text('ledger page'), findsOneWidget);
  });
}
