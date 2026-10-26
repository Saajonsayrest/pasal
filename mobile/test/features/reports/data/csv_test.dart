import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/reports/data/csv.dart';

void main() {
  group('csvCell', () {
    test('plain text is left as it is', () {
      expect(csvCell('Rice 5kg'), 'Rice 5kg');
    });

    test('empty and missing values are empty cells', () {
      expect(csvCell(null), '');
      expect(csvCell(''), '');
    });

    test('numbers are written as they are', () {
      expect(csvCell(12), '12');
      expect(csvCell(0), '0');
    });

    test('a cell that starts with a formula character gets a quote in front', () {
      expect(csvCell('=1+1'), "'=1+1");
      expect(csvCell('+91'), "'+91");
      expect(csvCell('-500'), "'-500");
      expect(csvCell('@sum'), "'@sum");
      expect(csvCell('\tx'), "'\tx");
    });

    test('a cell with a comma, quote or line break is wrapped in quotes', () {
      expect(csvCell('Kartik 1, 2083'), '"Kartik 1, 2083"');
      expect(csvCell('say "hi"'), '"say ""hi"""');
      expect(csvCell('a\nb'), '"a\nb"');
    });

    test('a formula cell that also needs quotes gets both', () {
      expect(csvCell('=A1,B1'), '"\'=A1,B1"');
    });
  });

  test('csvText puts the header first and uses Windows line ends', () {
    final text = csvText(['Name', 'Owes'], [
      ['Hari, Thapa', '63'],
      [null, 0],
    ]);
    expect(text, 'Name,Owes\r\n"Hari, Thapa",63\r\n,0');
  });

  test('csvBytes starts with a byte order mark and then UTF-8', () {
    final bytes = csvBytes('नाम');
    expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
    expect(bytes.length, 3 + 'नाम'.length * 3);
  });
}
