import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/money.dart';

/// Pure rules for purchases and supplier payments. Kept apart from widgets so they can be unit tested.

/// Money typed in an optional box. Empty means 0. Null when the text is not an amount.
int? optionalPaisa(String text) => text.trim().isEmpty ? 0 : toPaisa(text);

/// Whole digits only, or null.
int? wholeNumber(String text) {
  final t = text.trim();
  return RegExp(r'^\d+$').hasMatch(t) ? int.tryParse(t) : null;
}

/// A quantity from 1 to 1,000,000 (the API range), or null.
int? parseQuantity(String text) {
  final n = wholeNumber(text);
  return n != null && n >= 1 && n <= 1000000 ? n : null;
}

/// A unit cost in paisa from 0 to 10,000,000,000 (the API range), or null.
int? parseUnitCost(String text) {
  final paisa = toPaisa(text);
  return paisa != null && paisa <= 10000000000 ? paisa : null;
}

/// Quantity times unit cost, or null when either is missing.
int? lineTotalPaisa(int? quantity, int? unitCost) => quantity == null || unitCost == null ? null : quantity * unitCost;

/// The first element that matches, or null.
T? findFirst<T>(Iterable<T> items, bool Function(T item) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

/// Whole days since an ISO time stamp (Nepal calendar day). Never negative.
int daysAgo(String stamp) {
  final days = -daysUntil(adOfStamp(stamp));
  return days < 0 ? 0 : days;
}

/// Bills we still owe on, the oldest first.
List<LedgerPurchase> openBillsOldestFirst(List<LedgerPurchase> bills) {
  final open = bills.where((b) => b.balance > 0).toList()..sort((a, b) => DateTime.parse(a.boughtAt).compareTo(DateTime.parse(b.boughtAt)));
  return open;
}

/// How much of a payment goes to one bill.
class PaymentStep {
  const PaymentStep(this.bill, this.take);

  final LedgerPurchase bill;
  final int take;
}

/// The money pays the oldest open bills first. Returns the part each bill takes, in that order.
List<PaymentStep> planOldestFirst(List<LedgerPurchase> bills, int amount) {
  final steps = <PaymentStep>[];
  var left = amount;
  for (final bill in openBillsOldestFirst(bills)) {
    if (left <= 0) break;
    final take = left < bill.balance ? left : bill.balance;
    steps.add(PaymentStep(bill, take));
    left -= take;
  }
  return steps;
}
