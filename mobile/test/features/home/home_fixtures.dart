import 'package:pasal_mobile/core/models/models.dart';

/// Answers in the API shape, for the home and notification tests. All names and numbers are fake.

Json pagedWithTotal(List<Json> rows, int total) => {
      'data': rows,
      'meta': {'current_page': 1, 'last_page': 1, 'per_page': 1, 'total': total},
    };

Json saleJson({
  required int id,
  required int total,
  String? customer,
  int returned = 0,
  int paid = 0,
  String? soldBy,
  String? cancelledAt,
}) =>
    {
      'id': id,
      'bill_no': 'S-00$id',
      'customer_id': customer == null ? null : id,
      'customer': customer == null ? null : {'id': id, 'name': customer, 'phone': null, 'address': null, 'pan': null},
      'subtotal': total,
      'discount': 0,
      'total': total,
      'returned_total': returned,
      'paid': paid,
      'balance': total - returned - paid,
      'cancelled_at': cancelledAt,
      'vat_rate': 13.0,
      'taxable_amount': 0,
      'vat_amount': 0,
      'exempt_amount': 0,
      'sold_at': '2026-10-26T07:26:03+00:00',
      'note': null,
      'sold_by': soldBy,
    };

Json itemJson({required int id, required String name, required int quantity}) => {
      'id': id,
      'name': name,
      'unit': 'kg',
      'vat_applies': true,
      'sell_price': 10000,
      'quantity': quantity,
      'low_stock_at': 3,
      'is_low_stock': true,
    };

Json customerJson(int id, String name, int owes) => {
      'id': id,
      'name': name,
      'phone': '98000000$id',
      'address': null,
      'pan': null,
      'credit_limit': null,
      'owes': owes,
      'last_sale_at': null,
      'oldest_unpaid_at': null,
    };

Json summaryJson({required int sales, required int profit, required int cost, required int expenses}) => {
      'from': '2026-10-01',
      'to': '2026-10-26',
      'sales_total': sales,
      'vat_collected': 0,
      'cost_of_goods': cost,
      'expenses_total': expenses,
      'profit': profit,
      'stock_value': 0,
      'owed_to_us': 0,
      'we_owe': 0,
    };

Json vatPreviewJson({required int payable}) => {
      'period_from': '2026-09-17',
      'period_to': '2026-10-17',
      'due_date': '2026-11-11',
      'vat_rate': 13.0,
      'sales_bills': 10,
      'sales_taxable': 0,
      'sales_exempt': 0,
      'output_vat': 0,
      'purchase_bills_with_vat': 0,
      'purchases_taxable': 0,
      'input_vat': 0,
      'carry_in': 0,
      'payable': payable,
      'carry_out': 0,
      'carry_in_source': 'opening value you typed (0 if none)',
    };
