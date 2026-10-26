import 'dart:convert';
import 'dart:typed_data';

/// One CSV cell that Excel and Google Sheets read safely (ported from `csvCell` in web/src/lib/util.ts).
///
/// A value that starts with `=`, `+`, `-`, `@`, a tab or a line break gets a quote in front, so it
/// cannot run as a formula. Commas, quotes and line breaks put the cell in double quotes.
String csvCell(Object? value) {
  final text = value?.toString() ?? '';
  final safe = RegExp(r'^[=+\-@\t\r]').hasMatch(text) ? "'$text" : text;
  if (RegExp(r'[",\n\r]').hasMatch(safe)) {
    return '"${safe.replaceAll('"', '""')}"';
  }
  return safe;
}

/// A header line and the rows, joined with new lines.
String csvTable(List<String> header, List<List<Object?>> rows) =>
    [header, ...rows].map((row) => row.map(csvCell).join(',')).join('\n');

/// The file bytes: UTF-8 with a byte order mark, so Excel shows Nepali text correctly.
Uint8List csvBytes(String text) => Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);
