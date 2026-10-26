import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/bs_date.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/features/reports/data/range.dart';

/// Preset chips for the date range, and two date boxes for a custom range.
/// The preset starts on this Nepali month, like the web.
class RangePicker extends StatefulWidget {
  const RangePicker({required this.value, required this.onChanged, super.key});

  final DateRange value;
  final ValueChanged<DateRange> onChanged;

  @override
  State<RangePicker> createState() => _RangePickerState();
}

class _RangePickerState extends State<RangePicker> {
  RangePreset _preset = RangePreset.month;

  void _choose(RangePreset preset) {
    setState(() => _preset = preset);
    if (preset != RangePreset.custom) widget.onChanged(rangeFor(preset));
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChipsRow<RangePreset>(
          value: _preset,
          onChanged: _choose,
          options: {
            RangePreset.today: context.tr('Today', 'आज'),
            RangePreset.week: context.tr('Last 7 days', 'पछिल्ला ७ दिन'),
            RangePreset.month: context.tr('This month', 'यो महिना'),
            RangePreset.lastMonth: context.tr('Last month', 'गत महिना'),
            RangePreset.quarter: context.tr('Last 3 months', 'पछिल्ला ३ महिना'),
            RangePreset.custom: context.tr('Custom', 'आफैँ छान्ने'),
          },
        ),
        if (_preset == RangePreset.custom) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BsDateField(
                  label: context.tr('From', 'देखि'),
                  value: range.from,
                  max: range.to,
                  onChanged: (v) => widget.onChanged((from: v, to: range.to)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BsDateField(
                  label: context.tr('To', 'सम्म'),
                  value: range.to,
                  min: range.from,
                  onChanged: (v) => widget.onChanged((from: range.from, to: v)),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          context.tr('${formatDate(range.from)} to ${formatDate(range.to)}', '${formatDate(range.from)} देखि ${formatDate(range.to)} सम्म'),
          style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
