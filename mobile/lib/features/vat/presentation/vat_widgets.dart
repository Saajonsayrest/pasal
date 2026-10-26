import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/core/widgets/bs_date.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/vat/data/vat_helpers.dart';

/// Paisa as "1,24,000.50" for the book tables, with Nepali digits in Nepali mode.
String plainText(int paisa) => digits(plainAmount(paisa));

/// Label on the left, number on the right. The total line is bold, with a thin line above it.
class VatKvLine {
  const VatKvLine(this.label, this.value, {this.total = false});

  final String label;
  final String value;
  final bool total;
}

class VatKv extends StatelessWidget {
  const VatKv({required this.lines, super.key});

  final List<VatKvLine> lines;

  @override
  Widget build(BuildContext context) {
    final muted = context.scheme.onSurfaceVariant;
    return Column(
      children: [
        for (final line in lines)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: line.total ? Border(top: BorderSide(color: context.scheme.outlineVariant)) : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    line.label,
                    style: context.text.bodyMedium?.copyWith(color: muted, fontWeight: line.total ? FontWeight.w800 : FontWeight.w500),
                  ),
                ),
                Flexible(
                  child: Text(
                    line.value,
                    textAlign: TextAlign.end,
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small grey text under a block of numbers.
class VatNote extends StatelessWidget {
  const VatNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant));
  }
}

/// A box that shows a value the user cannot change (the period label, the month range).
class ReadOnlyValue extends StatelessWidget {
  const ReadOnlyValue({required this.label, required this.value, super.key, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: context.scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Text(value, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(hint!, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
          ),
      ],
    );
  }
}

/// A date that may be empty. Shows "Not set" until a date is picked. The clear button empties it again.
class OptionalBsDate extends StatelessWidget {
  const OptionalBsDate({required this.label, required this.value, required this.onChanged, super.key});

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () async {
            final picked = await showBsDatePicker(context, initial: current);
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            decoration: BoxDecoration(
              color: context.scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: context.scheme.outlineVariant.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: current == null
                      ? Text(context.tr('Not set', 'सेट गरिएको छैन'), style: context.text.titleSmall?.copyWith(color: context.scheme.onSurfaceVariant))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatDate(current), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            Text(formatDateSub(current), style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant)),
                          ],
                        ),
                ),
                if (current != null)
                  IconButton(
                    tooltip: context.tr('Clear date', 'मिति हटाउने'),
                    onPressed: () => onChanged(null),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Two fields side by side. A single last field keeps the left half.
Widget twoUp(List<Widget> items) {
  final rows = <Widget>[];
  for (var i = 0; i < items.length; i += 2) {
    final pair = items.skip(i).take(2).toList();
    rows.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < pair.length; j++) ...[
              if (j > 0) const SizedBox(width: 12),
              Expanded(child: pair[j]),
            ],
            if (pair.length == 1) ...[
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
            ],
          ],
        ),
      ),
    );
  }
  return Column(children: rows);
}

/// Colour, icon and words for a filing's state. The words always show with the colour.
({Tone tone, IconData icon, String label}) statusStyle(BuildContext context, FilingStatus status) => switch (status) {
      FilingStatus.notFiled => (tone: Tone.warn, icon: Icons.pending_actions_rounded, label: context.tr('Not filed', 'फाइल भएको छैन')),
      FilingStatus.filed => (tone: Tone.info, icon: Icons.task_alt_rounded, label: context.tr('Filed', 'फाइल भएको')),
      FilingStatus.paid => (tone: Tone.good, icon: Icons.check_circle_rounded, label: context.tr('Paid', 'फाइल र भुक्तानी भयो')),
    };

/// "due in 16 days" or "3 days past due".
String dueSentence(BuildContext context, int days) => days < 0
    ? context.tr('${context.num(-days)} days past due', '${context.num(-days)} दिन नाघेको')
    : context.tr('due in ${context.num(days)} days', '${context.num(days)} दिनमा तिर्नुपर्ने');

/// "16 days left" or "3 days past due".
String daysLeftSentence(BuildContext context, int days) => days < 0
    ? context.tr('${context.num(-days)} days past due', '${context.num(-days)} दिन नाघेको')
    : context.tr('${context.num(days)} days left', '${context.num(days)} दिन बाँकी');

/// The message under a field for an amount that is not a number.
String? amountError(BuildContext context, String text) =>
    toPaisa(text) == null ? context.tr('Enter an amount, for example 1250.50', 'रकम लेख्नुहोस्, जस्तै 1250.50') : null;
