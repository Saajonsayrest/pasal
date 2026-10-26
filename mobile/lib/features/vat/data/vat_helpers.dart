import 'dart:math' show max;

import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/money.dart';

/// Days after the last day of a VAT period when the return is due (VAT Act 2052, section 18).
const vatDueDays = 25;

final _periodLabel = RegExp(r'^(\d{4})-(\d{2})$');

/// "2083-07" to (year: 2083, month: 7). Null for any other label, for example a typed name.
({int year, int month})? parsePeriod(String label) {
  final m = _periodLabel.firstMatch(label);
  if (m == null) return null;
  final month = int.parse(m[2]!);
  if (month < 1 || month > 12) return null;
  return (year: int.parse(m[1]!), month: month);
}

/// "2083-07" to "Kartik 2083". Labels that are not year-month are shown as they are.
String periodTitle(String label) {
  final p = parsePeriod(label);
  return p == null ? label : monthTitle(p.year, p.month);
}

/// The day the return for a period is due: the last day of the period plus [vatDueDays].
String dueDate(String periodTo) => addDaysAd(periodTo, vatDueDays);

/// Whole days from today to the due date of a period. Negative when it has passed.
int dueInDays(String periodTo, [DateTime? now]) => daysUntil(dueDate(periodTo), now);

/// Paisa still to pay on a filing. Never below zero.
int remainingToPay(VatFiling f) => max(0, f.payable - f.paidAmount);

enum FilingStatus { notFiled, filed, paid }

bool isFiled(VatFiling f) => f.filedOn != null && f.filedOn!.isNotEmpty;

FilingStatus filingStatus(VatFiling f) {
  if (!isFiled(f)) return FilingStatus.notFiled;
  if (f.payable > 0 && f.paidAmount >= f.payable) return FilingStatus.paid;
  return FilingStatus.filed;
}

/// Paisa still to pay over a list of filings.
int stillToPay(Iterable<VatFiling> rows) => rows.fold(0, (sum, f) => sum + remainingToPay(f));

/// The oldest filing that still owes money. The rows come newest first, so it is the last unpaid row.
VatFiling? oldestUnpaid(List<VatFiling> rows) {
  final unpaid = rows.where((f) => remainingToPay(f) > 0).toList();
  return unpaid.isEmpty ? null : unpaid.last;
}

VatFiling? filingForPeriod(Iterable<VatFiling> rows, String period) {
  for (final f in rows) {
    if (f.period == period) return f;
  }
  return null;
}

/// The first message to show for a failed save. Field names in [shown] are skipped because the
/// screen shows them next to their field. Null when every message is shown elsewhere.
String? errorText(ApiException? e, {List<String> shown = const []}) {
  if (e == null) return null;
  if (e.errors.isEmpty) return e.message;
  for (final entry in e.errors.entries) {
    if (shown.contains(entry.key) || entry.value.isEmpty) continue;
    return entry.value.first;
  }
  return null;
}

/// Whole paisa as "12,40,000.50" with no Rs sign. Pass grouped false for CSV files.
String plainAmount(int paisa, {bool grouped = true}) {
  final sign = paisa < 0 ? '-' : '';
  final abs = paisa.abs();
  final whole = abs ~/ 100;
  final cents = (abs % 100).toString().padLeft(2, '0');
  return '$sign${grouped ? groupIndian(whole) : whole}.$cents';
}

/// Trimmed text, or null when nothing is left.
String? blankToNull(String text) {
  final t = text.trim();
  return t.isEmpty ? null : t;
}

/// The Idempotency-Key of one save button. It stays the same while the inputs stay the same, so a
/// retry of the same tap is safe. Changed inputs get a new key, because the server refuses a key that
/// comes back with a different body.
class RequestKey {
  String _key = newKey();
  String? _last;

  String forInputs(Object inputs) {
    final signature = inputs.toString();
    if (signature != _last) {
      _last = signature;
      _key = newKey();
    }
    return _key;
  }

  /// Call after a save that worked, so the next save gets a new key.
  void reset() {
    _last = null;
    _key = newKey();
  }
}

/// Totals of the rows shown in the sales book.
({int taxable, int vat, int exempt, int total}) salesTotals(Iterable<Sale> rows) {
  var taxable = 0;
  var vat = 0;
  var exempt = 0;
  var total = 0;
  for (final s in rows) {
    taxable += s.taxableAmount;
    vat += s.vatAmount;
    exempt += s.exemptAmount;
    total += s.total;
  }
  return (taxable: taxable, vat: vat, exempt: exempt, total: total);
}

/// Totals of the rows shown in the purchase book. The taxable part is the bill total without VAT.
({int taxable, int vat, int total}) purchaseTotals(Iterable<Purchase> rows) {
  var taxable = 0;
  var vat = 0;
  var total = 0;
  for (final p in rows) {
    taxable += p.total - p.vatAmount;
    vat += p.vatAmount;
    total += p.total;
  }
  return (taxable: taxable, vat: vat, total: total);
}
