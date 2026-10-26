import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/router/navigator_keys.dart';
import 'package:pasal_mobile/features/selling/presentation/bill_screen.dart';
import 'package:pasal_mobile/features/selling/presentation/cancel_sale_screen.dart';
import 'package:pasal_mobile/features/selling/presentation/checkout_screen.dart';
import 'package:pasal_mobile/features/selling/presentation/held_carts_screen.dart';
import 'package:pasal_mobile/features/selling/presentation/sale_details_screen.dart';
import 'package:pasal_mobile/features/selling/presentation/sale_return_screen.dart';
import 'package:pasal_mobile/features/selling/presentation/sales_screen.dart';
import 'package:pasal_mobile/features/selling/presentation/scan_item_screen.dart';

int _saleId(GoRouterState state) => int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

/// Scan, checkout, held carts, sales list, sale details, bill, return, cancel.
/// The tab at /sell is in the shell (app_router.dart). The rest open over the bottom menu.
final List<RouteBase> sellingRoutes = <RouteBase>[
  GoRoute(
    path: '/sell/scan',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const ScanItemScreen(),
  ),
  GoRoute(
    path: '/sell/checkout',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => CheckoutScreen(customerId: int.tryParse(state.uri.queryParameters['customer'] ?? '')),
  ),
  GoRoute(
    path: '/sell/held',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const HeldCartsScreen(),
  ),
  GoRoute(
    path: '/sales',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const SalesScreen(),
  ),
  GoRoute(
    path: '/sales/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => SaleDetailsScreen(saleId: _saleId(state)),
  ),
  GoRoute(
    path: '/sales/:id/bill',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => BillScreen(saleId: _saleId(state)),
  ),
  GoRoute(
    path: '/sales/:id/return',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => SaleReturnScreen(saleId: _saleId(state)),
  ),
  GoRoute(
    path: '/sales/:id/cancel',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => CancelSaleScreen(saleId: _saleId(state)),
  ),
];
