import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';

/// A label on the left and a value on the right. The total line is bold.
class KvRow extends StatelessWidget {
  const KvRow(this.label, this.value, {super.key, this.total = false});

  final String label;
  final String value;
  final bool total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant))),
          Text(value, style: context.text.bodyMedium?.copyWith(fontWeight: total ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Small bold title of a card, with an optional widget on the right.
class CardTitle extends StatelessWidget {
  const CardTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          ?trailing,
        ],
      ),
    );
  }
}

class BarChartItem {
  const BarChartItem({required this.label, required this.value});

  final String label;
  final int value;
}

/// Plain bars drawn with boxes. The biggest value fills [height] minus the label line.
/// Tap a bar when [onSelected] is set. The selected bar is drawn in the main colour.
class BarChart extends StatelessWidget {
  const BarChart({required this.items, required this.height, super.key, this.selected, this.onSelected});

  final List<BarChartItem> items;
  final double height;
  final int? selected;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    final peak = items.fold<int>(1, (m, item) => math.max(m, item.value));
    final scheme = context.scheme;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                button: onSelected != null,
                selected: selected == i,
                label: items[i].label,
                child: InkWell(
                  onTap: onSelected == null ? null : () => onSelected!(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: (items[i].value / peak).clamp(0.0, 1.0),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: selected == i ? scheme.primary : scheme.primary.withValues(alpha: 0.4),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(items[i].label, style: context.text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
