import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/features/money/presentation/add_expense_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';

void main() {
  testWidgets('saves the typed amount, title and date, then goes back to the list', (tester) async {
    final api = FakeApi()
      ..on(
        'POST',
        '/expenses',
        (q, b) => {
          'data': {'id': 7, 'title': 'Electricity', 'category': 'bills', 'amount': 150000, 'spent_at': todayAd()},
        },
      );

    await pumpApp(
      tester,
      const AddExpenseScreen(),
      api: api,
      routes: [GoRoute(path: '/expenses', builder: (_, _) => const Text('Expenses list'))],
    );

    // The amount display also shows "0", so only the keypad buttons are tapped. The pause stops
    // flutter_test from reading two quick taps as one double tap.
    for (final key in ['1', '5', '0', '0']) {
      await tester.tap(find.descendant(of: find.byType(InkWell), matching: find.text(key)).first);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.enterText(find.byType(TextField).first, 'Electricity');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /expenses']!.single, {
      'title': 'Electricity',
      'category': null,
      'amount': 150000,
      'spent_at': todayAd(),
    });
    expect(api.keys['POST /expenses']!.single, isNotNull);
    expect(find.text('Expenses list'), findsOneWidget);
  });

  testWidgets('asks for an amount and a title before it sends anything', (tester) async {
    final api = FakeApi();

    await pumpApp(tester, const AddExpenseScreen(), api: api);
    await tester.tap(find.text('Save expense'));
    await tester.pump();

    expect(find.text('Type the amount in rupees'), findsOneWidget);
    expect(find.text('Write what it was for'), findsOneWidget);
    expect(api.calls, isEmpty);
  });
}
