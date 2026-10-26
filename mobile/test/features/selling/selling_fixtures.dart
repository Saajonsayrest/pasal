import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/features/selling/data/cart.dart';

/// Item rows in the API shape. Fake data only.
Map<String, dynamic> itemJson(int id, String name, int price, {int qty = 5, String? sku, bool vat = true, bool low = false}) => {
      'id': id,
      'category_id': null,
      'name': name,
      'sku': sku,
      'unit': 'pcs',
      'vat_applies': vat,
      'cost_price': null,
      'sell_price': price,
      'quantity': qty,
      'low_stock_at': 2,
      'is_low_stock': low,
      'photo_url': null,
    };

Map<String, dynamic> customerJson({int id = 4, String name = 'Hari', int owes = 6300, int? creditLimit}) => {
      'id': id,
      'name': name,
      'phone': '9800000000',
      'address': null,
      'pan': null,
      'credit_limit': creditLimit,
      'owes': owes,
      'last_sale_at': null,
      'oldest_unpaid_at': null,
    };

Map<String, dynamic> lineJson({int id = 52, int qty = 1, int price = 11300, int returned = 0, String name = 'Rice 5kg'}) => {
      'id': id,
      'item_id': 7,
      'item_name': name,
      'quantity': qty,
      'unit_price': price,
      'discount': 0,
      'line_total': qty * price,
      'returned_quantity': returned,
    };

Map<String, dynamic> paymentJson({int id = 9, int amount = 5000, String direction = 'in', String method = 'cash'}) => {
      'id': id,
      'direction': direction,
      'sale_id': 31,
      'purchase_id': null,
      'amount': amount,
      'method': method,
      'paid_at': '2026-10-26T07:30:00+00:00',
      'party': null,
    };

/// A sale in the API shape. Totals are given by the test, the list fields are optional.
Map<String, dynamic> saleJson({
  int id = 31,
  String? billNo = 'S-0031',
  Map<String, dynamic>? customer,
  int subtotal = 11300,
  int discount = 0,
  int total = 11300,
  int returnedTotal = 0,
  int paid = 5000,
  int balance = 6300,
  String? cancelledAt,
  List<Map<String, dynamic>>? items,
  List<Map<String, dynamic>> payments = const [],
  List<Map<String, dynamic>> returns = const [],
}) =>
    {
      'id': id,
      'bill_no': billNo,
      'customer_id': customer?['id'],
      'customer': customer,
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'returned_total': returnedTotal,
      'paid': paid,
      'balance': balance,
      'cancelled_at': cancelledAt,
      'vat_rate': 13.0,
      'taxable_amount': 10000,
      'vat_amount': 1300,
      'exempt_amount': 0,
      'sold_at': '2026-10-26T07:26:03+00:00',
      'note': null,
      'sold_by': 'Asha Shrestha',
      'items': items ?? [lineJson()],
      'payments': payments,
      'returns': returns,
    };

Map<String, dynamic> returnJson({int refunded = 0, int total = 11300, String kind = 'return'}) => {
      'id': 3,
      'sale_id': 31,
      'kind': kind,
      'returned_at': '2026-10-26T08:00:00+00:00',
      'total': total,
      'vat_amount': 1300,
      'refunded': refunded,
      'restocked': true,
      'note': null,
    };

CartItem riceItem({int qty = 3}) => CartItem(id: 7, name: 'Rice 5kg', unit: 'pcs', sellPrice: 11300, quantity: qty, vatApplies: true);

CartItem milkItem({int qty = 2}) => CartItem(id: 9, name: 'Milk 500ml', unit: 'pcs', sellPrice: 5000, quantity: qty, vatApplies: false);

Customer hariCustomer() => Customer.fromJson(customerJson(creditLimit: 20000, owes: 0));
