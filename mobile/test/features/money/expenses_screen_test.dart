import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/features/money/presentation/expenses_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';

void main() {
  testWidgets('shows the month total, the split by category and the rows', (tester) async {
    final today = todayAd();
    final api = FakeApi()
      ..on(
        'GET',
        '/expenses',
        (q, b) => pagedJson([
          {'id': 1, 'title': 'NEA electricity bill', 'category': 'bills', 'amount': 150000, 'spent_at': today},
          {'id': 2, 'title': 'Staff tea', 'category': 'Tea and snacks', 'amount': 30000, 'spent_at': today},
        ]),
      );

    await pumpApp(tester, const ExpensesScreen(), api: api);

    expect(find.text('Rs 1,800'), findsOneWidget);
    expect(find.text('2 entries'), findsOneWidget);
    expect(find.text('NEA electricity bill'), findsOneWidget);
    expect(find.text('Rs 1,500'), findsNWidgets(2));
    expect(find.text('Tea and snacks'), findsWidgets);
  });

  testWidgets('shows an empty state for a month with no expenses', (tester) async {
    final api = FakeApi()..on('GET', '/expenses', (q, b) => pagedJson([]));

    await pumpApp(tester, const ExpensesScreen(), api: api);

    expect(find.text('No expenses this month'), findsOneWidget);
  });

  testWidgets('shows the server message and a retry when loading fails', (tester) async {
    final api = FakeApi()..on('GET', '/expenses', (q, b) => throw ApiException(500, 'Server is busy.'));

    await pumpApp(tester, const ExpensesScreen(), api: api);

    expect(find.text('Server is busy.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
