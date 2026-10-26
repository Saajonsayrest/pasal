import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/router/app_router.dart';
import 'package:pasal_mobile/core/settings/settings.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';

class PasalApp extends ConsumerWidget {
  const PasalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(appRouterProvider);
    final theme = buildTheme(settings);

    return MaterialApp.router(
      title: 'PASAL',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // The theme already holds its own brightness (light, dark or pure black).
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.light,
      locale: settings.locale,
      supportedLocales: const [Locale('en'), Locale('ne')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
