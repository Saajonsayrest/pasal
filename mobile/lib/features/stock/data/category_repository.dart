import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';

/// Talks to /categories. Reading is for everyone, changing is owner only (the server checks).
class CategoryRepository {
  CategoryRepository(this._api);

  final ApiClient _api;

  Future<List<Category>> list() => _api.all('/categories', Category.fromJson);

  /// Items per category id. A category with no items is missing from the map.
  Future<Map<int, int>> itemCounts() async {
    final items = await _api.all('/items', Item.fromJson);
    final counts = <int, int>{};
    for (final item in items) {
      final id = item.categoryId;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  /// Creates a category when [id] is null, otherwise updates it.
  Future<Category> save({int? id, required String name, required String icon, required String color}) async {
    final body = {'name': name, 'icon': icon, 'color': color};
    final res = id == null ? await _api.post('/categories', body: body) : await _api.put('/categories/$id', body: body);
    return Category.fromJson(res['data'] as Json);
  }

  /// Items keep existing. They just lose their category.
  Future<void> remove(int id) => _api.delete('/categories/$id');
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) => CategoryRepository(ref.watch(apiClientProvider)));

final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) => ref.watch(categoryRepositoryProvider).list());

final categoryItemCountsProvider = FutureProvider.autoDispose<Map<int, int>>((ref) => ref.watch(categoryRepositoryProvider).itemCounts());
