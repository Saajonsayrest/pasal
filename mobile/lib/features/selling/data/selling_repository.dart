import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';

/// Items on the sell screen: search text and category.
typedef SellItemsQuery = ({String search, int? categoryId});

/// The sales list filters. [from] and [to] are AD dates (YYYY-MM-DD) or null.
typedef SalesQuery = ({String search, bool unpaid, String? from, String? to});

/// What the server says after a return or a cancel.
class ReturnOutcome {
  const ReturnOutcome({required this.refunded, required this.saleBalance, required this.saleCancelled});

  final int refunded;
  final int saleBalance;
  final bool saleCancelled;
}

/// Talks to /items, /categories, /sales, /sales/{id}/returns, /sales/{id}/cancel and /payments.
/// Screens go through the providers below, never through [ApiClient].
class SellingRepository {
  SellingRepository(this._api);

  final ApiClient _api;

  Future<List<Category>> categories() => _api.all('/categories', Category.fromJson);

  Future<Paged<Item>> items({String search = '', int? categoryId, int page = 1}) => _api.page(
        '/items',
        Item.fromJson,
        query: {'search': search, 'category_id': categoryId, 'per_page': 50, 'page': page},
      );

  /// The item whose code (SKU) is exactly [code]. Items in [known] (the list on screen) are checked first.
  Future<Item?> findBySku(String code, {Iterable<Item> known = const []}) async {
    for (final item in known) {
      if (item.sku == code) return item;
    }
    final res = await items(search: code);
    for (final item in res.items) {
      if (item.sku == code) return item;
    }
    return null;
  }

  Future<Sale> createSale(Json body, String key) async {
    final res = await _api.post('/sales', body: body, key: key);
    return Sale.fromJson(res['data'] as Json);
  }

  Future<Sale> sale(int id) async => Sale.fromJson((await _api.get('/sales/$id'))['data'] as Json);

  Future<Paged<Sale>> sales(SalesQuery q, {int page = 1}) => _api.page(
        '/sales',
        Sale.fromJson,
        query: {
          'search': q.search,
          'unpaid': q.unpaid ? true : null,
          'from': q.from,
          'to': q.to,
          'per_page': 50,
          'page': page,
        },
      );

  Future<ReturnOutcome> returnItems(int saleId, Json body, String key) => _outcome('/sales/$saleId/returns', body, key);

  Future<ReturnOutcome> cancelSale(int saleId, Json body, String key) => _outcome('/sales/$saleId/cancel', body, key);

  /// Money in against one bill. Returns what is still owed on it.
  Future<int> takePayment({required int saleId, required int amount, required String method, required String key}) async {
    final res = await _api.post('/payments', body: {'sale_id': saleId, 'amount': amount, 'method': method}, key: key);
    return (res['balance_left'] as num).toInt();
  }

  Future<ReturnOutcome> _outcome(String path, Json body, String key) async {
    final res = await _api.post(path, body: body, key: key);
    final data = res['data'] as Json;
    return ReturnOutcome(
      refunded: (data['refunded'] as num).toInt(),
      saleBalance: (res['sale_balance'] as num).toInt(),
      saleCancelled: res['sale_cancelled'] as bool,
    );
  }
}

final sellingRepositoryProvider = Provider<SellingRepository>((ref) => SellingRepository(ref.watch(apiClientProvider)));

final sellCategoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(sellingRepositoryProvider).categories(),
);

final sellItemsProvider = FutureProvider.autoDispose.family<Paged<Item>, SellItemsQuery>(
  (ref, q) => ref.watch(sellingRepositoryProvider).items(search: q.search, categoryId: q.categoryId),
);

final saleProvider = FutureProvider.autoDispose.family<Sale, int>(
  (ref, id) => ref.watch(sellingRepositoryProvider).sale(id),
);

final salesListProvider = FutureProvider.autoDispose.family<Paged<Sale>, SalesQuery>(
  (ref, q) => ref.watch(sellingRepositoryProvider).sales(q),
);
