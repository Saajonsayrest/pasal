import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/router/navigator_keys.dart';
import 'package:pasal_mobile/features/items/presentation/adjust_stock_screen.dart';
import 'package:pasal_mobile/features/items/presentation/deleted_items_screen.dart';
import 'package:pasal_mobile/features/items/presentation/item_details_screen.dart';
import 'package:pasal_mobile/features/items/presentation/item_form_screen.dart';
import 'package:pasal_mobile/features/items/presentation/item_widgets.dart';
import 'package:pasal_mobile/features/items/presentation/scan_code_screen.dart';

int? _idOf(GoRouterState state) => int.tryParse(state.pathParameters['id'] ?? '');

/// Item details and forms, deleted items and the barcode scanner. Static paths come before `/items/:id`.
final List<RouteBase> itemsRoutes = <RouteBase>[
  GoRoute(path: '/items/scan', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const ScanCodeScreen()),
  GoRoute(path: '/items/new', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const ItemFormScreen()),
  GoRoute(path: '/items/deleted', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const DeletedItemsScreen()),
  GoRoute(
    path: '/items/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) {
      final id = _idOf(state);
      return id == null ? const MissingItemScreen() : ItemDetailsScreen(id: id);
    },
  ),
  GoRoute(
    path: '/items/:id/edit',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) {
      final id = _idOf(state);
      return id == null ? const MissingItemScreen() : ItemFormScreen(id: id);
    },
  ),
  GoRoute(
    path: '/items/:id/adjust',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) {
      final id = _idOf(state);
      return id == null ? const MissingItemScreen() : AdjustStockScreen(id: id);
    },
  ),
];
