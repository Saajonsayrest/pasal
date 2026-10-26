import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/features/home/data/home_prefs.dart';
import 'package:pasal_mobile/features/home/presentation/home_screen.dart';
import 'package:pasal_mobile/features/home/presentation/more_screen.dart';
import 'package:pasal_mobile/features/home/presentation/notifications_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';
import 'home_fixtures.dart';

/// Every answer the owner home asks for. The daily report is one path, told apart by its dates.
FakeApi _ownerApi() {
  final today = todayAd();
  final weekFrom = addDaysAd(today, -13);
  return FakeApi()
    ..on('GET', '/reports/daily', (q, b) {
      if (q!['from'] == q['to']) return {'days': [], 'hours': [], 'total': 125000, 'bills': 3};
      final days = [for (var i = 0; i < 14; i++) {'date': addDaysAd(weekFrom, i), 'bills': 1, 'sales': 10000 * (i + 1)}];
      return {'days': days, 'hours': [], 'total': 0, 'bills': 0};
    })
    ..on('GET', '/cash-book', (q, b) => {'money_in': 50000, 'data': [], 'meta': {'total': 0}})
    ..on('GET', '/customers', (q, b) => pagedJson([], summary: {'owed_total': 634000, 'owing_customers': 2}))
    ..on('GET', '/suppliers', (q, b) => pagedJson([], summary: {'owed_total': 0}))
    ..on('GET', '/items', (q, b) => pagedWithTotal([], 4))
    ..on('GET', '/reports/summary', (q, b) => summaryJson(sales: 1000000, profit: 200000, cost: 700000, expenses: 100000))
    ..on('GET', '/vat/preview', (q, b) => vatPreviewJson(payable: 520000))
    ..on(
      'GET',
      '/sales',
      (q, b) => pagedJson([saleJson(id: 31, customer: 'Hari Thapa', total: 11300, paid: 5000, soldBy: 'Asha Shrestha')]),
    );
}

void main() {
  testWidgets('owner home shows today, money owed both ways, VAT, the week and profit', (tester) async {
    await pumpApp(tester, const HomeScreen(), api: _ownerApi());

    expect(find.text("Today's sales"), findsOneWidget);
    expect(find.text('Rs 1,250'), findsOneWidget);
    expect(find.text('Money received today'), findsOneWidget);
    expect(find.text('Rs 500'), findsOneWidget);
    expect(find.text('To collect'), findsOneWidget);
    expect(find.text('Rs 6,340'), findsOneWidget);
    expect(find.text('from 2 customers'), findsOneWidget);
    expect(find.text('Rs 5,200'), findsOneWidget);
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('Rs 7,700'), findsOneWidget);
    expect(find.text('Profit this month'), findsOneWidget);
    expect(find.text('Profit · Rs 2,000'), findsOneWidget);
    expect(find.text('Recent sales'), findsOneWidget);
    expect(find.text('Hari Thapa'), findsOneWidget);
    expect(find.text('Credit'), findsOneWidget);
  });

  testWidgets('staff home shows own sales, customers to remind and low stock, but no profit or owner cards', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/sales',
        (q, b) => pagedJson([
          saleJson(id: 1, total: 11300, customer: 'Sita Gurung', paid: 5000, soldBy: 'Asha Shrestha'),
          saleJson(id: 2, total: 7000, soldBy: 'Ram Karki'),
        ]),
      )
      ..on(
        'GET',
        '/customers',
        (q, b) => pagedJson([customerJson(1, 'Hari Thapa', 634000)]),
      )
      ..on(
        'GET',
        '/items',
        (q, b) => pagedWithTotal([itemJson(id: 7, name: 'Rice 5kg', quantity: 2)], 1),
      );

    await pumpApp(tester, const HomeScreen(), api: api, owner: false);

    expect(find.text('For the next customer'), findsOneWidget);
    expect(find.text('Total amount'), findsOneWidget);
    expect(find.text('Rs 113'), findsWidgets);
    expect(find.text('Customers to remind'), findsOneWidget);
    expect(find.text('Hari Thapa'), findsOneWidget);
    expect(find.text('Rice 5kg'), findsOneWidget);
    expect(find.text('Profit this month'), findsNothing);
    expect(find.text('We owe'), findsNothing);
    expect(api.calls.contains('GET /reports/summary'), isFalse);
  });

  testWidgets('notifications list the server rows, filter them, and mark all as read', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/notifications',
        (q, b) => {
          'data': [
            {'type': 'low_stock', 'title': 'Sugar is low on stock', 'body': 'Only 2 kg left', 'at': DateTime.now().toUtc().toIso8601String()},
            {'type': 'credit_overdue', 'title': 'Hari owes for 40 days', 'body': 'Rs 6,340 not paid', 'at': '2026-01-01T00:00:00+05:45'},
          ],
        },
      )
      ..on('GET', '/vat/preview', (q, b) => vatPreviewJson(payable: 520000));

    final container = await pumpApp(tester, const NotificationsScreen(), api: api);

    expect(find.text('Sugar is low on stock'), findsOneWidget);
    expect(find.text('Hari owes for 40 days'), findsOneWidget);

    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    expect(find.text('Sugar is low on stock'), findsNothing);
    expect(find.text('Hari owes for 40 days'), findsOneWidget);

    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(find.text('All marked as read'), findsOneWidget);
    expect(container.read(notificationSeenProvider), isNotNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('more shows every group to the owner', (tester) async {
    await pumpApp(tester, const MoreScreen(), api: FakeApi());
    expect(find.text('Purchases'), findsOneWidget);
    expect(find.text('Sales list'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('more hides the owner links from staff and marks the printer as later', (tester) async {
    await pumpApp(tester, const MoreScreen(), api: FakeApi(), owner: false);
    expect(find.text('Purchases'), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Sales list'), findsOneWidget);
    expect(find.text('App look and language'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });
}
