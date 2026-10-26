import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/features/reports/data/csv.dart';
import 'package:pasal_mobile/features/reports/data/range.dart';

/// The lists the export screen can pick. A `dated` list is cut by the date range.
enum ExportSet {
  sales(dated: true),
  purchases(dated: true),
  payments(dated: true),
  expenses(dated: true),
  items(dated: false),
  customers(dated: false);

  const ExportSet({required this.dated});

  final bool dated;
}

/// One CSV table: the file name, the header line and the rows.
class CsvTable {
  const CsvTable({required this.fileName, required this.head, required this.rows});

  final String fileName;
  final List<String> head;
  final List<List<Object?>> rows;

  CsvFile get file => CsvFile(name: fileName, text: csvText(head, rows));
}

/// "2026-10-26" for a date or a full date-time. Empty when there is none.
String adDay(String? value) {
  if (value == null || value.isEmpty) return '';
  return value.length > 10 ? adOfStamp(value) : value.substring(0, 10);
}

/// "Kartik 9, 2083" with English month names, for the BS column.
String bsDay(String? value) {
  final ad = adDay(value);
  if (ad.isEmpty) return '';
  final b = adToBs(ad);
  return '${monthName(b.month, ne: false)} ${b.day}, ${b.year}';
}

/// Whole paisa as the text of an amount box ("1250.5"). Empty when there is no amount.
String rupees(int? paisa) => paisa == null ? '' : fromPaisa(paisa);

CsvTable salesTable(List<Sale> sales, DateRange range) => CsvTable(
      fileName: 'pasal-sales-${range.from}-to-${range.to}.csv',
      head: const ['Bill no', 'Date (AD)', 'Date (BS)', 'Customer', 'Sold by', 'Subtotal', 'Discount', 'VAT', 'Total', 'Returned', 'Paid', 'Balance', 'Cancelled'],
      rows: [
        for (final s in sales)
          [
            s.billNo ?? s.id,
            adDay(s.soldAt),
            bsDay(s.soldAt),
            s.customer?.name ?? '',
            s.soldBy ?? '',
            rupees(s.subtotal),
            rupees(s.discount),
            rupees(s.vatAmount),
            rupees(s.total),
            rupees(s.returnedTotal),
            rupees(s.paid),
            rupees(s.balance),
            s.isCancelled ? 'Yes' : 'No',
          ],
      ],
    );

CsvTable purchasesTable(List<Purchase> purchases, DateRange range) => CsvTable(
      fileName: 'pasal-purchases-${range.from}-to-${range.to}.csv',
      head: const ['Bill no', 'Bill date (AD)', 'Bought on (AD)', 'Bought on (BS)', 'Supplier', 'Total', 'VAT', 'Paid', 'Balance'],
      rows: [
        for (final p in purchases)
          [
            p.billNo ?? p.id,
            adDay(p.billDate),
            adDay(p.boughtAt),
            bsDay(p.boughtAt),
            p.supplier?.name ?? '',
            rupees(p.total),
            rupees(p.vatAmount),
            rupees(p.paid),
            rupees(p.balance),
          ],
      ],
    );

CsvTable paymentsTable(List<Payment> payments, DateRange range) => CsvTable(
      fileName: 'pasal-payments-${range.from}-to-${range.to}.csv',
      head: const ['Paid on (AD)', 'Paid on (BS)', 'Direction', 'Party', 'Method', 'Amount', 'Sale ID', 'Purchase ID'],
      rows: [
        for (final p in payments) [adDay(p.paidAt), bsDay(p.paidAt), p.direction, p.party ?? '', p.method, rupees(p.amount), p.saleId, p.purchaseId],
      ],
    );

/// Only the expenses whose day is inside the range.
CsvTable expensesTable(List<Expense> expenses, DateRange range) {
  final inRange = expenses.where((e) {
    final day = adDay(e.spentAt);
    return day.compareTo(range.from) >= 0 && day.compareTo(range.to) <= 0;
  });
  return CsvTable(
    fileName: 'pasal-expenses-${range.from}-to-${range.to}.csv',
    head: const ['Date (AD)', 'Date (BS)', 'Title', 'Category', 'Amount'],
    rows: [
      for (final e in inRange) [adDay(e.spentAt), bsDay(e.spentAt), e.title, e.category ?? '', rupees(e.amount)],
    ],
  );
}

CsvTable itemsTable(List<Item> items, {String? today}) => CsvTable(
      fileName: 'pasal-items-${today ?? todayAd()}.csv',
      head: const ['Name', 'SKU', 'Unit', 'Sell price', 'Buying price', 'Quantity', 'Low stock at', 'VAT applies'],
      rows: [
        for (final i in items) [i.name, i.sku ?? '', i.unit, rupees(i.sellPrice), rupees(i.costPrice), i.quantity, i.lowStockAt, i.vatApplies ? 'Yes' : 'No'],
      ],
    );

CsvTable customersTable(List<Customer> customers, {String? today}) => CsvTable(
      fileName: 'pasal-customers-${today ?? todayAd()}.csv',
      head: const ['Name', 'Phone', 'Address', 'PAN', 'Credit limit', 'Owes', 'Last sale (AD)', 'Last sale (BS)'],
      rows: [
        for (final c in customers)
          [c.name, c.phone ?? '', c.address ?? '', c.pan ?? '', rupees(c.creditLimit), rupees(c.owes ?? 0), adDay(c.lastSaleAt), bsDay(c.lastSaleAt)],
      ],
    );
