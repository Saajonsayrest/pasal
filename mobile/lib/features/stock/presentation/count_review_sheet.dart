import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/stock/data/stock_repository.dart';

/// The last step of a stock count: the differences, then one save. Pops the [StockCountResult] when saved.
class CountReviewSheet extends ConsumerStatefulWidget {
  const CountReviewSheet({required this.lines, required this.note, super.key});

  final List<CountLine> lines;
  final String note;

  @override
  ConsumerState<CountReviewSheet> createState() => _CountReviewSheetState();
}

class _CountReviewSheetState extends ConsumerState<CountReviewSheet> {
  /// One key for this sheet. The body never changes while it is open, so every retry reuses it.
  final _key = newKey();
  bool _busy = false;
  ApiException? _error;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await guard(
      () => ref.read(stockRepositoryProvider).count(lines: widget.lines, note: widget.note, key: _key),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _busy = false);
      return;
    }
    Navigator.of(context).pop(result);
  }

  String _errorText(ApiException e) {
    for (final list in e.errors.values) {
      if (list.isNotEmpty) return list.first;
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final differences = widget.lines.where((l) => l.difference != 0).toList();
    final error = _error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('Each difference adds a change to stock history.', 'हरेक फरकले स्टक इतिहासमा परिवर्तन थप्छ।'),
          style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (differences.isEmpty)
          Text(context.tr('Everything matches the system.', 'सबै सामान सिस्टमसँग मिल्छ।'), style: context.text.bodyLarge)
        else
          ListCard(
            children: [
              for (final line in differences)
                ListRow(
                  leading: IconTile(
                    line.difference < 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    tone: line.difference < 0 ? Tone.warn : Tone.info,
                    size: 40,
                  ),
                  title: line.item.name,
                  subtitle: context.tr(
                    'System ${context.num(line.item.quantity)} · counted ${context.num(line.counted)}',
                    'सिस्टम ${context.num(line.item.quantity)} · गनेको ${context.num(line.counted)}',
                  ),
                  amount: '${line.difference > 0 ? '+' : '-'}${context.num(line.difference.abs())}',
                  amountTone: line.difference < 0 ? Tone.warn : Tone.info,
                  chevron: false,
                ),
            ],
          ),
        if (error != null) ...[
          const SizedBox(height: 12),
          AlertBox(_errorText(error)),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save count', 'गणना सेभ गर्ने'),
          icon: Icons.done_all_rounded,
          busy: _busy,
          onPressed: widget.lines.isEmpty ? null : _save,
        ),
      ],
    );
  }
}
