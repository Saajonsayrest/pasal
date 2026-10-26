import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/features/stock/data/count_draft.dart';
import 'package:pasal_mobile/features/stock/data/stock_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stock_fixtures.dart';

void main() {
  group('count boxes', () {
    test('parseWhole keeps only whole numbers of 0 or more', () {
      expect(parseWhole('12'), 12);
      expect(parseWhole(' 7 '), 7);
      expect(parseWhole('0'), 0);
      expect(parseWhole(''), isNull);
      expect(parseWhole(null), isNull);
      expect(parseWhole('1.5'), isNull);
      expect(parseWhole('-2'), isNull);
    });

    test('hasInvalidCount ignores empty boxes', () {
      expect(hasInvalidCount(['', '3', '  ']), isFalse);
      expect(hasInvalidCount(['3', '1.5']), isTrue);
    });

    test('countedLines keeps valid counts in item order', () {
      final rice = item(id: 7, name: 'Rice', quantity: 5);
      final sugar = item(id: 8, name: 'Sugar', quantity: 2);
      final lines = countedLines([rice, sugar], {7: '4', 8: 'x'});
      expect(lines.length, 1);
      expect(lines.single.item.id, 7);
      expect(lines.single.counted, 4);
      expect(lines.single.difference, -1);
    });
  });

  group('low stock', () {
    test('suggestedOrder refills to twice the low level and is never below 1', () {
      expect(suggestedOrder(item(id: 1, name: 'Eggs', quantity: 4, lowStockAt: 10)), 16);
      expect(suggestedOrder(item(id: 2, name: 'Salt', quantity: 30, lowStockAt: 10)), 1);
    });

    test('stockFraction is between 0 and 1', () {
      expect(stockFraction(item(id: 1, name: 'Eggs', quantity: 2, lowStockAt: 4)), 0.5);
      expect(stockFraction(item(id: 1, name: 'Eggs', quantity: 9, lowStockAt: 4)), 1.0);
      expect(stockFraction(item(id: 1, name: 'Eggs', quantity: 2, lowStockAt: 0)), 0.0);
    });

    test('groupLowStock sorts groups by name and puts items with no category in their own group', () {
      final items = [
        item(id: 1, name: 'Eggs', quantity: 1, lowStockAt: 5, categoryId: 2),
        item(id: 2, name: 'Rice', quantity: 1, lowStockAt: 5),
        item(id: 3, name: 'Milk', quantity: 1, lowStockAt: 5, categoryId: 2),
      ];
      final categories = [
        Category.fromJson(categoryJson(id: 2, name: 'Dairy', icon: 'egg')),
        Category.fromJson(categoryJson(id: 9, name: 'Other')),
      ];

      final groups = groupLowStock(items, categories, noCategory: 'No category');

      expect(groups.map((g) => g.name).toList(), ['Dairy', 'No category']);
      expect(groups.first.items.map((i) => i.name).toList(), ['Eggs', 'Milk']);
      expect(groups.last.items.single.name, 'Rice');
    });

    test('orderCostPaisa multiplies whole paisa and counts a missing cost as 0', () {
      final rice = item(id: 1, name: 'Rice', costPrice: 90000);
      final staffView = item(id: 2, name: 'Salt');
      expect(orderCostPaisa([(item: rice, quantity: 2), (item: staffView, quantity: 5)]), 180000);
    });
  });

  group('count draft', () {
    test('round trips through the saved text', () {
      const draft = CountDraft(counts: {'7': '12'}, note: 'Month end');
      final back = CountDraft.fromRaw(draft.encode());
      expect(back.counts, {'7': '12'});
      expect(back.note, 'Month end');
    });

    test('a broken saved text gives an empty draft', () {
      expect(CountDraft.fromRaw('not json').isEmpty, isTrue);
      expect(CountDraft.fromRaw(null).isEmpty, isTrue);
    });

    test('saving an empty draft removes the key, a filled one stores it under pasal_count_draft', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await saveCountDraft(prefs, const CountDraft(counts: {'7': '3'}));
      expect(prefs.getString(countDraftKey), contains('"7":"3"'));
      expect(loadCountDraft(prefs).counts, {'7': '3'});

      await saveCountDraft(prefs, const CountDraft());
      expect(prefs.containsKey(countDraftKey), isFalse);
    });
  });
}
