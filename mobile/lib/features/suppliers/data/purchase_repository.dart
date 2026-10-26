import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/utils/bs.dart';

/// One page of the purchases list. [filter] is `all`, `unpaid` or `month` (this Nepali month).
typedef PurchaseQuery = ({String search, String filter, int? supplierId, int page});

class PurchaseSummary {
  const PurchaseSummary({required this.monthTotal, required this.monthCount, required this.owed, required this.openCount});

  /// Paisa bought this Nepali month, and the number of bills.
  final int monthTotal;
  final int monthCount;

  /// Paisa still to pay on open bills, and the number of open bills.
  final int owed;
  final int openCount;
}

/// Talks to /purchases, /items (for the picker) and /payments for one bill.
class PurchaseRepository {
  PurchaseRepository(this._api);

  final ApiClient _api;

  Future<Paged<Purchase>> page(PurchaseQuery q) {
    final month = bsMonthRange(todayBs().year, todayBs().month);
    final inMonth = q.filter == 'month';
    return _api.page(
      '/purchases',
      Purchase.fromJson,
      query: {
        'search': q.search,
        'unpaid': q.filter == 'unpaid' ? true : null,
        'supplier_id': q.supplierId,
        'from': inMonth ? month.from : null,
        'to': inMonth ? month.to : null,
        'per_page': 20,
        'page': q.page,
      },
    );
  }

  Future<PurchaseSummary> summary() async {
    final month = bsMonthRange(todayBs().year, todayBs().month);
    final monthRows = await _api.all('/purchases', Purchase.fromJson, query: {'from': month.from, 'to': month.to});
    final openRows = await _api.all('/purchases', Purchase.fromJson, query: {'unpaid': true});
    var monthTotal = 0;
    for (final p in monthRows) {
      monthTotal += p.total;
    }
    var owed = 0;
    for (final p in openRows) {
      owed += p.balance;
    }
    return PurchaseSummary(monthTotal: monthTotal, monthCount: monthRows.length, owed: owed, openCount: openRows.length);
  }

  Future<Purchase> get(int id) async => Purchase.fromJson((await _api.get('/purchases/$id'))['data'] as Json);

  /// Saves a bill. Stock goes up. Pass a key from [SaveKey].
  Future<Purchase> create(Json body, String key) async =>
      Purchase.fromJson((await _api.post('/purchases', body: body, key: key))['data'] as Json);

  /// Pays one bill. Returns the paisa still owed on it.
  Future<int> payBill({required int purchaseId, required int amount, required String method, required String key}) async {
    final res = await _api.post('/payments', body: {'purchase_id': purchaseId, 'amount': amount, 'method': method}, key: key);
    return (res['balance_left'] as num).toInt();
  }

  Future<List<Item>> searchItems(String term) async =>
      (await _api.page('/items', Item.fromJson, query: {'search': term, 'per_page': 50})).items;

  Future<Item> item(int id) async => Item.fromJson((await _api.get('/items/$id'))['data'] as Json);
}

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) => PurchaseRepository(ref.watch(apiClientProvider)));

final purchasePageProvider = FutureProvider.autoDispose.family<Paged<Purchase>, PurchaseQuery>(
  (ref, q) => ref.watch(purchaseRepositoryProvider).page(q),
);

final purchaseSummaryProvider = FutureProvider.autoDispose<PurchaseSummary>((ref) => ref.watch(purchaseRepositoryProvider).summary());

final purchaseProvider = FutureProvider.autoDispose.family<Purchase, int>(
  (ref, id) => ref.watch(purchaseRepositoryProvider).get(id),
);

final itemSearchProvider = FutureProvider.autoDispose.family<List<Item>, String>(
  (ref, term) => ref.watch(purchaseRepositoryProvider).searchItems(term),
);
