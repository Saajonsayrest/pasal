import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/router/navigator_keys.dart';
import 'package:pasal_mobile/features/auth/presentation/first_run_screen.dart';
import 'package:pasal_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:pasal_mobile/features/auth/presentation/login_screen.dart';
import 'package:pasal_mobile/features/auth/presentation/profile_screen.dart';
import 'package:pasal_mobile/features/auth/presentation/reset_password_screen.dart';

/// Login, forgot and reset password, first-run guide, profile.
final List<RouteBase> authRoutes = <RouteBase>[
  GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
  GoRoute(
    path: '/forgot-password',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const ForgotPasswordScreen(),
  ),
  GoRoute(
    path: '/reset-password',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => ResetPasswordScreen(
      email: state.uri.queryParameters['email'] ?? '',
      token: state.uri.queryParameters['token'] ?? '',
    ),
  ),
  GoRoute(
    path: '/welcome',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const FirstRunScreen(),
  ),
  GoRoute(
    path: '/profile',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const ProfileScreen(),
  ),
];
