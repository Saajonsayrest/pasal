import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/features/customers/data/ledger_entries.dart';

/// The API keeps the newest 200 bills and the newest 200 payments.
const ledgerRecordLimit = 200;

class StatementRow {
  const StatementRow(this.entry, this.balance);

  final LedgerEntry entry;

  /// Paisa owed after this line.
  final int balance;
}

class Statement {
  const Statement({
    required this.opening,
    required this.rows,
    required this.totalGiven,
    required this.totalReceived,
    required this.closing,
    required this.truncated,
  });

  /// Paisa owed before [from].
  final int opening;
  final List<StatementRow> rows;
  final int totalGiven;
  final int totalReceived;
  final int closing;

  /// True when the server may have cut older records, so the opening balance can be wrong.
  final bool truncated;
}

/// The statement for AD days [from] to [to], both included, with a running balance.
Statement buildStatement(CustomerLedger ledger, {required String from, required String to}) {
  final entries = customerEntries(ledger)..sort((a, b) => DateTime.parse(a.at).compareTo(DateTime.parse(b.at)));

  final opening = entries.where((e) => e.day.compareTo(from) < 0).fold<int>(0, (sum, e) => sum + e.delta);
  var balance = opening;
  final rows = <StatementRow>[];
  for (final e in entries) {
    if (e.day.compareTo(from) < 0 || e.day.compareTo(to) > 0) continue;
    balance += e.delta;
    rows.add(StatementRow(e, balance));
  }

  return Statement(
    opening: opening,
    rows: rows,
    totalGiven: rows.where((r) => r.entry.kind != EntryKind.received).fold<int>(0, (sum, r) => sum + r.entry.netAmount),
    totalReceived: rows.where((r) => r.entry.kind == EntryKind.received).fold<int>(0, (sum, r) => sum + r.entry.amount),
    closing: rows.isEmpty ? opening : rows.last.balance,
    truncated: ledger.sales.length >= ledgerRecordLimit || ledger.payments.length >= ledgerRecordLimit,
  );
}
