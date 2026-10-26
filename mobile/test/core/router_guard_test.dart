import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/router/app_router.dart';
import 'package:pasal_mobile/core/session/session.dart';

import '../helpers/pump_app.dart';

void main() {
  const out = SessionState(status: AuthStatus.signedOut);

  test('a person who is not logged in only reaches the public screens', () {
    expect(redirectFor(out, Uri.parse('/')), '/login');
    expect(redirectFor(out, Uri.parse('/customers/4')), '/login');
    expect(redirectFor(out, Uri.parse('/login')), isNull);
    expect(redirectFor(out, Uri.parse('/forgot-password')), isNull);
    expect(redirectFor(out, Uri.parse('/reset-password?token=a&email=b')), isNull);
  });

  test('waits while the saved login is being checked', () {
    expect(redirectFor(const SessionState.checking(), Uri.parse('/items')), isNull);
  });

  test('a logged in person is sent away from the login screen', () {
    expect(redirectFor(signedIn(), Uri.parse('/login')), '/');
    expect(redirectFor(signedIn(), Uri.parse('/items')), isNull);
  });

  test('staff cannot open owner screens, the owner can', () {
    final staff = signedIn(owner: false);
    final owner = signedIn();
    for (final path in ['/purchases', '/purchases/new', '/suppliers/3', '/reports/sales', '/vat/filings/2', '/expenses/new', '/cash-book', '/payments', '/items/new', '/items/deleted', '/items/12/edit', '/items/12/adjust', '/items/12/history', '/sales/9/return', '/sales/9/cancel', '/settings/staff', '/settings/shop', '/stock-count', '/low-stock', '/categories', '/welcome']) {
      expect(redirectFor(staff, Uri.parse(path)), '/', reason: path);
      expect(redirectFor(owner, Uri.parse(path)), isNull, reason: path);
    }
    for (final path in ['/', '/items', '/items/12', '/sell', '/sell/checkout', '/sales', '/sales/9', '/sales/9/bill', '/customers', '/customers/3/payment', '/settings/look', '/profile', '/notifications', '/more']) {
      expect(redirectFor(staff, Uri.parse(path)), isNull, reason: path);
    }
  });

  test('the reset link from the email opens the reset screen', () {
    expect(redirectFor(out, Uri.parse('pasal://reset-password?token=abc&email=a%40b.com')), '/reset-password?token=abc&email=a%40b.com');
  });
}
