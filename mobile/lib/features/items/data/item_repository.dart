import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/utils/bs.dart';

/// What the item list shows. A record has equality built in, so it can be a provider family key.
typedef ItemQuery = ({String search, int? categoryId, bool lowStock});

/// The values the item form sends. Money is whole paisa.
class ItemDraft {
  const ItemDraft({
    required this.name,
    required this.sku,
    required this.unit,
    required this.vatApplies,
    required this.costPrice,
    required this.sellPrice,
    required this.lowStockAt,
    required this.categoryId,
  });

  final String name;
  final String? sku;
  final String unit;
  final bool vatApplies;
  final int costPrice;
  final int sellPrice;
  final int lowStockAt;
  final int? categoryId;

  Json toJson() => {
        'name': name,
        'sku': sku,
        'unit': unit,
        'vat_applies': vatApplies,
        'cost_price': costPrice,
        'sell_price': sellPrice,
        'low_stock_at': lowStockAt,
        'category_id': categoryId,
      };
}

/// The item a duplicate name points to (`existing_item` in a 422 answer).
class ExistingItem {
  const ExistingItem({required this.id, required this.name, required this.deleted});

  factory ExistingItem.fromJson(Json j) => ExistingItem(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        deleted: j['deleted'] as bool? ?? false,
      );

  /// The item named in a failed save, or null when the answer has none.
  static ExistingItem? fromError(ApiException e) {
    final raw = e.body['existing_item'];
    return raw is Map ? ExistingItem.fromJson(Map<String, dynamic>.from(raw)) : null;
  }

  final int id;
  final String name;

  /// True when the name belongs to a deleted item (it can be restored).
  final bool deleted;
}

/// Talks to /items, /categories, /stock-adjustments and /reports/summary. Screens go through the providers.
class ItemRepository {
  ItemRepository(this._api);

  final ApiClient _api;

  Future<Paged<Item>> list(ItemQuery q, {int page = 1, int perPage = 20, bool trashedOnly = false}) => _api.page(
        '/items',
        Item.fromJson,
        query: {
          'search': q.search,
          'category_id': q.categoryId,
          'low_stock': q.lowStock ? 1 : null,
          'trashed': trashedOnly ? 'only' : null,
          'per_page': perPage,
          'page': page,
        },
      );

  Future<int> lowStockCount() async => (await list((search: '', categoryId: null, lowStock: true), perPage: 1)).meta.total;

  Future<List<Item>> deleted() async => (await list((search: '', categoryId: null, lowStock: false), perPage: 50, trashedOnly: true)).items;

  Future<List<Category>> categories() => _api.all('/categories', Category.fromJson);

  Future<Item> get(int id) async => Item.fromJson((await _api.get('/items/$id'))['data'] as Json);

  /// Items whose name starts with, or contains, [q]. Empty text asks nothing.
  Future<List<Item>> suggest(String q) async {
    final text = q.trim();
    if (text.isEmpty) return const [];
    final res = await _api.get('/items/suggest', query: {'q': text, 'limit': 8});
    return [for (final j in res['data'] as List<dynamic>) Item.fromJson(j as Json)];
  }

  Future<Item> create(ItemDraft draft) async => Item.fromJson((await _api.post('/items', body: draft.toJson()))['data'] as Json);

  Future<Item> update(int id, ItemDraft draft) async => Item.fromJson((await _api.patch('/items/$id', body: draft.toJson()))['data'] as Json);

  Future<void> delete(int id) async {
    await _api.delete('/items/$id');
  }

  Future<Item> restore(int id) async => Item.fromJson((await _api.post('/items/$id/restore'))['data'] as Json);

  /// Replaces the photo. The file is sent as the `photo` field.
  Future<void> uploadPhoto(int id, String filePath) async {
    await _api.upload('/items/$id/photo', field: 'photo', filePath: filePath);
  }

  Future<void> deletePhoto(int id) async {
    await _api.delete('/items/$id/photo');
  }

  /// A hand stock change. [change] is positive to add, negative to remove. [key] is one per tap.
  Future<Item> adjustStock({required int itemId, required int change, required String note, required String key}) async {
    final res = await _api.post('/stock-adjustments', body: {'item_id': itemId, 'change': change, 'note': note}, key: key);
    return Item.fromJson(res['data'] as Json);
  }

  Future<Paged<StockMovement>> movements(int id) => _api.page('/items/$id/stock-movements', StockMovement.fromJson, query: {'per_page': 100});

  /// Stock value at buying price for today. Owner only (the server answers 403 to staff).
  Future<int> stockValue() async {
    final today = todayAd();
    final res = await _api.get('/reports/summary', query: {'from': today, 'to': today});
    return Summary.fromJson(res).stockValue;
  }
}
