import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/settings/data/csv.dart';

void main() {
  group('csvCell', () {
    test('writes plain text and numbers as they are', () {
      expect(csvCell('Basmati rice'), 'Basmati rice');
      expect(csvCell(12), '12');
      expect(csvCell(null), '');
    });

    test('puts a cell with a comma, a quote or a line break in quotes', () {
      expect(csvCell('Rice, 5kg'), '"Rice, 5kg"');
      expect(csvCell('Say "hi"'), '"Say ""hi"""');
      expect(csvCell('line 1\nline 2'), '"line 1\nline 2"');
    });

    test('adds a quote in front of a cell that could run as a formula', () {
      expect(csvCell('=SUM(A1)'), "'=SUM(A1)");
      expect(csvCell('+977'), "'+977");
      expect(csvCell('-5'), "'-5");
      expect(csvCell('@admin'), "'@admin");
    });

    test('quotes a formula-like cell that also has a comma, after the prefix', () {
      expect(csvCell('=1,2'), '"\'=1,2"');
    });

    test('does not change a minus sign in the middle of a value', () {
      expect(csvCell('Rice 5-kg'), 'Rice 5-kg');
    });
  });

  test('csvTable joins the header and the rows', () {
    expect(
      csvTable(['Name', 'Price'], [
        ['Rice', 1250.5],
        ['Sugar, white', null],
      ]),
      'Name,Price\nRice,1250.5\n"Sugar, white",',
    );
  });

  test('csvBytes starts with the byte order mark and decodes back to the text', () {
    final bytes = csvBytes('नाम,रकम');
    expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
    expect(utf8.decode(bytes.sublist(3)), 'नाम,रकम');
  });
}
