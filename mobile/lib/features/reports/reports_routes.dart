import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/router/navigator_keys.dart';
import 'package:pasal_mobile/features/reports/presentation/credit_age_screen.dart';
import 'package:pasal_mobile/features/reports/presentation/export_screen.dart';
import 'package:pasal_mobile/features/reports/presentation/reports_screen.dart';
import 'package:pasal_mobile/features/reports/presentation/sales_chart_screen.dart';
import 'package:pasal_mobile/features/reports/presentation/staff_sales_screen.dart';
import 'package:pasal_mobile/features/reports/presentation/top_items_screen.dart';

/// Reports (owner only). The screens open over the bottom menu.
final List<RouteBase> reportsRoutes = <RouteBase>[
  GoRoute(path: '/reports', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const ReportsScreen()),
  GoRoute(path: '/reports/sales', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const SalesChartScreen()),
  GoRoute(path: '/reports/items', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const TopItemsScreen()),
  GoRoute(path: '/reports/credit-age', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const CreditAgeScreen()),
  GoRoute(path: '/reports/staff', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const StaffSalesScreen()),
  GoRoute(path: '/reports/export', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const ExportScreen()),
];
