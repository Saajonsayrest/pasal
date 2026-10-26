import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/utils/bs.dart';

enum EntryKind { given, received, refund }

/// One line of a customer's money history: a bill given on credit, or money in or back out.
class LedgerEntry {
  const LedgerEntry({
    required this.key,
    required this.kind,
    required this.at,
    required this.day,
    required this.amount,
    required this.delta,
    required this.saleId,
    required this.billNo,
    required this.returned,
    required this.method,
    required this.cancelled,
  });

  final String key;
  final EntryKind kind;

  /// Full time stamp from the API.
  final String at;

  /// Nepal calendar day (AD, YYYY-MM-DD) of [at].
  final String day;

  /// Paisa on the line: the bill total for a bill, the money for a payment.
  final int amount;

  /// Change to what the customer owes, in paisa. Plus means more owed, minus means money in.
  final int delta;
  final int? saleId;
  final String? billNo;

  /// Paisa returned on a bill.
  final int returned;

  /// Payment method key (`cash`, `qr`, `bank`, `esewa`, `khalti`). Empty for bills.
  final String method;
  final bool cancelled;

  /// The amount a statement shows for this line. A bill counts after returns.
  int get netAmount => kind == EntryKind.given ? delta : amount;
}

/// Bills and payments of one customer. Supplier payments are left out.
List<LedgerEntry> customerEntries(CustomerLedger ledger) {
  final billOf = {for (final s in ledger.sales) s.id: s.billNo};
  final entries = <LedgerEntry>[
    for (final s in ledger.sales)
      LedgerEntry(
        key: 'sale-${s.id}',
        kind: EntryKind.given,
        at: s.soldAt,
        day: adOfStamp(s.soldAt),
        amount: s.total,
        delta: s.total - s.returnedTotal,
        saleId: s.id,
        billNo: s.billNo,
        returned: s.returnedTotal,
        method: '',
        cancelled: s.cancelledAt != null,
      ),
  ];
  for (final p in ledger.payments) {
    if (p.direction == 'out') continue;
    final isRefund = p.direction == 'refund';
    entries.add(
      LedgerEntry(
        key: 'pay-${p.id}',
        kind: isRefund ? EntryKind.refund : EntryKind.received,
        at: p.paidAt,
        day: adOfStamp(p.paidAt),
        amount: p.amount,
        delta: isRefund ? p.amount : -p.amount,
        saleId: p.saleId,
        billNo: p.saleId == null ? null : billOf[p.saleId],
        returned: 0,
        method: p.method,
        cancelled: false,
      ),
    );
  }
  return entries;
}

/// The first day with any record, or today when there is none.
String earliestDay(CustomerLedger ledger) {
  final days = customerEntries(ledger).map((e) => e.day);
  if (days.isEmpty) return todayAd();
  return days.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
}
