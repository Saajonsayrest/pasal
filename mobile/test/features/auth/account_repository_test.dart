import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/auth/data/account_repository.dart';

import '../../helpers/fake_api.dart';

void main() {
  test('forgot password sends only the email', () async {
    final api = FakeApi()..on('POST', '/forgot-password', (q, b) => {'message': 'If the email has an account, a link is on its way.'});

    await AccountRepository(api).forgotPassword('owner@example.com');

    expect(api.bodies['POST /forgot-password'], [
      {'email': 'owner@example.com'},
    ]);
  });

  test('reset password sends the email, the token from the link and the new password', () async {
    final api = FakeApi()..on('POST', '/reset-password', (q, b) => {'message': 'Password reset.'});

    await AccountRepository(api).resetPassword(email: 'owner@example.com', token: 'abc123', password: 'new-pass-2026');

    expect(api.bodies['POST /reset-password'], [
      {'email': 'owner@example.com', 'token': 'abc123', 'password': 'new-pass-2026'},
    ]);
  });

  test('change password uses the snake case keys the API expects', () async {
    final api = FakeApi()..on('POST', '/me/password', (q, b) => {'message': 'Password changed.'});

    await AccountRepository(api).changePassword(currentPassword: 'old-pass-1', password: 'brand-new-1');

    expect(api.bodies['POST /me/password'], [
      {'current_password': 'old-pass-1', 'password': 'brand-new-1'},
    ]);
  });

  test('setup checklist: a step is done from the data the shop already has', () async {
    final api = FakeApi()
      ..on(
        'GET',
        '/business',
        (q, b) => {
          'data': {'id': 1, 'name': 'Himal Kirana Pasal', 'pan': '600000001', 'phone': '01-0000000', 'address': 'Baneshwor', 'vat_rate': 13.0},
        },
      )
      ..on('GET', '/items', (q, b) => {'data': [], 'meta': {'current_page': 1, 'last_page': 1, 'per_page': 1, 'total': 0}})
      ..on('GET', '/customers', (q, b) => {'data': [], 'meta': {'current_page': 1, 'last_page': 1, 'per_page': 1, 'total': 2}})
      ..on('GET', '/users', (q, b) => {'data': [], 'meta': {'current_page': 1, 'last_page': 1, 'per_page': 1, 'total': 1}});

    final list = await AccountRepository(api).setupChecklist();

    expect(list.shopDone, isTrue);
    expect(list.itemDone, isFalse);
    expect(list.customerDone, isTrue);
    expect(list.staffDone, isFalse, reason: 'only the owner exists');
    expect(list.doneCount, 2);
  });

  test('setup checklist: a shop with a blank PAN is not done yet', () async {
    final api = FakeApi()
      ..on(
        'GET',
        '/business',
        (q, b) => {
          'data': {'id': 1, 'name': 'Himal', 'pan': '  ', 'phone': '01-0000000', 'address': 'Baneshwor', 'vat_rate': 13.0},
        },
      )
      ..on('GET', '/items', (q, b) => {'data': [], 'meta': {'current_page': 1, 'last_page': 1, 'per_page': 1, 'total': 0}})
      ..on('GET', '/customers', (q, b) => {'data': [], 'meta': {'current_page': 1, 'last_page': 1, 'per_page': 1, 'total': 0}})
      ..on('GET', '/users', (q, b) => {'data': [], 'meta': {'current_page': 1, 'last_page': 1, 'per_page': 1, 'total': 1}});

    final list = await AccountRepository(api).setupChecklist();

    expect(list.shopDone, isFalse);
    expect(list.doneCount, 0);
  });
}
