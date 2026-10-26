import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/settings/presentation/backup_screen.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('offers the five CSV exports', (tester) async {
    await pumpApp(tester, const BackupScreen());

    for (final label in ['Items (CSV)', 'Customers (CSV)', 'Suppliers (CSV)', 'Sales (CSV)', 'Expenses (CSV)']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('Daily backups are not built yet.'), findsOneWidget);
  });
}
