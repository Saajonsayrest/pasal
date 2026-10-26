import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/router/app_shell.dart';
import 'package:pasal_mobile/core/router/navigator_keys.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/features/auth/auth_routes.dart';
import 'package:pasal_mobile/features/customers/customers_routes.dart';
import 'package:pasal_mobile/features/customers/presentation/customers_screen.dart';
import 'package:pasal_mobile/features/home/home_routes.dart';
import 'package:pasal_mobile/features/home/presentation/home_screen.dart';
import 'package:pasal_mobile/features/home/presentation/more_screen.dart';
import 'package:pasal_mobile/features/items/items_routes.dart';
import 'package:pasal_mobile/features/items/presentation/items_screen.dart';
import 'package:pasal_mobile/features/money/money_routes.dart';
import 'package:pasal_mobile/features/reports/reports_routes.dart';
import 'package:pasal_mobile/features/selling/presentation/sell_screen.dart';
import 'package:pasal_mobile/features/selling/selling_routes.dart';
import 'package:pasal_mobile/features/settings/settings_routes.dart';
import 'package:pasal_mobile/features/stock/stock_routes.dart';
import 'package:pasal_mobile/features/suppliers/suppliers_routes.dart';
import 'package:pasal_mobile/features/vat/vat_routes.dart';

/// Paths that work without a login.
const _publicPaths = {'/login', '/forgot-password', '/reset-password'};

/// Paths staff cannot open. The server refuses them too, this only saves a wrong turn.
final _ownerOnly = <RegExp>[
  RegExp(r'^/(purchases|suppliers|expenses|cash-book|payments|reports|vat|stock-count|low-stock|categories|welcome|purchase-return|barcode-labels|expiry)(/|$)'),
  RegExp(r'^/settings/(shop|staff|activity|backup)$'),
  RegExp(r'^/items/(new|deleted|\d+/(edit|adjust|history))$'),
  RegExp(r'^/sales/\d+/(return|cancel)$'),
];

bool _isOwnerOnly(String path) => _ownerOnly.any((r) => r.hasMatch(path));

/// Where the person is sent. Public so it can be tested.
String? redirectFor(SessionState session, Uri uri) {
  if (uri.scheme == 'pasal') return '/reset-password?${uri.query}'; // link in the reset email
  final path = uri.path;
  if (session.status == AuthStatus.checking) return null;
  if (!session.isSignedIn) return _publicPaths.contains(path) ? null : '/login';
  if (path == '/login') return '/';
  if (!session.isOwner && _isOwnerOnly(path)) return '/';
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(ref.read(sessionProvider), state.uri),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/items', builder: (_, _) => const ItemsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/sell', builder: (_, _) => const SellScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/customers', builder: (_, _) => const CustomersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/more', builder: (_, _) => const MoreScreen())]),
        ],
      ),
      ...authRoutes,
      ...homeRoutes,
      ...sellingRoutes,
      ...itemsRoutes,
      ...stockRoutes,
      ...customersRoutes,
      ...suppliersRoutes,
      ...moneyRoutes,
      ...reportsRoutes,
      ...vatRoutes,
      ...settingsRoutes,
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(state.error?.toString() ?? 'Page not found')),
    ),
  );
});
