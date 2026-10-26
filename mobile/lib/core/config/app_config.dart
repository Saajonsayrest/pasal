import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Build time settings, given with `--dart-define`. See `setup.sh` and the README.
///
///     flutter run --dart-define=API_URL=https://api.example.com/api/v1
class AppConfig {
  AppConfig._();

  static const _apiUrl = String.fromEnvironment('API_URL');

  /// Address of the API, always ending with `/api/v1`.
  /// Default for development: the Android emulator reaches the computer at 10.0.2.2,
  /// the iOS simulator and desktop at localhost. A real phone needs `--dart-define=API_URL=http://<computer ip>:8000/api/v1`.
  static String get apiUrl {
    if (_apiUrl.isNotEmpty) return _apiUrl;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000/api/v1';
    return 'http://localhost:8000/api/v1';
  }

  /// `development` or `production`.
  static const env = String.fromEnvironment('APP_ENV', defaultValue: 'development');
}
