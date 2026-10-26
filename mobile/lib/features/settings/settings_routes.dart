import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/router/navigator_keys.dart';
import 'package:pasal_mobile/features/settings/presentation/activity_screen.dart';
import 'package:pasal_mobile/features/settings/presentation/app_look_screen.dart';
import 'package:pasal_mobile/features/settings/presentation/backup_screen.dart';
import 'package:pasal_mobile/features/settings/presentation/printer_screen.dart';
import 'package:pasal_mobile/features/settings/presentation/shop_screen.dart';
import 'package:pasal_mobile/features/settings/presentation/staff_screen.dart';

/// Shop details, staff, app look, printer, activity log, backup.
final List<RouteBase> settingsRoutes = <RouteBase>[
  GoRoute(path: '/settings/shop', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const ShopScreen()),
  GoRoute(path: '/settings/staff', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const StaffScreen()),
  GoRoute(path: '/settings/look', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const AppLookScreen()),
  GoRoute(path: '/settings/printer', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const PrinterScreen()),
  GoRoute(path: '/settings/activity', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const ActivityScreen()),
  GoRoute(path: '/settings/backup', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const BackupScreen()),
];
