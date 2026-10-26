import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';

enum AuthStatus { checking, signedOut, signedIn }

class SessionState {
  const SessionState({required this.status, this.user});

  const SessionState.checking() : this(status: AuthStatus.checking);

  final AuthStatus status;
  final AppUser? user;

  bool get isSignedIn => status == AuthStatus.signedIn && user != null;
  bool get isOwner => user?.isOwner ?? false;
  Business? get business => user?.business;
}

/// Who is logged in. Read `ref.watch(sessionProvider)`; use `.isOwner` to hide owner only parts
/// (the server still enforces it).
class SessionNotifier extends Notifier<SessionState> {
  static const _userKey = 'pasal_user';

  @override
  SessionState build() => const SessionState.checking();

  /// Check a saved token at start (called once from `main`).
  /// With no network the last known user is used, so the shop can still open the app on a weak connection.
  Future<void> restore() async {
    final api = ref.read(apiClientProvider);
    final token = await ref.read(tokenStoreProvider).read();
    if (token == null) {
      state = const SessionState(status: AuthStatus.signedOut);
      return;
    }
    api.setToken(token);
    try {
      await _setUser(AppUser.fromJson(await api.get('/me')));
    } on ApiException catch (e) {
      final cached = e.isNetwork ? _cachedUser() : null;
      if (cached != null) {
        state = SessionState(status: AuthStatus.signedIn, user: cached);
      } else {
        await _forget();
      }
    }
  }

  Future<void> login(String email, String password, {String deviceName = 'Phone'}) async {
    final api = ref.read(apiClientProvider);
    final res = await api.post('/login', body: {'email': email, 'password': password, 'device_name': deviceName});
    final token = res['token'] as String;
    api.setToken(token);
    await ref.read(tokenStoreProvider).write(token);
    await _setUser(AppUser.fromJson(res['user'] as Json));
  }

  Future<void> logout({bool everywhere = false}) async {
    try {
      await ref.read(apiClientProvider).post(everywhere ? '/logout-all' : '/logout');
    } catch (_) {
      // The token may already be dead. Either way this phone forgets it.
    }
    await _forget();
  }

  /// A 401 came back: the token is no longer good.
  void expire() {
    if (state.status == AuthStatus.signedOut) return;
    _forget();
  }

  /// Reload the user after the shop details change.
  Future<void> refresh() async => _setUser(AppUser.fromJson(await ref.read(apiClientProvider).get('/me')));

  Future<void> _setUser(AppUser user) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(
      _userKey,
      jsonEncode({
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'role': user.role,
        if (user.business != null)
          'business': {
            'id': user.business!.id,
            'name': user.business!.name,
            'pan': user.business!.pan,
            'phone': user.business!.phone,
            'address': user.business!.address,
            'vat_rate': user.business!.vatRate,
          },
      }),
    );
    state = SessionState(status: AuthStatus.signedIn, user: user);
  }

  AppUser? _cachedUser() {
    final raw = ref.read(sharedPrefsProvider).getString(_userKey);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _forget() async {
    ref.read(apiClientProvider).setToken(null);
    await ref.read(tokenStoreProvider).clear();
    await ref.read(sharedPrefsProvider).remove(_userKey);
    state = const SessionState(status: AuthStatus.signedOut);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
