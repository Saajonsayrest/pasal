import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/features/reports/data/csv.dart';
import 'package:pasal_mobile/features/reports/data/export_tables.dart';
import 'package:pasal_mobile/features/reports/data/range.dart';

typedef ExportProgress = void Function(ExportSet set, int page, int last);

/// Talks to the report endpoints and builds the CSV files. Money stays in paisa.
class ReportsRepository {
  ReportsRepository(this._api);

  final ApiClient _api;

  Query _dates(DateRange range) => {'from': range.from, 'to': range.to};

  Future<Summary> summary(DateRange range) async => Summary.fromJson(await _api.get('/reports/summary', query: _dates(range)));

  Future<DailyReport> daily(DateRange range) async => DailyReport.fromJson(await _api.get('/reports/daily', query: _dates(range)));

  Future<ItemsReport> items(DateRange range, {int limit = 20}) async =>
      ItemsReport.fromJson(await _api.get('/reports/items', query: {..._dates(range), 'limit': limit}));

  Future<CreditAge> creditAge() async => CreditAge.fromJson(await _api.get('/reports/credit-age'));

  Future<List<StaffSales>> staff(DateRange range) async {
    final res = await _api.get('/reports/staff', query: _dates(range));
    return (res['data'] as List<dynamic>).cast<Json>().map(StaffSales.fromJson).toList();
  }

  /// One CSV file per picked list, in the order of [ExportSet]. Reads every page of each list.
  Future<List<CsvFile>> exportCsv({required DateRange range, required Set<ExportSet> sets, ExportProgress? onPage}) async {
    final files = <CsvFile>[];
    for (final set in ExportSet.values) {
      if (!sets.contains(set)) continue;
      files.add((await _table(set, range, onPage)).file);
    }
    return files;
  }

  Future<CsvTable> _table(ExportSet set, DateRange range, ExportProgress? onPage) async {
    final dates = _dates(range);
    switch (set) {
      case ExportSet.sales:
        return salesTable(await _collect('/sales', Sale.fromJson, dates, set, onPage), range);
      case ExportSet.purchases:
        return purchasesTable(await _collect('/purchases', Purchase.fromJson, dates, set, onPage), range);
      case ExportSet.payments:
        return paymentsTable(await _collect('/payments', Payment.fromJson, dates, set, onPage), range);
      case ExportSet.expenses:
        // Newest first. Stop once a page reaches a day before the range.
        return expensesTable(
          await _collect(
            '/expenses',
            Expense.fromJson,
            const {},
            set,
            onPage,
            stopWhen: (rows) => rows.any((e) => adDay(e.spentAt).compareTo(range.from) < 0),
          ),
          range,
        );
      case ExportSet.items:
        return itemsTable(await _collect('/items', Item.fromJson, const {}, set, onPage));
      case ExportSet.customers:
        return customersTable(await _collect('/customers', Customer.fromJson, const {}, set, onPage));
    }
  }

  Future<List<T>> _collect<T>(
    String path,
    T Function(Json) parse,
    Query query,
    ExportSet set,
    ExportProgress? onPage, {
    bool Function(List<T> rows)? stopWhen,
  }) async {
    final out = <T>[];
    var page = 1;
    var last = 1;
    do {
      final res = await _api.page(path, parse, query: {...query, 'per_page': 50, 'page': page});
      out.addAll(res.items);
      last = res.meta.lastPage;
      onPage?.call(set, page, last);
      if (stopWhen?.call(res.items) ?? false) break;
      page++;
    } while (page <= last && page <= 200);
    return out;
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) => ReportsRepository(ref.watch(apiClientProvider)));

final summaryProvider = FutureProvider.autoDispose.family<Summary, DateRange>(
  (ref, range) => ref.watch(reportsRepositoryProvider).summary(range),
);

final dailyReportProvider = FutureProvider.autoDispose.family<DailyReport, DateRange>(
  (ref, range) => ref.watch(reportsRepositoryProvider).daily(range),
);

final itemsReportProvider = FutureProvider.autoDispose.family<ItemsReport, DateRange>(
  (ref, range) => ref.watch(reportsRepositoryProvider).items(range),
);

final staffSalesProvider = FutureProvider.autoDispose.family<List<StaffSales>, DateRange>(
  (ref, range) => ref.watch(reportsRepositoryProvider).staff(range),
);

final creditAgeProvider = FutureProvider.autoDispose<CreditAge>((ref) => ref.watch(reportsRepositoryProvider).creditAge());
