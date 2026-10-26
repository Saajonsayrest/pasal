import 'package:pasal_mobile/core/models/models.dart';

/// Fake stock data in the API shape. Names and numbers only.

Json itemJson({
  required int id,
  required String name,
  int quantity = 0,
  int lowStockAt = 0,
  int? categoryId,
  int sellPrice = 0,
  int? costPrice = 0,
  String? sku,
  String unit = 'pcs',
}) =>
    {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'sku': sku,
      'unit': unit,
      'vat_applies': true,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'quantity': quantity,
      'low_stock_at': lowStockAt,
      'is_low_stock': quantity <= lowStockAt,
      'photo_url': null,
    };

Json categoryJson({required int id, required String name, String? icon, String? color}) => {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
    };

Json movementJson({
  required int id,
  required int change,
  required String reason,
  String? refType,
  int? refId,
  String? note,
  String? by,
  String at = '2026-10-25T05:00:00+00:00',
}) =>
    {
      'id': id,
      'change': change,
      'reason': reason,
      'ref_type': refType,
      'ref_id': refId,
      'note': note,
      'by': by,
      'at': at,
    };

Item item({
  required int id,
  required String name,
  int quantity = 0,
  int lowStockAt = 0,
  int? categoryId,
  int? costPrice,
}) =>
    Item.fromJson(itemJson(id: id, name: name, quantity: quantity, lowStockAt: lowStockAt, categoryId: categoryId, costPrice: costPrice));
