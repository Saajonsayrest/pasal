import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';

/// Small pieces shared by the supplier and purchase screens.

const paymentMethods = ['cash', 'bank', 'cheque'];

/// "cash", "bank" or "cheque" in the words of the app.
String methodLabel(BuildContext context, String method) {
  return switch (method) {
    'cash' => context.tr('cash', 'नगद'),
    'bank' => context.tr('bank', 'बैंक'),
    'cheque' => context.tr('cheque', 'चेक'),
    _ => method.isEmpty ? context.tr('not set', 'छैन') : method,
  };
}

/// 1st, 2nd, 3rd ... in English. पहिलो, दोस्रो ... in Nepali.
String ordinalLabel(BuildContext context, int n) {
  const neOrdinals = ['पहिलो', 'दोस्रो', 'तेस्रो', 'चौथो', 'पाँचौं', 'छैटौं', 'सातौं', 'आठौं', 'नवौं', 'दसौं'];
  final tens = n % 100;
  final suffix = tens >= 11 && tens <= 13 ? 'th' : (const {1: 'st', 2: 'nd', 3: 'rd'}[n % 10] ?? 'th');
  return context.tr('$n$suffix', n <= neOrdinals.length ? neOrdinals[n - 1] : context.num(n));
}

/// "3 days ago" for a bill date stamp.
String daysAgoText(BuildContext context, int days) {
  return context.tr('$days days ago', '${context.num(days)} दिन अघि');
}

/// A small heading above a block, with an optional button on the right. A long title wraps instead of overflowing.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// A label on the left and a value on the right, for totals.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({required this.label, required this.value, super.key, this.valueColor, this.strong = false});

  final String label;
  final String value;
  final Color? valueColor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final labelStyle = context.text.bodyMedium?.copyWith(
      color: strong ? context.scheme.onSurface : context.scheme.onSurfaceVariant,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
    );
    final valueStyle = context.text.bodyMedium?.copyWith(
      color: valueColor ?? context.scheme.onSurface,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

/// A round button with an icon and a label under it, for the row of quick actions.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({required this.icon, required this.label, required this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? context.scheme.onSurface : context.scheme.onSurface.withValues(alpha: 0.38);
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: context.scheme.primaryContainer.withValues(alpha: enabled ? 1 : 0.4), shape: BoxShape.circle),
              child: Icon(icon, color: context.scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: context.text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Cash, bank or cheque, one at a time.
class PaymentMethodPicker extends StatelessWidget {
  const PaymentMethodPicker({required this.value, required this.onChanged, super.key});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Seg<String>(
      value: value,
      onChanged: onChanged,
      options: {for (final m in paymentMethods) m: methodLabel(context, m)},
      icons: const {'cash': Icons.payments_rounded, 'bank': Icons.account_balance_rounded, 'cheque': Icons.receipt_rounded},
    );
  }
}

/// The date text of a bill, in the Nepali calendar first.
String billDateText(String? billDate, String boughtAt) => formatDate(billDate ?? boughtAt);
