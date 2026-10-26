import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/router/navigator_keys.dart';
import 'package:pasal_mobile/features/vat/presentation/filing_details_screen.dart';
import 'package:pasal_mobile/features/vat/presentation/old_return_screen.dart';
import 'package:pasal_mobile/features/vat/presentation/vat_books_screen.dart';
import 'package:pasal_mobile/features/vat/presentation/vat_filings_screen.dart';
import 'package:pasal_mobile/features/vat/presentation/vat_screen.dart';

/// VAT this month, filings, old return, books. Owner only (the router guards these paths).
final List<RouteBase> vatRoutes = <RouteBase>[
  GoRoute(path: '/vat', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const VatScreen()),
  GoRoute(path: '/vat/filings', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const VatFilingsScreen()),
  GoRoute(
    path: '/vat/filings/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => FilingDetailsScreen(id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
  ),
  GoRoute(path: '/vat/old-return', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const OldReturnScreen()),
  GoRoute(path: '/vat/books', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const VatBooksScreen()),
];
