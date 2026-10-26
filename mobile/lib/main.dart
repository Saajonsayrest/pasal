import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/app.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Riverpod 3 retries a failed provider by itself. Our screens show a "Try again" button instead.
  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    retry: (count, error) => null,
  );
  await container.read(sessionProvider.notifier).restore();

  runApp(UncontrolledProviderScope(container: container, child: const PasalApp()));
}
