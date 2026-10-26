import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/features/items/data/item_pricing.dart';
import 'package:pasal_mobile/features/items/data/item_repository.dart';
import 'package:pasal_mobile/features/items/data/item_sales.dart';

import '../../../helpers/fake_api.dart';
import '../item_fixtures.dart';

void main() {
  group('pricing (whole paisa)', () {
    test('takes VAT out of a VAT included price', () {
      expect(exVatPaisa(11500, 13), 10177);
    });

    test('keeps the price of an item without VAT', () {
      expect(exVatPaisa(11500, 13, vatApplies: false), 11500);
    });

    test('profit is the price without VAT minus the buying price', () {
      expect(profitPaisa(sellPaisa: 11500, costPaisa: 8650, vatRate: 13, vatApplies: true), 1527);
    });

    test('there is no profit without a buying price (staff)', () {
      expect(profitPaisa(sellPaisa: 11500, costPaisa: null, vatRate: 13, vatApplies: true), isNull);
    });

    test('margin is shown in tenths of a percent with one decimal', () {
      expect(marginTenths(1527, 10177), 150);
      expect(marginText(150), '15.0%');
      expect(marginText(-5), '-0.5%');
    });
  });

  group('sales of the last 30 days', () {
    test('counts bill movements only and splits them into weeks', () {
      final now = DateTime.now();
      final window = salesWindow([
        movementJson(id: 1, change: -2, reason: 'sale', at: now.subtract(const Duration(days: 3))),
        movementJson(id: 2, change: 1, reason: 'sale_return', at: now.subtract(const Duration(days: 3))),
        movementJson(id: 3, change: -4, reason: 'sale', at: now.subtract(const Duration(days: 8))),
        movementJson(id: 4, change: 10, reason: 'purchase', at: now.subtract(const Duration(days: 2))),
        movementJson(id: 5, change: -5, reason: 'sale', at: now.subtract(const Duration(days: 40))),
      ].map(StockMovement.fromJson).toList());

      expect(window.sold, 5);
      expect(window.weeks, [0, 0, 0, 4, 1]);
    });
  });

  group('ItemRepository', () {
    test('list sends the search, the category, low stock and the page', () async {
      final api = FakeApi();
      Query? seen;
      api.on('GET', '/items', (q, b) {
        seen = q;
        return pagedJson([]);
      });

      await ItemRepository(api).list((search: 'rice', categoryId: 2, lowStock: true), page: 3);

      expect(seen!['search'], 'rice');
      expect(seen!['category_id'], 2);
      expect(seen!['low_stock'], 1);
      expect(seen!['trashed'], isNull);
      expect(seen!['page'], 3);
    });

    test('a stock adjustment sends the change, the note and one key', () async {
      final api = FakeApi()..on('POST', '/stock-adjustments', (q, b) => {'data': itemJson(quantity: 8)});

      final saved = await ItemRepository(api).adjustStock(itemId: 7, change: -4, note: 'Damaged', key: 'key-1');

      expect(api.bodies['POST /stock-adjustments'], [
        {'item_id': 7, 'change': -4, 'note': 'Damaged'},
      ]);
      expect(api.keys['POST /stock-adjustments'], ['key-1']);
      expect(saved.quantity, 8);
    });

    test('a new item is sent in paisa with the SKU left out when empty', () async {
      final api = FakeApi()..on('POST', '/items', (q, b) => {'data': itemJson(id: 9, name: 'Sugar 1kg')});
      final draft = ItemDraft(
        name: 'Sugar 1kg',
        sku: null,
        unit: 'pcs',
        vatApplies: true,
        costPrice: 8650,
        sellPrice: 11500,
        lowStockAt: 5,
        categoryId: null,
      );

      final created = await ItemRepository(api).create(draft);

      expect(api.bodies['POST /items'], [draft.toJson()]);
      expect(draft.toJson()['cost_price'], 8650);
      expect(created.id, 9);
    });

    test('suggest asks nothing for an empty text', () async {
      final api = FakeApi();

      expect(await ItemRepository(api).suggest('   '), isEmpty);
      expect(api.calls, isEmpty);
    });

    test('a duplicate name answer tells which item to use', () {
      final error = ApiException(
        422,
        'An item named "Rice 5kg" already exists.',
        errors: {
          'name': ['An item named "Rice 5kg" already exists.'],
        },
        body: {
          'existing_item': {'id': 7, 'name': 'Rice 5kg', 'deleted': true},
        },
      );

      final existing = ExistingItem.fromError(error);

      expect(existing?.id, 7);
      expect(existing?.deleted, isTrue);
      expect(ExistingItem.fromError(ApiException(422, 'No')), isNull);
    });
  });
}
