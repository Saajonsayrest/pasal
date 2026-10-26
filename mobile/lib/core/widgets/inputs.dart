import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';

/// A text field with the label above it (website style) and the server error under it.
///
///     PField(label: 'Name', controller: name, error: save.field('name'))
class PField extends StatelessWidget {
  const PField({
    required this.label,
    super.key,
    this.controller,
    this.error,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
    this.onChanged,
    this.prefixText,
    this.suffix,
    this.textInputAction,
    this.autofocus = false,
    this.enabled = true,
    this.inputFormatters,
    this.onSubmitted,
    this.autofillHints,
    this.helper,
    this.maxLength,
  });

  final String label;
  final TextEditingController? controller;
  final String? error;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? prefixText;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          minLines: 1,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          autofocus: autofocus,
          enabled: enabled,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            suffixIcon: suffix,
            errorText: error,
            errorMaxLines: 3,
            counterText: '',
          ),
        ),
        if (helper != null && error == null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(helper!, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
          ),
      ],
    );
  }
}

/// An amount box in rupees: digits and one dot with two decimals. Read it with `toPaisa(controller.text)`.
class MoneyField extends StatelessWidget {
  const MoneyField({required this.label, required this.controller, super.key, this.error, this.onChanged, this.hint, this.helper, this.autofocus = false});

  final String label;
  final TextEditingController controller;
  final String? error;
  final String? hint;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return PField(
      label: label,
      controller: controller,
      error: error,
      hint: hint ?? '0',
      helper: helper,
      prefixText: 'Rs ',
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,12}\.?\d{0,2}'))],
      onChanged: onChanged,
    );
  }
}

/// Filter chips, one active at a time.
///
///     ChipsRow<String>(value: filter, options: {'all': 'All', 'owes': 'Owes money'}, onChanged: (v) => ...)
class ChipsRow<T> extends StatelessWidget {
  const ChipsRow({required this.value, required this.options, required this.onChanged, super.key});

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in options.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: e.key == value,
                showCheckmark: false,
                onSelected: (_) => onChanged(e.key),
              ),
            ),
        ],
      ),
    );
  }
}

/// Segmented control (cash / QR / bank, sort order, add or remove).
class Seg<T> extends StatelessWidget {
  const Seg({required this.value, required this.options, required this.onChanged, super.key, this.icons});

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final Map<T, IconData>? icons;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: [
        for (final e in options.entries)
          ButtonSegment<T>(value: e.key, label: Text(e.value, overflow: TextOverflow.ellipsis), icon: icons?[e.key] == null ? null : Icon(icons![e.key], size: 18)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// The main button of a form. Shows a small spinner while saving and ignores taps then.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({required this.label, required this.onPressed, super.key, this.busy = false, this.icon, this.tone});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  /// `good` makes it green (money received).
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: tone == null ? null : FilledButton.styleFrom(backgroundColor: tone),
        icon: busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
            : (icon == null ? const SizedBox.shrink() : Icon(icon)),
        label: Text(label),
      ),
    );
  }
}
