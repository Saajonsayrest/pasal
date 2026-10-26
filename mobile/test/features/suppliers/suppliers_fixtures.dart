// JSON in the API shape for the supplier and purchase tests. Fake data only.

Map<String, dynamic> supplierJson(int id, String name, {int? weOwe, String? phone}) => {
      'id': id,
      'name': name,
      'phone': phone,
      'address': null,
      'pan': null,
      'note': null,
      'we_owe': weOwe,
      'last_purchase_at': null,
    };

Map<String, dynamic> itemJson(int id, String name, {int costPrice = 10000, int quantity = 12}) => {
      'id': id,
      'category_id': null,
      'name': name,
      'sku': null,
      'unit': 'pcs',
      'vat_applies': true,
      'cost_price': costPrice,
      'sell_price': 12000,
      'quantity': quantity,
      'low_stock_at': 3,
      'is_low_stock': false,
      'photo_url': null,
    };

Map<String, dynamic> purchaseJson(
  int id, {
  String? billNo,
  required int total,
  required int paid,
  int vat = 0,
  int supplierId = 3,
  String supplierName = 'Himal Traders',
  String boughtAt = '2026-10-24T07:26:03.000000Z',
}) =>
    {
      'id': id,
      'bill_no': billNo,
      'bill_date': '2026-10-24',
      'supplier_id': supplierId,
      'supplier': supplierJson(supplierId, supplierName),
      'total': total,
      'paid': paid,
      'balance': total - paid,
      'vat_amount': vat,
      'bought_at': boughtAt,
      'note': null,
      'items': [
        {'item_id': 7, 'item_name': 'Rice 5kg', 'quantity': 100, 'unit_cost': 10000, 'line_total': total - vat},
      ],
      'payments': <Object>[],
    };

/// The supplier ledger: two open bills (the first one bought earlier) and one payment on the newer bill.
Map<String, dynamic> ledgerJson() => {
      'supplier': supplierJson(3, 'Himal Traders', weOwe: 1130000, phone: '9800000003'),
      'total_purchases': 2630000,
      'total_paid': 1500000,
      'we_owe': 1130000,
      'purchases': [
        {'id': 12, 'bill_no': 'INV-889', 'bought_at': '2026-10-24T07:26:03.000000Z', 'total': 1130000, 'paid': 500000, 'balance': 630000},
        {'id': 11, 'bill_no': 'INV-700', 'bought_at': '2026-10-01T07:26:03.000000Z', 'total': 1500000, 'paid': 1000000, 'balance': 500000},
      ],
      'payments': [
        {'id': 5, 'direction': 'out', 'sale_id': null, 'purchase_id': 12, 'amount': 500000, 'method': 'cash', 'paid_at': '2026-10-24T07:26:03+00:00', 'party': null},
      ],
    };
