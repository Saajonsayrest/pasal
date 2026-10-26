import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/features/vat/presentation/vat_filings_screen.dart';
import 'package:pasal_mobile/features/vat/presentation/vat_screen.dart';

import '../../../helpers/fake_api.dart';
import '../../../helpers/pump_app.dart';
import '../vat_fixtures.dart';

final _filingsRoute = GoRoute(path: '/vat/filings', builder: (_, _) => const Text('filings page'));

void main() {
  testWidgets('VAT this month loads the numbers and saves the month with the right body', (tester) async {
    final today = todayBs();
    final period = periodLabel(today.year, today.month);
    final range = bsMonthRange(today.year, today.month);
    Map<String, Object?>? previewQuery;
    final api = FakeApi()
      ..on('GET', '/vat/preview', (q, b) {
        previewQuery = q;
        return previewJson();
      })
      ..on('GET', '/vat/filings', (q, b) => pagedJson([]))
      ..on('POST', '/vat/filings', (q, b) => {'data': filingJson(id: 9, period: period)});

    await pumpApp(tester, const VatScreen(), api: api, routes: [_filingsRoute]);

    expect(previewQuery?['from'], range.from);
    expect(previewQuery?['to'], range.to);
    expect(find.text('Rs 5,200.00'), findsNWidgets(2)); // the big number and the payable line
    expect(find.text('Rs 11,700.00'), findsOneWidget); // output VAT

    await tester.ensureVisible(find.byType(PrimaryButton));
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /vat/filings']!.single, {'period': period, 'from': range.from, 'to': range.to, 'opening_carry': 0});
    expect(api.keys['POST /vat/filings']!.single, isNotNull);
    expect(find.text('filings page'), findsOneWidget);
  });

  testWidgets('VAT filings lists each saved month and the total still to pay', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/vat/filings',
        (q, b) => pagedJson([
          filingJson(id: 1, period: '2083-06', payable: 520000),
          filingJson(id: 2, period: '2083-05', payable: 624000, paid: 624000, filedOn: '2026-09-30'),
        ]),
      );

    await pumpApp(tester, const VatFilingsScreen(), api: api, routes: [GoRoute(path: '/vat/filings/:id', builder: (_, _) => const Text('detail'))]);

    expect(find.text('Ashoj 2083'), findsOneWidget);
    expect(find.text('Bhadra 2083'), findsOneWidget);
    expect(find.text('Rs 5,200.00'), findsNWidgets(2)); // the still to pay total and Ashoj's amount
    expect(find.text('Rs 6,240.00'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);

    await tester.tap(find.text('Filed'));
    await tester.pump();
    expect(find.text('Ashoj 2083'), findsNothing);
    expect(find.text('Bhadra 2083'), findsOneWidget);
  });
}
