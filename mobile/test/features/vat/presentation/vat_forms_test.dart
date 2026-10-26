import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/features/vat/presentation/filing_details_screen.dart';
import 'package:pasal_mobile/features/vat/presentation/old_return_screen.dart';

import '../../../helpers/fake_api.dart';
import '../../../helpers/pump_app.dart';
import '../vat_fixtures.dart';

final _filingsRoute = GoRoute(path: '/vat/filings', builder: (_, _) => const Text('filings page'));

void main() {
  testWidgets('filing details shows the frozen numbers and saves the paid amount', (tester) async {
    final api = FakeApi()
      ..on('GET', '/vat/filings/3', (q, b) => {'data': filingJson(id: 3, period: '2083-06', payable: 520000)})
      ..on('PATCH', '/vat/filings/3', (q, b) => {'data': filingJson(id: 3, period: '2083-06', payable: 520000, paid: 50000)});

    await pumpApp(tester, const FilingDetailsScreen(id: 3), api: api, routes: [_filingsRoute]);

    expect(find.textContaining('Ashoj 2083'), findsOneWidget);
    expect(find.text('Rs 5,200.00'), findsWidgets);
    expect(find.text('Computed'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '500');
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(api.bodies['PATCH /vat/filings/3']!.single, {
      'filed_on': null,
      'paid_amount': 50000,
      'paid_on': null,
      'receipt_no': null,
      'note': null,
    });
    expect(find.text('filings page'), findsOneWidget);
  });

  testWidgets('old return saves the month before this one with the typed amounts in paisa', (tester) async {
    final api = FakeApi()..on('POST', '/vat/filings', (q, b) => {'data': filingJson(id: 4, period: 'x', source: 'manual')});

    await pumpApp(tester, const OldReturnScreen(), api: api, routes: [_filingsRoute]);

    final previous = shiftMonth(todayBs().year, todayBs().month, -1);
    final period = periodLabel(previous.year, previous.month);
    expect(find.text(period), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '1250.50');
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    final body = api.bodies['POST /vat/filings']!.single! as Map<String, Object?>;
    expect(body['manual'], true);
    expect(body['period'], period);
    expect(body['sales_taxable'], 125050);
    expect(body['payable'], 0);
    expect(api.keys['POST /vat/filings']!.single, isNotNull);
    expect(find.text('filings page'), findsOneWidget);
  });
}
