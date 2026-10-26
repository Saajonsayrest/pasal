import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/features/settings/data/csv.dart';

/// The lists the phone can export as CSV.
enum ExportKind { items, customers, suppliers, sales, expenses }

/// Called after each page is read: which list, the page just read, and the last page number.
typedef ExportProgress = void Function(ExportKind kind, int page, int lastPage);

const _maxPages = 200;
const _perPage = 50;

/// Builds the CSV text of each list by reading every page of the API. Money is written as rupees (paisa / 100).
class BackupRepository {
  BackupRepository(this._api);

  final ApiClient _api;

  Future<String> build(ExportKind kind, {ExportProgress? onProgress}) async {
    switch (kind) {
      case ExportKind.items:
        final categories = await _api.all('/categories', Category.fromJson);
        final names = {for (final c in categories) c.id: c.name};
        final items = await _fetchAll('/items', Item.fromJson, kind, onProgress);
        return csvTable(
          ['Name', 'SKU', 'Unit', 'Category', 'Sell price (Rs)', 'Buying price (Rs)', 'Stock', 'Low stock level', 'VAT applies'],
          [
            for (final i in items)
              [
                i.name,
                i.sku,
                i.unit,
                i.categoryId == null ? '' : names[i.categoryId] ?? '',
                fromPaisa(i.sellPrice),
                i.costPrice == null ? '' : fromPaisa(i.costPrice!),
                i.quantity,
                i.lowStockAt,
                i.vatApplies ? 'Yes' : 'No',
              ],
          ],
        );
      case ExportKind.customers:
        final customers = await _fetchAll('/customers', Customer.fromJson, kind, onProgress);
        return csvTable(
          ['Name', 'Phone', 'Address', 'PAN', 'Credit limit (Rs)', 'Owes (Rs)'],
          [
            for (final c in customers)
              [c.name, c.phone, c.address, c.pan, _rupees(c.creditLimit), _rupees(c.owes ?? 0)],
          ],
        );
      case ExportKind.suppliers:
        final suppliers = await _fetchAll('/suppliers', Supplier.fromJson, kind, onProgress);
        return csvTable(
          ['Name', 'Phone', 'Address', 'PAN', 'We owe (Rs)'],
          [
            for (final s in suppliers) [s.name, s.phone, s.address, s.pan, _rupees(s.weOwe ?? 0)],
          ],
        );
      case ExportKind.sales:
        final sales = await _fetchAll('/sales', Sale.fromJson, kind, onProgress);
        return csvTable(
          ['Bill no', 'Date (AD)', 'Sold at (UTC)', 'Customer', 'Subtotal (Rs)', 'Discount (Rs)', 'Total (Rs)', 'Paid (Rs)', 'Balance (Rs)', 'Returned (Rs)', 'VAT (Rs)', 'Cancelled', 'Sold by'],
          [
            for (final s in sales)
              [
                s.billNo,
                adOfStamp(s.soldAt),
                s.soldAt,
                s.customer?.name,
                fromPaisa(s.subtotal),
                fromPaisa(s.discount),
                fromPaisa(s.total),
                fromPaisa(s.paid),
                fromPaisa(s.balance),
                fromPaisa(s.returnedTotal),
                fromPaisa(s.vatAmount),
                s.cancelledAt == null ? 'No' : 'Yes',
                s.soldBy,
              ],
          ],
        );
      case ExportKind.expenses:
        final expenses = await _fetchAll('/expenses', Expense.fromJson, kind, onProgress);
        return csvTable(
          ['Date (AD)', 'Title', 'Category', 'Amount (Rs)'],
          [
            for (final e in expenses) [adOfStamp(e.spentAt), e.title, e.category, fromPaisa(e.amount)],
          ],
        );
    }
  }

  Future<List<T>> _fetchAll<T>(String path, T Function(Json) parse, ExportKind kind, ExportProgress? onProgress) async {
    final out = <T>[];
    var lastPage = 1;
    for (var page = 1; page <= lastPage && page <= _maxPages; page++) {
      final res = await _api.page(path, parse, query: {'per_page': _perPage, 'page': page});
      out.addAll(res.items);
      lastPage = res.meta.lastPage;
      onProgress?.call(kind, page, lastPage);
    }
    return out;
  }

  /// Empty text for a missing amount, otherwise the rupee text ("1250.5").
  static String _rupees(int? paisa) => paisa == null ? '' : fromPaisa(paisa);
}

final backupRepositoryProvider = Provider<BackupRepository>((ref) => BackupRepository(ref.watch(apiClientProvider)));
