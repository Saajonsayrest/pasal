import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/settings/presentation/shop_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _business({double vat = 13.0}) => {
      'id': 1,
      'name': 'Himal Kirana Pasal',
      'pan': '600000001',
      'phone': '01-0000000',
      'address': 'Baneshwor, Kathmandu',
      'vat_rate': vat,
    };

/// The text in the Nth field of the form (0 is the shop name, 4 is the VAT rate).
String _fieldText(WidgetTester tester, int index) => tester.widget<EditableText>(find.byType(EditableText).at(index)).controller.text;

void main() {
  testWidgets('loads the shop details into the form', (tester) async {
    final api = FakeApi()..on('GET', '/business', (q, b) => {'data': _business()});
    await pumpApp(tester, const ShopScreen(), api: api);

    expect(_fieldText(tester, 0), 'Himal Kirana Pasal');
    expect(_fieldText(tester, 1), '600000001');
    expect(_fieldText(tester, 4), '13');
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('saves the new VAT rate with the whole form, then refreshes the session', (tester) async {
    final api = FakeApi()
      ..on('GET', '/business', (q, b) => {'data': _business()})
      ..on('PATCH', '/business', (q, b) => {'data': _business(vat: 18)})
      ..on(
        'GET',
        '/me',
        (q, b) => {
          'id': 1,
          'name': 'Asha Shrestha',
          'email': 'asha@example.com',
          'role': 'owner',
          'business': _business(vat: 18),
        },
      );
    await pumpApp(tester, const ShopScreen(), api: api);

    await tester.enterText(find.byType(TextField).at(4), '18');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.bodies['PATCH /business']!.single, {
      'name': 'Himal Kirana Pasal',
      'pan': '600000001',
      'phone': '01-0000000',
      'address': 'Baneshwor, Kathmandu',
      'vat_rate': 18.0,
    });
    expect(api.calls, contains('GET /me'));
    expect(find.text('Shop details saved'), findsOneWidget);
  });

  testWidgets('a VAT rate above 100 is refused before anything is sent', (tester) async {
    final api = FakeApi()..on('GET', '/business', (q, b) => {'data': _business()});
    await pumpApp(tester, const ShopScreen(), api: api);

    await tester.enterText(find.byType(TextField).at(4), '150');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Type a rate from 0 to 100'), findsOneWidget);
    expect(api.calls.where((c) => c == 'PATCH /business'), isEmpty);
  });
}
