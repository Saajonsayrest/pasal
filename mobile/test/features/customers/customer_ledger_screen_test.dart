import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/customers/presentation/customer_ledger_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'customer_fixtures.dart';

void main() {
  testWidgets('shows what is owed, the credit limit warning and each bill and payment', (tester) async {
    final api = FakeApi()..on('GET', '/customers/4/ledger', (q, b) => ledgerJson());

    await pumpApp(tester, const CustomerLedgerScreen(customerId: 4), api: api, size: testCanvas);

    expect(find.text('Rs 15,000'), findsOneWidget);
    expect(find.text('Over the credit limit by Rs 5,000.'), findsOneWidget);
    expect(find.text('Given on credit'), findsNWidgets(2));
    expect(find.text('Rs 11,300'), findsOneWidget);
    expect(find.text('Rs 8,700'), findsOneWidget);
    expect(find.text('Received · Cash'), findsOneWidget);
    expect(find.text('Hari Thapa'), findsOneWidget);
  });

  testWidgets('the Received filter hides the bills', (tester) async {
    final api = FakeApi()..on('GET', '/customers/4/ledger', (q, b) => ledgerJson());
    await pumpApp(tester, const CustomerLedgerScreen(customerId: 4), api: api, size: testCanvas);

    await tester.tap(find.text('Received'));
    await tester.pumpAndSettle();

    expect(find.text('Given on credit'), findsNothing);
    expect(find.text('Received · Cash'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no bills or payments', (tester) async {
    final empty = ledgerJson()
      ..['sales'] = <Object>[]
      ..['payments'] = <Object>[]
      ..['owes'] = 0;
    final api = FakeApi()..on('GET', '/customers/4/ledger', (q, b) => empty);

    await pumpApp(tester, const CustomerLedgerScreen(customerId: 4), api: api, size: testCanvas);

    expect(find.text('No bills or payments yet'), findsOneWidget);
  });
}
