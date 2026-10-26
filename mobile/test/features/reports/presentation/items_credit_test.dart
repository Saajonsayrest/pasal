import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/reports/presentation/credit_age_screen.dart';
import 'package:pasal_mobile/features/reports/presentation/top_items_screen.dart';

import '../../../helpers/fake_api.dart';
import '../../../helpers/pump_app.dart';

Map<String, dynamic> _itemsReport() => {
      'top': [
        {'item_id': 7, 'name': 'Rice 5kg', 'unit': 'pcs', 'quantity': 30, 'revenue': 3150000},
        {'item_id': 8, 'name': 'Tea leaves 500g', 'unit': 'pcs', 'quantity': 74, 'revenue': 2072000},
      ],
      'slow': [
        {'item_id': 9, 'name': 'Toothpaste', 'unit': 'pcs', 'in_stock': 22, 'sold': 0, 'stock_value': 319000},
        {'item_id': 10, 'name': 'Bath soap', 'unit': 'pcs', 'in_stock': 48, 'sold': 5, 'stock_value': 288000},
      ],
    };

Map<String, dynamic> _creditAge() => {
      'as_of': '2026-10-26',
      'total': 8642000,
      'buckets': [
        {'key': 'd0_30', 'label': '0 to 30 days', 'bills': 3, 'amount': 4182000},
        {'key': 'd31_60', 'label': '31 to 60 days', 'bills': 2, 'amount': 2600000},
        {'key': 'd61_90', 'label': '61 to 90 days', 'bills': 1, 'amount': 1280000},
        {'key': 'd90_plus', 'label': 'Over 90 days', 'bills': 2, 'amount': 580000},
      ],
      'customers': [
        {'customer_id': 1, 'name': 'Kiran Rai', 'phone': null, 'owes': 960000, 'oldest_days': 12, 'bucket': 'd0_30'},
        {'customer_id': 2, 'name': 'Hari Thapa', 'phone': '9800000001', 'owes': 300000, 'oldest_days': 45, 'bucket': 'd31_60'},
        {'customer_id': 3, 'name': 'Ram Bahadur KC', 'phone': null, 'owes': 1280000, 'oldest_days': 70, 'bucket': 'd61_90'},
      ],
    };

void main() {
  testWidgets('top items sorts by money, then by quantity', (tester) async {
    final api = FakeApi()..on('GET', '/reports/items', (q, b) => _itemsReport());

    await pumpApp(tester, const TopItemsScreen(), api: api);

    expect(find.text('Rs 31,500'), findsOneWidget);
    expect(find.text('30 pcs sold'), findsOneWidget);
    final riceFirst = tester.getCenter(find.text('Rice 5kg')).dy < tester.getCenter(find.text('Tea leaves 500g')).dy;
    expect(riceFirst, isTrue);

    await tester.tap(find.text('By quantity'));
    await tester.pumpAndSettle();

    final teaFirst = tester.getCenter(find.text('Tea leaves 500g')).dy < tester.getCenter(find.text('Rice 5kg')).dy;
    expect(teaFirst, isTrue);
  });

  testWidgets('slow items shows the stuck stock value and the items not sold', (tester) async {
    final api = FakeApi()..on('GET', '/reports/items', (q, b) => _itemsReport());

    await pumpApp(tester, const TopItemsScreen(), api: api);
    await tester.tap(find.text('Slow items'));
    await tester.pumpAndSettle();

    expect(find.text('Rs 6,070'), findsOneWidget);
    expect(find.text('Not sold'), findsOneWidget);
    expect(find.text('Toothpaste'), findsOneWidget);
    expect(find.text('Bath soap'), findsOneWidget);
  });

  testWidgets('credit age shows the groups and filters the list by a group', (tester) async {
    final api = FakeApi()..on('GET', '/reports/credit-age', (q, b) => _creditAge());

    await pumpApp(tester, const CreditAgeScreen(), api: api);

    expect(find.text('Rs 86,420'), findsOneWidget);
    expect(find.text('Kiran Rai'), findsOneWidget);
    expect(find.text('Ram Bahadur KC'), findsOneWidget);

    await tester.tap(find.text('61 to 90 days'));
    await tester.pumpAndSettle();

    expect(find.text('Kiran Rai'), findsNothing);
    expect(find.text('Ram Bahadur KC'), findsOneWidget);
    expect(find.text('Rs 12,800'), findsWidgets); // the group total and his one row
  });
}
