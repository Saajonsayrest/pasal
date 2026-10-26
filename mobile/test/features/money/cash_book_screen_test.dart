import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/features/money/presentation/cash_book_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';

FakeApi _cashApi(String at) => FakeApi()
  ..on(
    'GET',
    '/cash-book',
    (q, b) => {
      'from': q!['from'],
      'to': q['to'],
      'opening_balance': 500000,
      'money_in': 200000,
      'money_out': 50000,
      'closing_balance': 650000,
      'data': [
        {'kind': 'payment_in', 'id': 1, 'at': at, 'amount': 200000, 'method': 'cash', 'label': 'Hari Thapa', 'balance': 700000},
        {'kind': 'expense', 'id': 2, 'at': at, 'amount': -50000, 'method': 'cash', 'label': 'Electricity', 'balance': 650000},
      ],
      'meta': {'current_page': 1, 'per_page': 100, 'total': 2},
    },
  );

void main() {
  testWidgets('shows the expected drawer cash and the entries of the day', (tester) async {
    final api = _cashApi(DateTime.now().toUtc().toIso8601String());

    await pumpApp(tester, const CashBookScreen(), api: api);

    expect(find.text('Rs 6,500'), findsNWidgets(2));
    expect(find.text('Hari Thapa'), findsOneWidget);
    expect(find.text('Electricity'), findsOneWidget);
  });

  testWidgets('saves the counted cash for the day with the difference', (tester) async {
    final api = _cashApi(DateTime.now().toUtc().toIso8601String());

    final container = await pumpApp(tester, const CashBookScreen(), api: api);
    await tester.enterText(find.byType(TextField), '6400');
    await tester.pump();

    expect(find.text('Rs 100 short'), findsOneWidget);

    await tester.tap(find.text('Save count'));
    await tester.pumpAndSettle();

    final prefs = container.read(sharedPrefsProvider);
    expect(prefs.getString('pasal_cash_count_${todayAd()}'), '{"counted":640000,"expected":650000}');
  });
}
