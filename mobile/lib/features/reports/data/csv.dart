import 'dart:convert';
import 'dart:typed_data';

/// One CSV file to share: its file name and its text.
class CsvFile {
  const CsvFile({required this.name, required this.text});

  final String name;
  final String text;
}

/// Text for one cell. Port of web/src/lib/util.ts `csvCell`.
String csvCell(Object? value) {
  final s = value?.toString() ?? '';
  // A cell that starts with = + - @ or a tab can run as a formula in a spreadsheet. A quote in front stops that.
  final safe = RegExp(r'^[=+\-@\t\r]').hasMatch(s) ? "'$s" : s;
  return RegExp(r'[",\n\r]').hasMatch(safe) ? '"${safe.replaceAll('"', '""')}"' : safe;
}

/// The whole file text: the header line, then one line per row, with Windows line ends (as the web).
String csvText(List<String> head, List<List<Object?>> rows) => <List<Object?>>[head, ...rows].map((r) => r.map(csvCell).join(',')).join('\r\n');

/// The file bytes: a byte order mark, then UTF-8. The mark lets Excel read Nepali text.
Uint8List csvBytes(String text) => Uint8List.fromList(utf8.encode('﻿$text'));
