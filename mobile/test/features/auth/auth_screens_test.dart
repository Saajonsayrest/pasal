import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/features/auth/presentation/first_run_screen.dart';
import 'package:pasal_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:pasal_mobile/features/auth/presentation/profile_screen.dart';
import 'package:pasal_mobile/features/auth/presentation/reset_password_screen.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/pump_app.dart';

void main() {
  testWidgets('forgot password sends the email and then says to check the inbox', (tester) async {
    final api = FakeApi()..on('POST', '/forgot-password', (q, b) => {'message': 'If the email has an account, a link is on its way.'});

    await pumpApp(tester, const ForgotPasswordScreen(), api: api);
    await tester.enterText(find.byType(TextField), '  owner@example.com ');
    await tester.pump();
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /forgot-password'], [
      {'email': 'owner@example.com'},
    ]);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('The link works for 60 minutes.'), findsOneWidget);
  });

  testWidgets('a link with a wrong or missing token says so and offers a new link', (tester) async {
    await pumpApp(tester, const ResetPasswordScreen(email: 'owner@example.com', token: ''), api: FakeApi());

    expect(find.text('This link is wrong or expired'), findsOneWidget);
    expect(find.text('Ask for a new link'), findsOneWidget);
  });

  testWidgets('reset password sends email, token and the new password, then opens log in', (tester) async {
    final api = FakeApi()..on('POST', '/reset-password', (q, b) => {'message': 'Password reset.'});

    await pumpApp(
      tester,
      const ResetPasswordScreen(email: 'owner@example.com', token: 'abc123'),
      api: api,
      routes: [GoRoute(path: '/login', builder: (_, _) => const Text('LOGIN PAGE'))],
    );
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'new-pass-2026');
    await tester.enterText(fields.at(1), 'new-pass-2026');
    await tester.pump();
    await tester.tap(find.text('Save new password'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /reset-password'], [
      {'email': 'owner@example.com', 'token': 'abc123', 'password': 'new-pass-2026'},
    ]);
    expect(find.text('LOGIN PAGE'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('reset password shows a mismatch under the confirm box and does not send', (tester) async {
    final api = FakeApi();

    await pumpApp(tester, const ResetPasswordScreen(email: 'owner@example.com', token: 'abc123'), api: api);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'new-pass-2026');
    await tester.enterText(fields.at(1), 'other-pass-2026');
    await tester.pump();
    await tester.tap(find.text('Save new password'));
    await tester.pumpAndSettle();

    expect(find.text('The two passwords do not match.'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('first run shows the setup steps done from the data, and skip is remembered', (tester) async {
    final api = FakeApi()
      ..on(
        'GET',
        '/business',
        (q, b) => {
          'data': {'id': 1, 'name': 'Himal Kirana Pasal', 'pan': '600000001', 'phone': '01-0000000', 'address': 'Baneshwor', 'vat_rate': 13.0},
        },
      )
      ..on('GET', '/items', (q, b) => {'data': [], 'meta': {'current_page': 1, 'last_page': 1, 'per_page': 1, 'total': 0}})
      ..on(
        'GET',
        '/customers',
        (q, b) => {
          'data': [
            {'id': 1, 'name': 'Hari Thapa', 'phone': null, 'address': null, 'pan': null, 'credit_limit': null, 'owes': 0, 'last_sale_at': null, 'oldest_unpaid_at': null},
          ],
          'meta': {'current_page': 1, 'last_page': 1, 'per_page': 1, 'total': 1},
        },
      )
      ..on('GET', '/users', (q, b) => {'data': [], 'meta': {'current_page': 1, 'last_page': 1, 'per_page': 1, 'total': 2}});

    final container = await pumpApp(tester, const FirstRunScreen(), api: api);

    expect(find.text('Welcome, Asha'), findsOneWidget);
    expect(find.text('3 of 4 steps done'), findsOneWidget);
    expect(find.text('Add your first item'), findsOneWidget);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(container.read(sharedPrefsProvider).getBool('pasal_welcome_done'), isTrue);
  });

  testWidgets('profile: change password sends the current and new password, then says it is changed', (tester) async {
    final api = FakeApi()..on('POST', '/me/password', (q, b) => {'message': 'Password changed.'});

    await pumpApp(tester, const ProfileScreen(), api: api);
    expect(find.text('Asha Shrestha'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);

    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'old-pass-1');
    await tester.enterText(find.byType(TextField).at(1), 'brand-new-1');
    await tester.pump();
    await tester.tap(find.text('Save new password'));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /me/password'], [
      {'current_password': 'old-pass-1', 'password': 'brand-new-1'},
    ]);
    expect(find.text('Password changed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
