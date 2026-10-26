import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/reports/presentation/reports_screen.dart';
import 'package:pasal_mobile/features/reports/presentation/sales_chart_screen.dart';

import '../../../helpers/fake_api.dart';
import '../../../helpers/pump_app.dart';

Map<String, dynamic> _summary() => {
      'from': '2026-10-01',
      'to': '2026-10-31',
      'sales_total': 10000000,
      'vat_collected': 1300000,
      'cost_of_goods': 6000000,
      'expenses_total': 500000,
      'profit': 2200000,
      'stock_value': 38400000,
      'owed_to_us': 8642000,
      'we_owe': 12400000,
    };

void main() {
  testWidgets('reports home loads the profit, the stock and the money to collect', (tester) async {
    final queries = <Map<String, Object?>?>[];
    final api = FakeApi()
      ..on('GET', '/reports/summary', (q, b) {
        queries.add(q);
        return _summary();
      });

    await pumpApp(tester, const ReportsScreen(), api: api);

    expect(queries.single, containsPair('from', isA<String>()));
    expect(find.text('Rs 22,000'), findsNWidgets(2)); // the big profit and the last line
    expect(find.text('Rs 3,84,000'), findsOneWidget);
    expect(find.text('Rs 86,420'), findsOneWidget);
    expect(find.text('Rs 1,24,000'), findsOneWidget);
    expect(find.text('Minus VAT collected'), findsOneWidget);
    expect(find.text('Sales chart'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
  });

  testWidgets('sales chart draws a bar per day and shows the picked day', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/reports/daily',
        (q, b) => {
          'from': '2026-10-01',
          'to': '2026-10-31',
          'total': 2000000,
          'bills': 6,
          'days': [
            {'date': '2026-10-17', 'bills': 2, 'sales': 500000},
            {'date': '2026-10-18', 'bills': 3, 'sales': 1200000},
            {'date': '2026-10-19', 'bills': 1, 'sales': 300000},
          ],
          'hours': [
            {'hour': 10, 'bills': 2, 'sales': 800000},
            {'hour': 17, 'bills': 4, 'sales': 1200000},
          ],
        },
      );

    await pumpApp(tester, const SalesChartScreen(), api: api);

    expect(find.text('Sales per day'), findsOneWidget);
    expect(find.text('Rs 20,000'), findsOneWidget);
    expect(find.text('Best day'), findsOneWidget);
    expect(find.text('Busiest: 5pm'), findsOneWidget);

    expect(find.text('Rs 3,000'), findsNWidgets(2)); // the last day is picked at first: its total and its average bill

    await tester.tap(find.text('17'));
    await tester.pumpAndSettle();

    expect(find.text('Rs 5,000'), findsOneWidget);
    expect(find.text('Rs 3,000'), findsNothing);
    expect(find.text('Rs 12,000'), findsOneWidget); // the best day
  });
}
