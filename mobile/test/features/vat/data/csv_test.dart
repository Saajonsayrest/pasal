import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/features/vat/data/csv.dart';

import '../vat_fixtures.dart';

void main() {
  group('csvCell', () {
    test('leaves plain text alone', () {
      expect(csvCell('Hari Thapa'), 'Hari Thapa');
      expect(csvCell('मा'), 'मा');
    });

    test('quotes cells with commas, quotes or line breaks', () {
      expect(csvCell('Thapa, Hari'), '"Thapa, Hari"');
      expect(csvCell('say "hi"'), '"say ""hi"""');
      expect(csvCell('line one\nline two'), '"line one\nline two"');
      expect(csvCell('carriage\rreturn'), '"carriage\rreturn"');
    });

    test('puts a quote in front of a formula that a spreadsheet could run', () {
      expect(csvCell('=HYPERLINK("http://x")'), '"\'=HYPERLINK(""http://x"")"');
      expect(csvCell('+5'), "'+5");
      expect(csvCell('-10.00'), "'-10.00");
      expect(csvCell('@SUM(A1)'), "'@SUM(A1)");
      expect(csvCell('\tcell'), "'\tcell");
    });

    test('guards a name that starts with a formula sign, the same as a number', () {
      expect(csvCell('-Hari'), "'-Hari");
    });

    test('turns null into an empty cell and numbers into text', () {
      expect(csvCell(null), '');
      expect(csvCell(42), '42');
    });
  });

  test('csvText joins cells with commas and rows with CRLF', () {
    expect(csvText(['A', 'B'], [[1, 'x,y'], [null, 'z']]), 'A,B\r\n1,"x,y"\r\n,z');
  });

  test('csvBytes starts with a UTF-8 byte order mark', () {
    final bytes = csvBytes('a');
    expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
    expect(bytes.skip(3).toList(), [0x61]);
  });

  test('bookFileName names the file by book and month', () {
    expect(bookFileName(sales: true, period: '2083-07'), 'sales-book-2083-07.csv');
    expect(bookFileName(sales: false, period: '2083-07'), 'purchase-book-2083-07.csv');
  });

  test('salesBookRows writes walk-in sales and cancelled flags', () {
    final sales = [
      Sale.fromJson(saleJson(id: 1, billNo: 'S-0031', total: 11300, taxable: 10000, vat: 1300)),
      Sale.fromJson(
        saleJson(
          id: 2,
          billNo: 'S-0032',
          total: 2260,
          taxable: 2000,
          vat: 260,
          customer: {'id': 4, 'name': 'Hari, Thapa', 'phone': null, 'address': null, 'pan': '600000001'},
          cancelledAt: '2026-10-27T01:00:00+00:00',
        ),
      ),
    ];
    final text = csvText(salesBookHeader, salesBookRows(sales));
    final lines = text.split('\r\n');
    expect(lines.first, 'Date,Bill no,Buyer,Buyer PAN,Taxable,VAT,Exempt,Total,Cancelled');
    expect(lines[1], endsWith(',S-0031,Walk-in customer,,100.00,13.00,0.00,113.00,No'));
    expect(lines[2], endsWith(',S-0032,"Hari, Thapa",600000001,20.00,2.60,0.00,22.60,Yes'));
  });

  test('purchaseBookRows writes the bill date and the VAT split', () {
    final purchases = [
      Purchase.fromJson(
        purchaseJson(id: 1, billNo: 'INV-889', total: 1130000, vat: 130000, supplier: {'id': 3, 'name': 'Himal Traders', 'pan': '123456789'}),
      ),
    ];
    final rows = purchaseBookRows(purchases);
    expect(rows.single, ['2026-10-24', 'INV-889', 'Himal Traders', '123456789', '10000.00', '1300.00', '11300.00']);
  });
}
