import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/features/items/data/item_repository.dart';

final itemRepositoryProvider = Provider<ItemRepository>((ref) => ItemRepository(ref.watch(apiClientProvider)));

/// The first page of the item list. Later pages are loaded by the list screen.
final itemListProvider = FutureProvider.autoDispose.family<Paged<Item>, ItemQuery>(
  (ref, query) => ref.watch(itemRepositoryProvider).list(query),
);

final itemCategoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(itemRepositoryProvider).categories(),
);

final itemDetailProvider = FutureProvider.autoDispose.family<Item, int>(
  (ref, id) => ref.watch(itemRepositoryProvider).get(id),
);

final itemMovementsProvider = FutureProvider.autoDispose.family<Paged<StockMovement>, int>(
  (ref, id) => ref.watch(itemRepositoryProvider).movements(id),
);

/// Type-ahead for the item name. An empty text gives an empty list without a request.
final itemSuggestProvider = FutureProvider.autoDispose.family<List<Item>, String>(
  (ref, text) => ref.watch(itemRepositoryProvider).suggest(text),
);

final lowStockCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(itemRepositoryProvider).lowStockCount(),
);

final deletedItemsProvider = FutureProvider.autoDispose<List<Item>>(
  (ref) => ref.watch(itemRepositoryProvider).deleted(),
);

final stockValueProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(itemRepositoryProvider).stockValue(),
);
