import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/router/navigator_keys.dart';
import 'package:pasal_mobile/features/stock/presentation/barcode_labels_screen.dart';
import 'package:pasal_mobile/features/stock/presentation/categories_screen.dart';
import 'package:pasal_mobile/features/stock/presentation/expiry_screen.dart';
import 'package:pasal_mobile/features/stock/presentation/low_stock_screen.dart';
import 'package:pasal_mobile/features/stock/presentation/stock_count_screen.dart';
import 'package:pasal_mobile/features/stock/presentation/stock_history_screen.dart';

/// Stock history, stock count, low stock, categories, barcode labels, expiry.
final List<RouteBase> stockRoutes = <RouteBase>[
  GoRoute(
    path: '/items/:id/history',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => StockHistoryScreen(itemId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
  ),
  GoRoute(path: '/stock-count', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const StockCountScreen()),
  GoRoute(path: '/low-stock', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const LowStockScreen()),
  GoRoute(path: '/categories', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const CategoriesScreen()),
  GoRoute(path: '/barcode-labels', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const BarcodeLabelsScreen()),
  GoRoute(path: '/expiry', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const ExpiryScreen()),
];
