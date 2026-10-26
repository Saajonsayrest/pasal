import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/config/app_config.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/storage/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the loaded preferences.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'));

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// The one HTTP client. Use it from repositories: `ref.watch(apiClientProvider)`.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: AppConfig.apiUrl,
    onUnauthorized: () => ref.read(sessionProvider.notifier).expire(),
  );
});
