import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/settings/presentation/staff_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _user(int id, String name, String email, String role) => {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
    };

FakeApi _apiWithTeam() => FakeApi()
  ..on(
    'GET',
    '/users',
    (q, b) => pagedJson([
      _user(1, 'Asha Shrestha', 'asha@example.com', 'owner'),
      _user(5, 'Sita Gurung', 'sita@example.com', 'staff'),
    ]),
  );

void main() {
  testWidgets('lists the team and marks the signed in person', (tester) async {
    await pumpApp(tester, const StaffScreen(), api: _apiWithTeam());

    expect(find.text('Asha Shrestha (You)'), findsOneWidget);
    expect(find.text('Sita Gurung'), findsOneWidget);
    expect(find.text('sita@example.com'), findsOneWidget);
    expect(find.widgetWithText(PBadge, 'Staff'), findsOneWidget);
  });

  testWidgets('editing a person sends only the field that changed', (tester) async {
    final api = _apiWithTeam()..on('PATCH', '/users/5', (q, b) => {'data': _user(5, 'Sita Devi', 'sita@example.com', 'staff')});
    await pumpApp(tester, const StaffScreen(), api: api);

    await tester.tap(find.widgetWithText(ListRow, 'Sita Gurung'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Sita Devi');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.bodies['PATCH /users/5']!.single, {'name': 'Sita Devi'});
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('adding staff generates a password, sends it and shows it once', (tester) async {
    final api = _apiWithTeam()..on('POST', '/users', (q, b) => {'data': _user(6, 'Ram Karki', 'ram@example.com', 'staff')});
    await pumpApp(tester, const StaffScreen(), api: api);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add staff'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Ram Karki');
    await tester.enterText(find.byType(TextField).at(1), 'ram@example.com');
    await tester.tap(find.text('Generate a password'));
    await tester.pump();

    final password = tester.widget<EditableText>(find.byType(EditableText).at(2)).controller.text;
    expect(password, hasLength(14));

    await tester.tap(find.descendant(of: find.byType(PrimaryButton), matching: find.text('Add staff')));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /users']!.single, {
      'name': 'Ram Karki',
      'email': 'ram@example.com',
      'password': password,
      'role': 'staff',
    });
    expect(find.text('Ram Karki is added'), findsOneWidget);
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, password);
  });
}
