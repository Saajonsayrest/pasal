import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/router/navigator_keys.dart';
import 'package:pasal_mobile/features/home/presentation/notifications_screen.dart';

/// Notifications and other home screens that open over the bottom menu.
final List<RouteBase> homeRoutes = <RouteBase>[
  GoRoute(
    path: '/notifications',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const NotificationsScreen(),
  ),
];
