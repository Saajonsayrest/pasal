import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/storage/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_api.dart';
import '../helpers/pump_app.dart' show validation;

const _user = {
  'id': 1,
  'name': 'Asha Shrestha',
  'email': 'asha@example.com',
  'role': 'owner',
  'business': {'id': 1, 'name': 'Himal Kirana Pasal', 'pan': null, 'phone': null, 'address': null, 'vat_rate': 13.0},
};

Future<(ProviderContainer, FakeApi, MemoryTokenStore)> _make({String? savedToken}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = FakeApi();
  final tokens = MemoryTokenStore()..token = savedToken;
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [sharedPrefsProvider.overrideWithValue(prefs), apiClientProvider.overrideWithValue(api), tokenStoreProvider.overrideWithValue(tokens)],
  );
  addTearDown(container.dispose);
  return (container, api, tokens);
}

void main() {
  test('login keeps the token safe and signs the person in', () async {
    final (c, api, tokens) = await _make();
    api.on('POST', '/login', (q, b) => {'token': '12|abc', 'user': _user});

    await c.read(sessionProvider.notifier).login('asha@example.com', 'a-long-password');

    final s = c.read(sessionProvider);
    expect(s.isSignedIn, isTrue);
    expect(s.isOwner, isTrue);
    expect(s.business?.name, 'Himal Kirana Pasal');
    expect(tokens.token, '12|abc');
    expect(api.hasToken, isTrue);
  });

  test('a wrong password leaves the person signed out', () async {
    final (c, api, tokens) = await _make();
    api.on('POST', '/login', (q, b) => throw validation({'email': ['These credentials do not match.']}));

    await expectLater(c.read(sessionProvider.notifier).login('a@b.com', 'nope'), throwsA(isA<ApiException>()));
    expect(c.read(sessionProvider).isSignedIn, isFalse);
    expect(tokens.token, isNull);
  });

  test('start with no saved token means signed out', () async {
    final (c, _, _) = await _make();
    await c.read(sessionProvider.notifier).restore();
    expect(c.read(sessionProvider).status, AuthStatus.signedOut);
  });

  test('start with a good saved token signs in again', () async {
    final (c, api, _) = await _make(savedToken: '12|abc');
    api.on('GET', '/me', (q, b) => _user);
    await c.read(sessionProvider.notifier).restore();
    expect(c.read(sessionProvider).isSignedIn, isTrue);
  });

  test('start with a dead token forgets it', () async {
    final (c, api, tokens) = await _make(savedToken: 'dead');
    api.on('GET', '/me', (q, b) => throw ApiException(401, 'Unauthenticated.'));
    await c.read(sessionProvider.notifier).restore();
    expect(c.read(sessionProvider).status, AuthStatus.signedOut);
    expect(tokens.token, isNull);
  });

  test('start without network keeps the token and opens with the last known user', () async {
    final (c, api, tokens) = await _make();
    api.on('POST', '/login', (q, b) => {'token': '12|abc', 'user': _user});
    await c.read(sessionProvider.notifier).login('asha@example.com', 'a-long-password');

    // The phone is restarted with no network.
    api.on('GET', '/me', (q, b) => throw ApiException(0, 'Cannot reach the server.'));
    c.read(sessionProvider.notifier).state = const SessionState.checking();
    await c.read(sessionProvider.notifier).restore();

    expect(c.read(sessionProvider).isSignedIn, isTrue);
    expect(c.read(sessionProvider).user?.name, 'Asha Shrestha');
    expect(tokens.token, '12|abc');
  });

  test('logout clears the token even when the server cannot be reached', () async {
    final (c, api, tokens) = await _make();
    api.on('POST', '/login', (q, b) => {'token': '12|abc', 'user': _user});
    await c.read(sessionProvider.notifier).login('asha@example.com', 'a-long-password');
    api.on('POST', '/logout', (q, b) => throw ApiException(0, 'offline'));

    await c.read(sessionProvider.notifier).logout();

    expect(c.read(sessionProvider).status, AuthStatus.signedOut);
    expect(tokens.token, isNull);
    expect(api.hasToken, isFalse);
  });
}
