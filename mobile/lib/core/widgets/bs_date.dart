import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';

/// Previous and next Nepali (BS) month.
///
///     MonthNav(year: y, month: m, onChanged: (y, m) => setState(...))
class MonthNav extends StatelessWidget {
  const MonthNav({required this.year, required this.month, required this.onChanged, super.key});

  final int year;
  final int month;
  final void Function(int year, int month) onChanged;

  void _go(int by) {
    final next = shiftMonth(year, month, by);
    if (next.year < bsMinYear || next.year > bsMaxYear) return;
    onChanged(next.year, next.month);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(tooltip: context.tr('Previous month', 'अघिल्लो महिना'), onPressed: () => _go(-1), icon: const Icon(Icons.chevron_left_rounded)),
        Text(monthTitle(year, month), style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        IconButton(tooltip: context.tr('Next month', 'अर्को महिना'), onPressed: () => _go(1), icon: const Icon(Icons.chevron_right_rounded)),
      ],
    );
  }
}

/// A date box that shows the Nepali (BS) date and opens a BS calendar. [value] is the AD date
/// "YYYY-MM-DD" (what the API wants).
///
///     BsDateField(label: 'Bill date', value: date, onChanged: (v) => setState(() => date = v))
class BsDateField extends StatelessWidget {
  const BsDateField({required this.label, required this.value, required this.onChanged, super.key, this.min, this.max});

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? min;
  final String? max;

  @override
  Widget build(BuildContext context) {
    context.isNe;
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
            final picked = await showBsDatePicker(context, initial: value, min: min, max: max);
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatDate(value), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(formatDateSub(value), style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens the BS calendar in a bottom sheet. Returns the chosen AD date, or null.
Future<String?> showBsDatePicker(BuildContext context, {String? initial, String? min, String? max}) {
  return showPasalSheet<String>(
    context,
    title: context.tr('Pick a date', 'मिति छान्नुहोस्'),
    builder: (ctx) => _BsCalendar(initial: initial ?? todayAd(), min: min, max: max),
  );
}

class _BsCalendar extends StatefulWidget {
  const _BsCalendar({required this.initial, this.min, this.max});

  final String initial;
  final String? min;
  final String? max;

  @override
  State<_BsCalendar> createState() => _BsCalendarState();
}

class _BsCalendarState extends State<_BsCalendar> {
  late int year;
  late int month;

  @override
  void initState() {
    super.initState();
    final b = adToBs(widget.initial);
    year = b.year;
    month = b.month;
  }

  bool _disabled(String ad) => (widget.min != null && ad.compareTo(widget.min!) < 0) || (widget.max != null && ad.compareTo(widget.max!) > 0);

  @override
  Widget build(BuildContext context) {
    final days = daysInBsMonth(year, month);
    final firstAd = bsToAd(year, month, 1);
    final lead = DateTime.parse(firstAd).weekday % 7; // Sunday first
    final today = todayAd();
    // Weekday names from a known Sunday (25 Oct 2026).
    final heads = [for (var i = 0; i < 7; i++) weekday(addDaysAd('2026-10-25', i)).substring(0, Lang.ne ? 3 : 2)];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MonthNav(year: year, month: month, onChanged: (y, m) => setState(() {
              year = y;
              month = m;
            })),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.05,
          children: [
            for (final h in heads) Center(child: Text(h, style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var d = 1; d <= days; d++) _day(context, d, today),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.of(context).pop(today), child: Text(context.tr('Today', 'आज'))),
      ],
    );
  }

  Widget _day(BuildContext context, int d, String today) {
    final ad = bsToAd(year, month, d);
    final selected = ad == widget.initial;
    final disabled = _disabled(ad);
    final adDay = int.parse(ad.substring(8));
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected ? context.scheme.primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: ad == today && !selected ? BorderSide(color: context.scheme.primary) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled ? null : () => Navigator.of(context).pop(ad),
          child: Opacity(
            opacity: disabled ? 0.3 : 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  digits(d),
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: selected ? context.scheme.onPrimary : context.scheme.onSurface),
                ),
                Positioned(
                  right: 5,
                  bottom: 2,
                  child: Text(digits(adDay), style: TextStyle(fontSize: 8, color: (selected ? context.scheme.onPrimary : context.scheme.onSurfaceVariant).withValues(alpha: 0.7))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
