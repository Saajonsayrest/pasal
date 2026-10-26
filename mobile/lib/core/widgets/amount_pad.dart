import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/money.dart';

/// Big amount display with a number keypad (Cashew style). [value] is the typed text in rupees,
/// for example "1250.5". Turn it into paisa with `toPaisa(value)`.
///
///     AmountPad(value: raw, onChanged: (v) => setState(() => raw = v))
class AmountPad extends StatelessWidget {
  const AmountPad({required this.value, required this.onChanged, super.key});

  final String value;
  final ValueChanged<String> onChanged;

  static String press(String current, String key) {
    var raw = current.isEmpty ? '0' : current;
    if (key == 'del') {
      raw = raw.length > 1 ? raw.substring(0, raw.length - 1) : '0';
    } else if (key == '.') {
      if (raw.contains('.')) return raw;
      raw += '.';
    } else {
      final dot = raw.indexOf('.');
      if (dot != -1 && raw.length - dot - 1 >= 2) return raw; // paisa has two digits
      if (raw.replaceAll('.', '').length >= 12) return raw;
      raw = raw == '0' ? key : raw + key;
    }
    return raw;
  }

  String _shown() {
    final parts = (value.isEmpty ? '0' : value).split('.');
    final whole = groupIndian(int.tryParse(parts[0]) ?? 0);
    return digits(parts.length > 1 ? '$whole.${parts[1]}' : whole);
  }

  @override
  Widget build(BuildContext context) {
    Widget key(String k, {Widget? child, bool fn = false}) => Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: fn ? Colors.transparent : context.scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(Radii.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: () => onChanged(press(value, k)),
              child: SizedBox(
                height: 56,
                child: Center(
                  child: child ?? Text(digits(k), style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Rs', style: context.text.titleLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_shown(), style: context.text.displayMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1)),
                ),
              ),
            ],
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final k in row) Expanded(child: key(k))]),
        Row(
          children: [
            Expanded(child: key('.', fn: true, child: Text('.', style: context.text.headlineSmall?.copyWith(color: context.scheme.onSurfaceVariant)))),
            Expanded(child: key('0')),
            Expanded(child: key('del', fn: true, child: Icon(Icons.backspace_outlined, color: context.scheme.onSurfaceVariant))),
          ],
        ),
      ],
    );
  }
}
