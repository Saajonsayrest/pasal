import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/router/navigator_keys.dart';
import 'package:pasal_mobile/features/customers/presentation/customer_form_screen.dart';
import 'package:pasal_mobile/features/customers/presentation/customer_ledger_screen.dart';
import 'package:pasal_mobile/features/customers/presentation/reminder_screen.dart';
import 'package:pasal_mobile/features/customers/presentation/statement_screen.dart';
import 'package:pasal_mobile/features/customers/presentation/take_payment_screen.dart';

int _customerId(GoRouterState state) => int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

/// Customer ledger, take payment, form, reminder, statement. Same paths as the website.
/// `/customers/new` comes before `/customers/:id` so that "new" is never read as an id.
final List<RouteBase> customersRoutes = <RouteBase>[
  GoRoute(
    path: '/customers/new',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => CustomerFormScreen(afterCheckout: state.uri.queryParameters['next'] == 'checkout'),
  ),
  GoRoute(
    path: '/customers/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => CustomerLedgerScreen(customerId: _customerId(state)),
  ),
  GoRoute(
    path: '/customers/:id/edit',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => CustomerFormScreen(customerId: _customerId(state)),
  ),
  GoRoute(
    path: '/customers/:id/payment',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => TakePaymentScreen(customerId: _customerId(state)),
  ),
  GoRoute(
    path: '/customers/:id/remind',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => ReminderScreen(customerId: _customerId(state)),
  ),
  GoRoute(
    path: '/customers/:id/statement',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => StatementScreen(customerId: _customerId(state)),
  ),
];
