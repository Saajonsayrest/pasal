import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/customers/presentation/customers_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _customer(int id, String name, int owes) => {
      'id': id,
      'name': name,
      'phone': '98000000$id',
      'address': null,
      'pan': null,
      'credit_limit': null,
      'owes': owes,
      'last_sale_at': null,
      'oldest_unpaid_at': null,
    };

void main() {
  testWidgets('shows the total to collect and each customer', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/customers',
        (q, b) => pagedJson(
          [_customer(1, 'Hari Thapa', 634000), _customer(2, 'Sita Gurung', 0)],
          summary: {'owed_total': 634000, 'owing_customers': 1},
        ),
      );

    await pumpApp(tester, const CustomersScreen(), api: api);

    expect(find.text('Rs 6,340'), findsNWidgets(2)); // the big number and Hari's row
    expect(find.text('Hari Thapa'), findsOneWidget);
    expect(find.text('Sita Gurung'), findsOneWidget);
    expect(find.text('Paid up'), findsWidgets);
  });

  testWidgets('shows an empty state and a retry on error', (tester) async {
    final api = FakeApi()..on('GET', '/customers', (q, b) => pagedJson([], summary: {'owed_total': 0, 'owing_customers': 0}));
    await pumpApp(tester, const CustomersScreen(), api: api);
    expect(find.text('No customers found'), findsOneWidget);
  });
}
