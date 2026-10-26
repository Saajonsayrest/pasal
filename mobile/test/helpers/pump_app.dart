import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/settings/settings.dart';
import 'package:pasal_mobile/core/storage/token_store.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// A signed in owner (or staff) for tests.
SessionState signedIn({bool owner = true}) => SessionState(
      status: AuthStatus.signedIn,
      user: AppUser(
        id: 1,
        name: 'Asha Shrestha',
        email: 'asha@example.com',
        role: owner ? 'owner' : 'staff',
        business: const Business(id: 1, name: 'Himal Kirana Pasal', pan: '600000001', phone: '01-0000000', address: 'Baneshwor, Kathmandu'),
      ),
    );

class _FixedSession extends SessionNotifier {
  _FixedSession(this._state);

  final SessionState _state;

  @override
  SessionState build() => _state;
}

/// Shows [child] inside the app theme, English text, a router (so `context.push` works), a fake API and a signed in user.
///
///     final api = FakeApi()..on('GET', '/customers', (q, b) => pagedJson([...]));
///     await pumpApp(tester, const CustomersScreen(), api: api);
///
/// Pass [routes] to register more paths that `context.push` may open (their builders can return a Text).
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  Widget child, {
  FakeApi? api,
  bool owner = true,
  bool nepali = false,
  List<GoRoute> routes = const [],
  List<Override> overrides = const [],
  Size size = const Size(420, 900),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Lang.ne = nepali;
  Lang.bsDates = true;
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      apiClientProvider.overrideWithValue(api ?? FakeApi()),
      sessionProvider.overrideWith(() => _FixedSession(signedIn(owner: owner))),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => child),
      ...routes,
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildTheme(const AppSettings()),
        locale: Locale(nepali ? 'ne' : 'en'),
        supportedLocales: const [Locale('en'), Locale('ne')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Same, with the answer of a failed request.
ApiException validation(Map<String, List<String>> errors, {String message = 'The given data was invalid.'}) => ApiException(422, message, errors: errors);
