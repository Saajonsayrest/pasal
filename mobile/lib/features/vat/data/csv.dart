import 'dart:convert';
import 'dart:typed_data';

import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/features/vat/data/vat_helpers.dart';

final _formulaStart = RegExp(r'^[=+\-@\t\r]');
final _quoteNeeded = RegExp(r'[",\n\r]');

/// One CSV cell. A cell that starts with = + - @ tab or CR can run as a formula in a spreadsheet,
/// so a quote is put in front of it. Cells with commas, quotes or line breaks are wrapped in quotes.
String csvCell(Object? value) {
  final text = value?.toString() ?? '';
  final safe = _formulaStart.hasMatch(text) ? "'$text" : text;
  return _quoteNeeded.hasMatch(safe) ? '"${safe.replaceAll('"', '""')}"' : safe;
}

/// Rows joined with CRLF, the usual CSV line ending.
String csvText(List<String> header, List<List<Object?>> rows) =>
    <List<Object?>>[header, ...rows].map((cells) => cells.map(csvCell).join(',')).join('\r\n');

/// The file bytes: UTF-8 with a byte order mark, so spreadsheet apps read Nepali text correctly.
Uint8List csvBytes(String text) => Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);

String bookFileName({required bool sales, required String period}) => '${sales ? 'sales' : 'purchase'}-book-$period.csv';

const salesBookHeader = ['Date', 'Bill no', 'Buyer', 'Buyer PAN', 'Taxable', 'VAT', 'Exempt', 'Total', 'Cancelled'];
const purchaseBookHeader = ['Date', 'Bill no', 'Seller', 'Seller PAN', 'Taxable', 'VAT', 'Total'];

List<List<Object?>> salesBookRows(List<Sale> sales) => [
      for (final s in sales)
        [
          adOfStamp(s.soldAt),
          s.billNo ?? '',
          s.customer?.name ?? 'Walk-in customer',
          s.customer?.pan ?? '',
          plainAmount(s.taxableAmount, grouped: false),
          plainAmount(s.vatAmount, grouped: false),
          plainAmount(s.exemptAmount, grouped: false),
          plainAmount(s.total, grouped: false),
          s.cancelledAt == null ? 'No' : 'Yes',
        ],
    ];

List<List<Object?>> purchaseBookRows(List<Purchase> purchases) => [
      for (final p in purchases)
        [
          p.billDate ?? adOfStamp(p.boughtAt),
          p.billNo ?? '',
          p.supplier?.name ?? '',
          p.supplier?.pan ?? '',
          plainAmount(p.total - p.vatAmount, grouped: false),
          plainAmount(p.vatAmount, grouped: false),
          plainAmount(p.total, grouped: false),
        ],
    ];
