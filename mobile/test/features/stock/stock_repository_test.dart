import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/features/stock/data/category_repository.dart';
import 'package:pasal_mobile/features/stock/data/stock_repository.dart';

import '../../helpers/fake_api.dart';
import 'stock_fixtures.dart';

void main() {
  group('StockRepository', () {
    test('history reads the item, the rows and whether a next page exists', () async {
      final api = FakeApi()
        ..on(
          'GET',
          '/items/7/stock-movements',
          (q, b) => {
            'item': {'id': 7, 'name': 'Rice 5kg', 'quantity': 12},
            'data': [movementJson(id: 41, change: -3, reason: 'sale', refType: 'sale', refId: 9, by: 'Sita')],
            'links': {'next': '/api/v1/items/7/stock-movements?page=2', 'prev': null},
            'meta': {'current_page': 1, 'per_page': 30, 'total': 31},
          },
        );

      final page = await StockRepository(api).history(7, 1);

      expect(page.item.name, 'Rice 5kg');
      expect(page.item.quantity, 12);
      expect(page.movements.single.reason, 'sale');
      expect(page.movements.single.refId, 9);
      expect(page.hasMore, isTrue);
    });

    test('a last page has no more pages', () async {
      final api = FakeApi()
        ..on(
          'GET',
          '/items/7/stock-movements',
          (q, b) => {
            'item': {'id': 7, 'name': 'Rice 5kg', 'quantity': 12},
            'data': <Json>[],
            'links': {'next': null, 'prev': null},
          },
        );
      expect((await StockRepository(api).history(7, 2)).hasMore, isFalse);
      expect(api.calls, ['GET /items/7/stock-movements']);
    });

    test('count sends only the given lines, trims the note and passes the key', () async {
      final api = FakeApi()
        ..on(
          'POST',
          '/stock-counts',
          (q, b) => {
            'data': [
              {'item_id': 7, 'item_name': 'Rice 5kg', 'system': 12, 'counted': 10, 'difference': -2},
            ],
            'items_changed': 1,
          },
        );
      final lines = [CountLine(item: item(id: 7, name: 'Rice 5kg', quantity: 12), counted: 10)];

      final result = await StockRepository(api).count(lines: lines, note: '  Month end ', key: 'key-1');

      expect(api.bodies['POST /stock-counts'], [
        {
          'note': 'Month end',
          'items': [
            {'item_id': 7, 'counted': 10},
          ],
        },
      ]);
      expect(api.keys['POST /stock-counts'], ['key-1']);
      expect(result.itemsChanged, 1);
      expect(result.rows.single.difference, -2);
    });

    test('count leaves the note out when it is blank', () async {
      final api = FakeApi()
        ..on('POST', '/stock-counts', (q, b) => {'data': <Json>[], 'items_changed': 0});

      await StockRepository(api).count(lines: const [], note: '   ', key: 'key-2');

      expect((api.bodies['POST /stock-counts']!.single as Map).containsKey('note'), isFalse);
    });

    test('low stock asks the server for low items only', () async {
      Object? seen;
      final api = FakeApi()
        ..on('GET', '/items', (q, b) {
          seen = q?['low_stock'];
          return pagedJson([itemJson(id: 5, name: 'Eggs', quantity: 4, lowStockAt: 10)]);
        });

      final items = await StockRepository(api).lowStockItems();

      expect(seen, 1);
      expect(items.single.name, 'Eggs');
    });
  });

  group('CategoryRepository', () {
    test('save posts a new category and puts an existing one', () async {
      final api = FakeApi()
        ..on('POST', '/categories', (q, b) => {'data': categoryJson(id: 3, name: 'Spices', icon: 'category', color: '#1f8a63')})
        ..on('PUT', '/categories/3', (q, b) => {'data': categoryJson(id: 3, name: 'Spice', icon: 'egg', color: '#2563eb')});
      final repo = CategoryRepository(api);

      final created = await repo.save(name: 'Spices', icon: 'category', color: '#1f8a63');
      final renamed = await repo.save(id: 3, name: 'Spice', icon: 'egg', color: '#2563eb');

      expect(created.name, 'Spices');
      expect(renamed.icon, 'egg');
      expect(api.bodies['POST /categories'], [
        {'name': 'Spices', 'icon': 'category', 'color': '#1f8a63'},
      ]);
      expect(api.bodies['PUT /categories/3'], [
        {'name': 'Spice', 'icon': 'egg', 'color': '#2563eb'},
      ]);
    });

    test('remove deletes by id', () async {
      final api = FakeApi()..on('DELETE', '/categories/3', (q, b) => {'message': 'Deleted.'});
      await CategoryRepository(api).remove(3);
      expect(api.calls, ['DELETE /categories/3']);
    });

    test('itemCounts counts items per category and skips items with none', () async {
      final api = FakeApi()
        ..on(
          'GET',
          '/items',
          (q, b) => pagedJson([
            itemJson(id: 1, name: 'Rice', categoryId: 1),
            itemJson(id: 2, name: 'Dal', categoryId: 1),
            itemJson(id: 3, name: 'Eggs', categoryId: 2),
            itemJson(id: 4, name: 'Salt'),
          ]),
        );

      expect(await CategoryRepository(api).itemCounts(), {1: 2, 2: 1});
    });
  });
}
