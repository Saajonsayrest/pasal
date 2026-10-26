/// An item in the API shape. Defaults: Rice 5kg, sell Rs 115 (VAT included), buying Rs 86.50, 12 pcs.
Map<String, dynamic> itemJson({
  int id = 7,
  String name = 'Rice 5kg',
  String? sku,
  int? categoryId,
  String unit = 'pcs',
  bool vatApplies = true,
  int? costPrice = 8650,
  int sellPrice = 11500,
  int quantity = 12,
  int lowStockAt = 3,
  bool isLowStock = false,
  String? photoUrl,
}) =>
    {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'sku': sku,
      'unit': unit,
      'vat_applies': vatApplies,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'quantity': quantity,
      'low_stock_at': lowStockAt,
      'is_low_stock': isLowStock,
      'photo_url': photoUrl,
    };

Map<String, dynamic> categoryJson(int id, String name) => {'id': id, 'name': name, 'icon': null, 'color': null};

Map<String, dynamic> movementJson({
  required int id,
  required int change,
  required String reason,
  required DateTime at,
  String? by,
  String? note,
}) =>
    {
      'id': id,
      'change': change,
      'reason': reason,
      'ref_type': null,
      'ref_id': null,
      'note': note,
      'by': by,
      'at': at.toUtc().toIso8601String(),
    };

Map<String, dynamic> summaryJson({int stockValue = 0}) => {
      'from': '2026-10-26',
      'to': '2026-10-26',
      'stock_value': stockValue,
    };
