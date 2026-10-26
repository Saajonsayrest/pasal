import 'package:flutter/widgets.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/features/customers/data/ledger_entries.dart';
import 'package:pasal_mobile/features/customers/data/payment_methods.dart';

String _spaced(Iterable<String> parts) => parts.where((p) => p.isNotEmpty).join(' ');

/// Headline of one ledger line: "Given on credit", "Received · Cash", "Refunded".
String entryTitle(BuildContext context, LedgerEntry e) {
  final method = paymentMethodName(e.method, ne: context.isNe);
  return switch (e.kind) {
    EntryKind.given => context.tr('Given on credit', 'उधारो दिइयो'),
    EntryKind.refund => context.tr('Refunded', 'फिर्ता दिइयो'),
    EntryKind.received => context.tr('Received · $method', 'पाइयो · $method'),
  };
}

/// The line of a statement: "Sale S-0412", "Paid eSewa for S-0301", "Cancelled sale S-0400".
String entryDetail(BuildContext context, LedgerEntry e) {
  final bill = e.billNo ?? '';
  final method = paymentMethodName(e.method, ne: context.isNe);
  return switch (e.kind) {
    EntryKind.given when e.cancelled => context.tr(_spaced(['Cancelled sale', bill]), _spaced([bill, 'रद्द'])),
    EntryKind.given => context.tr(_spaced(['Sale', bill]), _spaced(['बिक्री', bill])),
    EntryKind.refund => context.tr(_spaced(['Refunded', bill]), _spaced([bill, 'फिर्ता'])),
    EntryKind.received => context.tr(
        bill.isEmpty ? 'Paid $method' : 'Paid $method for $bill',
        '$method बाट ${bill.isEmpty ? '' : '$bill को '}भुक्तानी',
      ),
  };
}

/// "Today · Kartik 9, 2083" or "Kartik 4, 2083" for a day group.
String dayLabel(BuildContext context, String day) {
  final text = formatDate(day);
  return day == todayAd() ? '${context.tr('Today', 'आज')} · $text' : text;
}
