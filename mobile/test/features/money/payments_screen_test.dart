import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/features/money/presentation/payments_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _payment(
  int id,
  String direction,
  String party,
  int amount, {
  int? saleId,
  int? purchaseId,
  String method = 'cash',
}) =>
    {
      'id': id,
      'direction': direction,
      'sale_id': saleId,
      'purchase_id': purchaseId,
      'amount': amount,
      'method': method,
      'paid_at': '2026-10-26T07:26:03+00:00',
      'party': party,
    };

void main() {
  testWidgets('shows the first page and loads the next one', (tester) async {
    final queries = <Query?>[];
    final api = FakeApi()
      ..on('GET', '/payments', (q, b) {
        queries.add(q);
        if (q!['page'] == 2) {
          return {
            'data': [_payment(3, 'in', 'Kiran Rai', 100000)],
            'meta': {'current_page': 2, 'last_page': 2, 'per_page': 30, 'total': 3},
          };
        }
        return {
          'data': [
            _payment(1, 'out', 'Annapurna Dairy', 250000, purchaseId: 87, method: 'bank'),
            _payment(2, 'in', 'Dipak Lama', 180000, saleId: 356),
          ],
          'meta': {'current_page': 1, 'last_page': 2, 'per_page': 30, 'total': 3},
        };
      });

    await pumpApp(tester, const PaymentsScreen(), api: api);

    expect(find.text('Annapurna Dairy'), findsOneWidget);
    expect(find.text('Dipak Lama'), findsOneWidget);
    expect(find.text('Showing 2 of 3 payments'), findsOneWidget);

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Kiran Rai'), findsOneWidget);
    expect(find.text('Showing 3 of 3 payments'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
    expect(queries.last!['page'], 2);
  });

  testWidgets('filters by direction from the first page again', (tester) async {
    final queries = <Query?>[];
    final api = FakeApi()
      ..on('GET', '/payments', (q, b) {
        queries.add(q);
        return {
          'data': [_payment(2, 'in', 'Dipak Lama', 180000, saleId: 356)],
          'meta': {'current_page': 1, 'last_page': 1, 'per_page': 30, 'total': 1},
        };
      });

    await pumpApp(tester, const PaymentsScreen(), api: api);
    await tester.tap(find.text('Out'));
    await tester.pumpAndSettle();

    expect(queries.last!['direction'], 'out');
    expect(queries.last!['page'], 1);
  });
}
