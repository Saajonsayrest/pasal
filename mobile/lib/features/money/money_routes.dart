import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/router/navigator_keys.dart';
import 'package:pasal_mobile/features/money/presentation/add_expense_screen.dart';
import 'package:pasal_mobile/features/money/presentation/cash_book_screen.dart';
import 'package:pasal_mobile/features/money/presentation/expenses_screen.dart';
import 'package:pasal_mobile/features/money/presentation/payments_screen.dart';

/// Expenses, cash book, all payments.
final List<RouteBase> moneyRoutes = <RouteBase>[
  GoRoute(path: '/expenses', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const ExpensesScreen()),
  GoRoute(path: '/expenses/new', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const AddExpenseScreen()),
  GoRoute(path: '/cash-book', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const CashBookScreen()),
  GoRoute(path: '/payments', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const PaymentsScreen()),
];
