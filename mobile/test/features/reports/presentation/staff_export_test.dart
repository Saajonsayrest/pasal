import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/reports/data/csv.dart';
import 'package:pasal_mobile/features/reports/data/csv_share.dart';
import 'package:pasal_mobile/features/reports/data/range.dart';
import 'package:pasal_mobile/features/reports/presentation/export_screen.dart';
import 'package:pasal_mobile/features/reports/presentation/staff_sales_screen.dart';

import '../../../helpers/fake_api.dart';
import '../../../helpers/pump_app.dart';

Map<String, dynamic> _staff() => {
      'data': [
        {'user_id': 1, 'name': 'Asha Shrestha', 'bills': 80, 'sales': 11200000, 'discount': 0},
        {'user_id': 2, 'name': 'Bikash K.', 'bills': 52, 'sales': 4680000, 'discount': 50000},
        {'user_id': 3, 'name': 'Sunita M.', 'bills': 40, 'sales': 2820000, 'discount': 0},
      ],
    };

Map<String, dynamic> _sale() => {
      'id': 31,
      'bill_no': 'S-0031',
      'customer': null,
      'subtotal': 11300,
      'discount': 0,
      'total': 11300,
      'returned_total': 0,
      'paid': 5000,
      'balance': 6300,
      'cancelled_at': null,
      'vat_rate': 13,
      'taxable_amount': 10000,
      'vat_amount': 1300,
      'exempt_amount': 0,
      'sold_at': '2026-10-18T07:26:03+00:00',
      'sold_by': 'Asha',
    };

void main() {
  testWidgets('staff sales shows the total, the bills and each share', (tester) async {
    final api = FakeApi()..on('GET', '/reports/staff', (q, b) => _staff());

    await pumpApp(tester, const StaffSalesScreen(), api: api);

    expect(find.text('Rs 1,87,000'), findsOneWidget);
    expect(find.text('172 bills'), findsOneWidget);
    expect(find.text('Rs 1,12,000'), findsOneWidget);
    expect(find.text('60% of total sales'), findsOneWidget);
    expect(find.text('25% of total sales'), findsOneWidget);
    expect(find.text('Rs 500'), findsNWidgets(2)); // the total discount and Bikash's discount
  });

  testWidgets('export shares the picked list as a CSV file for the dates', (tester) async {
    final queries = <Map<String, Object?>?>[];
    final api = FakeApi()
      ..on('GET', '/sales', (q, b) {
        queries.add(q);
        return pagedJson([_sale()]);
      });
    final shared = <List<CsvFile>>[];

    await pumpApp(
      tester,
      const ExportScreen(),
      api: api,
      overrides: [
        csvSharerProvider.overrideWithValue((files) async => shared.add(files)),
      ],
    );

    await tester.tap(find.text('Share CSV'));
    await tester.pumpAndSettle();

    final month = rangeFor(RangePreset.month);
    expect(queries.single, containsPair('from', month.from));
    expect(queries.single, containsPair('to', month.to));

    expect(shared.length, 1);
    final file = shared.single.single;
    expect(file.name, startsWith('pasal-sales-'));
    expect(file.name, endsWith('.csv'));
    expect(file.text, contains('Bill no,Date (AD),Date (BS),Customer,Sold by,Subtotal'));
    expect(file.text, contains('S-0031,2026-10-18,"Kartik 1, 2083",,Asha,113,0,13,113,0,50,63,No'));
    expect(find.text('Done. Choose where to save or send the files.'), findsOneWidget);
  });
}
