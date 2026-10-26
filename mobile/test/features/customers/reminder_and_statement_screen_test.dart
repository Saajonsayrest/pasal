import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/customers/presentation/reminder_screen.dart';
import 'package:pasal_mobile/features/customers/presentation/statement_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'customer_fixtures.dart';

void main() {
  testWidgets('the reminder writes the balance into the English message', (tester) async {
    final api = FakeApi()..on('GET', '/customers/4', (q, b) => {'data': customerJson(owes: 1500000)});
    await pumpApp(tester, const ReminderScreen(customerId: 4), api: api, size: testCanvas);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.controller!.text,
      'Namaste Hari Thapa ji. This is a reminder from Himal Kirana Pasal. Your balance is Rs 15,000. Please pay when you can.',
    );
    expect(find.text('WhatsApp'), findsOneWidget);
  });

  testWidgets('switching to Nepali writes the message in Nepali with Nepali digits', (tester) async {
    final api = FakeApi()..on('GET', '/customers/4', (q, b) => {'data': customerJson(owes: 1500000)});
    await pumpApp(tester, const ReminderScreen(customerId: 4), api: api, size: testCanvas);

    await tester.tap(find.text('नेपाली'));
    await tester.pumpAndSettle();

    final text = tester.widget<TextField>(find.byType(TextField)).controller!.text;
    expect(text, startsWith('नमस्ते Hari Thapa जी।'));
    expect(text, contains('तपाईंको रु १५,००० बाँकी छ।'));
  });

  testWidgets('a sent WhatsApp reminder shows the sent tick', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async => call.method == 'launch' ? true : null,
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ));

    final api = FakeApi()..on('GET', '/customers/4', (q, b) => {'data': customerJson(owes: 1500000)});
    await pumpApp(tester, const ReminderScreen(customerId: 4), api: api, size: testCanvas);

    expect(find.textContaining('Marked as sent'), findsNothing);
    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.textContaining('WhatsApp: Marked as sent on'), findsOneWidget);
  });

  testWidgets('the statement shows every line with the running balance for All', (tester) async {
    final api = FakeApi()..on('GET', '/customers/4/ledger', (q, b) => ledgerJson());
    await pumpApp(tester, const StatementScreen(customerId: 4), api: api, size: testCanvas);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Sale S-0031'), findsOneWidget);
    expect(find.text('Paid Cash for S-0031'), findsOneWidget);
    expect(find.text('Sale S-0032'), findsOneWidget);
    expect(find.text('Rs 20,000'), findsOneWidget);
    expect(find.text('Rs 5,000'), findsNWidgets(2)); // the payment line and the total received
    expect(find.text('Rs 15,000'), findsOneWidget);
    expect(find.textContaining('latest 200'), findsNothing);
    expect(find.text('Share'), findsOneWidget);
  });
}
