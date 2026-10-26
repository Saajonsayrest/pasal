import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/features/settings/presentation/activity_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _sale() => {
      'kind': 'sale',
      'ref_id': 9,
      'at': '2026-10-26T07:00:00+00:00',
      'by': 'Sita Gurung',
      'label': 'S-0413',
      'amount': 221500,
    };

Map<String, dynamic> _expense() => {
      'kind': 'expense',
      'ref_id': 3,
      'at': '2026-10-26T06:00:00+00:00',
      'by': 'Asha Shrestha',
      'label': 'Electricity',
      'amount': 85000,
    };

void main() {
  testWidgets('shows each event as a sentence and filters by kind', (tester) async {
    final api = FakeApi()
      ..on('GET', '/users', (q, b) => pagedJson([{'id': 5, 'name': 'Sita Gurung', 'email': 'sita@example.com', 'role': 'staff'}]))
      ..on(
        'GET',
        '/activity',
        (q, b) => {
          'data': [_sale(), _expense()],
          'meta': {'current_page': 1, 'last_page': 1, 'per_page': 30, 'total': 2},
        },
      );
    await pumpApp(tester, const ActivityScreen(), api: api);

    expect(find.text('Sita Gurung made sale S-0413 for Rs 2,215'), findsOneWidget);
    expect(find.text('Asha Shrestha added expense Electricity, Rs 850'), findsOneWidget);
    expect(find.text('Showing 2 of 2 events'), findsOneWidget);

    final money = find.widgetWithText(ChoiceChip, 'Money');
    await tester.ensureVisible(money);
    await tester.tap(money);
    await tester.pumpAndSettle();

    expect(find.textContaining('made sale'), findsNothing);
    expect(find.textContaining('added expense'), findsOneWidget);
  });

  testWidgets('load more adds the next page of events', (tester) async {
    final api = FakeApi()
      ..on('GET', '/users', (q, b) => pagedJson([]))
      ..on(
        'GET',
        '/activity',
        (q, b) => {
          'data': [q!['page'] == 1 ? _sale() : _expense()],
          'meta': {'current_page': q['page'], 'last_page': 2, 'per_page': 30, 'total': 2},
        },
      );
    await pumpApp(tester, const ActivityScreen(), api: api);

    expect(find.text('Load more'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Asha Shrestha added expense Electricity, Rs 850'), findsOneWidget);
    expect(find.text('Showing 2 of 2 events'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
  });
}
