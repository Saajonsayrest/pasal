import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/utils/icon_names.dart';
import 'package:pasal_mobile/features/stock/data/stock_repository.dart';

/// A whole number typed in a count box, or null when the box is empty or holds something else.
int? parseWhole(String? raw) {
  final text = raw?.trim() ?? '';
  if (!RegExp(r'^\d+$').hasMatch(text)) return null;
  return int.tryParse(text);
}

/// True when some box holds text that is not a whole number.
bool hasInvalidCount(Iterable<String> typed) => typed.any((t) => t.trim().isNotEmpty && parseWhole(t) == null);

/// The lines that have a valid count, in the order of [items].
List<CountLine> countedLines(List<Item> items, Map<int, String> typed) => [
      for (final item in items)
        if (parseWhole(typed[item.id]) case final n?) CountLine(item: item, counted: n),
    ];

/// Refill to twice the low level. Never less than 1.
int suggestedOrder(Item item) => math.max(1, item.lowStockAt * 2 - item.quantity);

/// How full the item is against its low level, from 0 to 1. Used for the bar only.
double stockFraction(Item item) {
  if (item.lowStockAt <= 0) return 0;
  final ratio = item.quantity / item.lowStockAt;
  return math.min(1.0, math.max(0.0, ratio));
}

class LowStockGroup {
  LowStockGroup({required this.key, required this.name, required this.icon});

  /// The category id as text, or `none` for items with no category.
  final String key;
  final String name;
  final IconData icon;
  final List<Item> items = [];
}

/// Groups low stock items by category, sorted by category name. [noCategory] is the label for items without one.
List<LowStockGroup> groupLowStock(List<Item> items, List<Category> categories, {required String noCategory}) {
  final byId = {for (final c in categories) c.id: c};
  final groups = <String, LowStockGroup>{};
  for (final item in items) {
    final categoryId = item.categoryId;
    final cat = categoryId == null ? null : byId[categoryId];
    final key = categoryId == null ? 'none' : '$categoryId';
    groups
        .putIfAbsent(
          key,
          () => LowStockGroup(
            key: key,
            name: cat?.name ?? noCategory,
            icon: cat == null ? Icons.inventory_2_rounded : symbolIcon(cat.icon),
          ),
        )
        .items
        .add(item);
  }
  return groups.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}

/// Buying cost of order lines, in paisa. An item without a cost (the staff view) counts as 0.
int orderCostPaisa(List<({Item item, int quantity})> lines) => lines.fold(0, (sum, l) => sum + l.quantity * (l.item.costPrice ?? 0));
