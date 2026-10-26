import 'package:pasal_mobile/core/l10n/tr.dart';

/// Money helpers. The API sends and expects whole paisa (integers). Rs 113.00 is 11300.
/// Never do money maths with doubles.

/// Indian grouping: 1234567 becomes 12,34,567.
String groupIndian(int whole) {
  final negative = whole < 0;
  final digits = whole.abs().toString();
  if (digits.length <= 3) return negative ? '-$digits' : digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  final text = '${parts.join(',')},$last3';
  return negative ? '-$text' : text;
}

/// "Rs 1,24,000". Paisa show only when there are some, or when [paisa] is true (VAT screens).
/// Negative amounts keep the minus sign: "-Rs 500". Nepali digits when the language is Nepali.
String rs(int? paisaAmount, {bool paisa = false}) {
  final value = paisaAmount ?? 0;
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  final whole = abs ~/ 100;
  final cents = abs % 100;
  var text = groupIndian(whole);
  if (paisa || cents != 0) text += '.${cents.toString().padLeft(2, '0')}';
  return digits('${sign}Rs $text');
}

/// A plain number with Indian grouping.
String num0(int value) => digits(groupIndian(value));

/// Text typed by a person ("1,250.50") to whole paisa. Null when it is not a money amount.
int? toPaisa(String? input) {
  if (input == null) return null;
  final text = input.replaceAll(RegExp(r'[,\s]'), '').replaceFirst(RegExp(r'^Rs\.?', caseSensitive: false), '');
  if (text.isEmpty || text == '.' || !RegExp(r'^\d*\.?\d{0,2}$').hasMatch(text)) return null;
  final parts = text.split('.');
  final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]);
  if (whole == null) return null;
  final frac = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
  return whole * 100 + int.parse(frac);
}

/// Paisa back to the text a person types into an amount box ("1250.5", no grouping).
String fromPaisa(int paisaAmount) {
  final sign = paisaAmount < 0 ? '-' : '';
  final abs = paisaAmount.abs();
  final whole = abs ~/ 100;
  final cents = abs % 100;
  if (cents == 0) return '$sign$whole';
  final frac = cents.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '');
  return '$sign$whole.$frac';
}

/// Percent of an amount, rounded to whole paisa (halves round away from zero).
int percentOf(int paisaAmount, num percent) => (paisaAmount * percent / 100).round();
