import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/features/stock/data/category_repository.dart';

/// The item at the top of a stock history answer.
class StockItemRef {
  const StockItemRef({required this.id, required this.name, required this.quantity});

  factory StockItemRef.fromJson(Json j) => StockItemRef(id: j['id'] as int, name: j['name'] as String, quantity: (j['quantity'] as num).toInt());

  final int id;
  final String name;
  final int quantity;
}

/// One page of `GET /items/{id}/stock-movements` (not wrapped in `data` at the top).
class StockHistoryPage {
  const StockHistoryPage({required this.item, required this.movements, required this.hasMore});

  final StockItemRef item;
  final List<StockMovement> movements;
  final bool hasMore;
}

/// One row of the answer to `POST /stock-counts`.
class CountRow {
  const CountRow({required this.itemId, required this.itemName, required this.system, required this.counted, required this.difference});

  factory CountRow.fromJson(Json j) => CountRow(
        itemId: j['item_id'] as int,
        itemName: j['item_name'] as String,
        system: (j['system'] as num).toInt(),
        counted: (j['counted'] as num).toInt(),
        difference: (j['difference'] as num).toInt(),
      );

  final int itemId;
  final String itemName;
  final int system;
  final int counted;
  final int difference;
}

class StockCountResult {
  const StockCountResult({required this.rows, required this.itemsChanged});

  factory StockCountResult.fromJson(Json j) => StockCountResult(
        rows: (j['data'] as List<dynamic>).map((e) => CountRow.fromJson(e as Json)).toList(),
        itemsChanged: (j['items_changed'] as num).toInt(),
      );

  final List<CountRow> rows;
  final int itemsChanged;
}

/// One item with the number somebody counted on the shelf.
class CountLine {
  const CountLine({required this.item, required this.counted});

  final Item item;
  final int counted;

  /// Counted minus the system stock. Negative when the shelf has less.
  int get difference => counted - item.quantity;
}

class LowStockData {
  const LowStockData({required this.items, required this.categories});

  final List<Item> items;
  final List<Category> categories;
}

/// Talks to the stock endpoints. Screens read through the providers below, never through [ApiClient].
class StockRepository {
  StockRepository(this._api);

  final ApiClient _api;

  Future<StockHistoryPage> history(int itemId, int page) async {
    final res = await _api.get('/items/$itemId/stock-movements', query: {'page': page});
    final links = res['links'] as Json?;
    return StockHistoryPage(
      item: StockItemRef.fromJson(res['item'] as Json),
      movements: (res['data'] as List<dynamic>).map((e) => StockMovement.fromJson(e as Json)).toList(),
      hasMore: links?['next'] != null,
    );
  }

  Future<List<Item>> items() => _api.all('/items', Item.fromJson);

  Future<List<Item>> lowStockItems() => _api.all('/items', Item.fromJson, query: {'low_stock': 1});

  /// Only the lines that have a count. The server saves all of them at once or none.
  Future<StockCountResult> count({required List<CountLine> lines, required String key, String? note}) async {
    final trimmed = note?.trim() ?? '';
    final res = await _api.post(
      '/stock-counts',
      body: {
        if (trimmed.isNotEmpty) 'note': trimmed,
        'items': [for (final line in lines) {'item_id': line.item.id, 'counted': line.counted}],
      },
      key: key,
    );
    return StockCountResult.fromJson(res);
  }
}

final stockRepositoryProvider = Provider<StockRepository>((ref) => StockRepository(ref.watch(apiClientProvider)));

/// One page of an item's history. The screen asks for more pages as the person taps "Load more".
final stockHistoryPageProvider = FutureProvider.autoDispose.family<StockHistoryPage, ({int itemId, int page})>(
  (ref, query) => ref.watch(stockRepositoryProvider).history(query.itemId, query.page),
);

final allItemsProvider = FutureProvider.autoDispose<List<Item>>((ref) => ref.watch(stockRepositoryProvider).items());

final lowStockProvider = FutureProvider.autoDispose<LowStockData>((ref) async {
  final items = await ref.watch(stockRepositoryProvider).lowStockItems();
  final categories = await ref.watch(categoriesProvider.future);
  return LowStockData(items: items, categories: categories);
});
