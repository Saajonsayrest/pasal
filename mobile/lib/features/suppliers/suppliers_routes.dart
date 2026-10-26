import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/router/navigator_keys.dart';
import 'package:pasal_mobile/features/suppliers/presentation/new_purchase_screen.dart';
import 'package:pasal_mobile/features/suppliers/presentation/pay_supplier_screen.dart';
import 'package:pasal_mobile/features/suppliers/presentation/purchase_details_screen.dart';
import 'package:pasal_mobile/features/suppliers/presentation/purchase_return_screen.dart';
import 'package:pasal_mobile/features/suppliers/presentation/purchases_screen.dart';
import 'package:pasal_mobile/features/suppliers/presentation/supplier_form_screen.dart';
import 'package:pasal_mobile/features/suppliers/presentation/supplier_ledger_screen.dart';
import 'package:pasal_mobile/features/suppliers/presentation/suppliers_screen.dart';

/// Suppliers and purchases (owner only, the router guard lives in app_router.dart).
/// The fixed paths (`/new`) come before the `/:id` ones so they are not read as an id.
int _idOf(GoRouterState state) => int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

final List<RouteBase> suppliersRoutes = <RouteBase>[
  GoRoute(
    path: '/suppliers',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const SuppliersScreen(),
  ),
  GoRoute(
    path: '/suppliers/new',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const SupplierFormScreen(),
  ),
  GoRoute(
    path: '/suppliers/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => SupplierLedgerScreen(id: _idOf(state)),
  ),
  GoRoute(
    path: '/suppliers/:id/edit',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => SupplierFormScreen(id: _idOf(state)),
  ),
  GoRoute(
    path: '/suppliers/:id/pay',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => PaySupplierScreen(id: _idOf(state)),
  ),
  GoRoute(
    path: '/purchases',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const PurchasesScreen(),
  ),
  GoRoute(
    path: '/purchases/new',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => NewPurchaseScreen(
      supplierId: int.tryParse(state.uri.queryParameters['supplier'] ?? ''),
      prefillItems: state.uri.queryParameters['items'],
    ),
  ),
  GoRoute(
    path: '/purchases/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => PurchaseDetailsScreen(id: _idOf(state)),
  ),
  GoRoute(
    path: '/purchase-return',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const PurchaseReturnScreen(),
  ),
];
