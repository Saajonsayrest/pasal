import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/features/reports/data/export_tables.dart';

Sale _sale({int id = 31, String soldAt = '2026-10-18T07:26:03+00:00', int total = 11300, int paid = 5000, String? cancelledAt}) => Sale.fromJson({
      'id': id,
      'bill_no': 'S-0031',
      'customer': null,
      'subtotal': total,
      'discount': 0,
      'total': total,
      'returned_total': 0,
      'paid': paid,
      'balance': total - paid,
      'cancelled_at': cancelledAt,
      'vat_rate': 13,
      'taxable_amount': 10000,
      'vat_amount': 1300,
      'exempt_amount': 0,
      'sold_at': soldAt,
      'sold_by': 'Asha',
    });

const _range = (from: '2026-10-01', to: '2026-10-31');

void main() {
  test('adDay takes the Nepal day of a date-time and keeps a plain date', () {
    expect(adDay('2026-10-26T07:26:03+00:00'), '2026-10-26');
    expect(adDay('2026-10-26'), '2026-10-26');
    expect(adDay(null), '');
    expect(adDay(''), '');
  });

  test('bsDay gives the Nepali date with English month names', () {
    expect(bsDay('2026-10-18'), 'Kartik 1, 2083');
    expect(bsDay(null), '');
  });

  test('rupees turns paisa into the text of an amount box', () {
    expect(rupees(11300), '113');
    expect(rupees(1250), '12.5');
    expect(rupees(null), '');
  });

  test('sales table has the file name, the header and one row per sale', () {
    final table = salesTable([_sale(), _sale(id: 32, cancelledAt: '2026-10-19T00:00:00+00:00')], _range);
    expect(table.fileName, 'pasal-sales-2026-10-01-to-2026-10-31.csv');
    expect(table.head.first, 'Bill no');
    expect(table.rows.length, 2);
    expect(table.rows.first, ['S-0031', '2026-10-18', 'Kartik 1, 2083', '', 'Asha', '113', '0', '13', '113', '0', '50', '63', 'No']);
    expect(table.rows.last.last, 'Yes');
  });

  test('expenses outside the dates are left out', () {
    final expenses = [
      Expense.fromJson({'id': 1, 'title': 'Electricity', 'category': 'bills', 'amount': 150000, 'spent_at': '2026-10-20'}),
      Expense.fromJson({'id': 2, 'title': 'Old bill', 'category': null, 'amount': 5000, 'spent_at': '2026-09-30'}),
      Expense.fromJson({'id': 3, 'title': 'Last day', 'category': null, 'amount': 100, 'spent_at': '2026-10-31T10:00:00+00:00'}),
    ];
    final table = expensesTable(expenses, _range);
    expect(table.rows.map((r) => r[2]), ['Electricity', 'Last day']);
    expect(table.rows.first[4], '1500');
  });

  test('items and customers are named with today and keep blank cells empty', () {
    final items = [
      Item.fromJson({
        'id': 7,
        'name': 'Rice 5kg',
        'sku': null,
        'unit': 'pcs',
        'vat_applies': true,
        'cost_price': null,
        'sell_price': 11300,
        'quantity': 4,
        'low_stock_at': 2,
        'is_low_stock': false,
      }),
    ];
    final itemTable = itemsTable(items, today: '2026-10-26');
    expect(itemTable.fileName, 'pasal-items-2026-10-26.csv');
    expect(itemTable.rows.single, ['Rice 5kg', '', 'pcs', '113', '', 4, 2, 'Yes']);

    final customers = [
      Customer.fromJson({'id': 4, 'name': 'Hari', 'phone': null, 'credit_limit': null, 'owes': 6340, 'last_sale_at': null}),
    ];
    final customerTable = customersTable(customers, today: '2026-10-26');
    expect(customerTable.fileName, 'pasal-customers-2026-10-26.csv');
    expect(customerTable.rows.single, ['Hari', '', '', '', '', '63.4', '', '']);
  });

  test('a table turns into a CSV file with its text', () {
    final file = salesTable([_sale()], _range).file;
    expect(file.name, 'pasal-sales-2026-10-01-to-2026-10-31.csv');
    expect(file.text.split('\r\n').first, 'Bill no,Date (AD),Date (BS),Customer,Sold by,Subtotal,Discount,VAT,Total,Returned,Paid,Balance,Cancelled');
  });
}
