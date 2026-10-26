import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/stock/presentation/expiry_screen.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('shows the later note, the example rows and switched off filters', (tester) async {
    await pumpApp(tester, const ExpiryScreen());

    expect(find.text('Planned after the first release. Example only.'), findsOneWidget);
    expect(find.text('Expiry dates need a change in the server first. The app does not save them yet.'), findsOneWidget);
    expect(find.text('Milk 500ml'), findsOneWidget);
    expect(find.text('Expired'), findsWidgets);

    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.onSelected, isNull);
    }
  });
}
