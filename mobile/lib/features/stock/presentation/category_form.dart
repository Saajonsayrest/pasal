import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/settings/settings.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/utils/icon_names.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/features/stock/data/category_repository.dart';

/// What the sheet did. The screen shows the matching message.
enum CategoryAction { saved, deleted }

const _categoryColors = <Color>[
  ...seedColors,
  Color(0xFF9E9D24),
  Color(0xFF8D6E63),
  Color(0xFF5C6BC0),
  Color(0xFFEF6C8F),
  Color(0xFF26A69A),
];

/// Add or edit one category: name, icon and colour. Pops a [CategoryAction].
class CategoryForm extends ConsumerStatefulWidget {
  const CategoryForm({this.category, super.key});

  /// Null for a new category.
  final Category? category;

  @override
  ConsumerState<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<CategoryForm> {
  late final TextEditingController _name = TextEditingController(text: widget.category?.name ?? '');
  late String _icon = widget.category?.icon ?? 'category';
  late String _color = _validHex(widget.category?.color);
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _validHex(String? hex) => colorFromHex(hex) == null ? hexFromColor(seedColors.first) : hex!.toLowerCase();

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await guard(
      () => ref.read(categoryRepositoryProvider).save(id: widget.category?.id, name: _name.text.trim(), icon: _icon, color: _color),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    if (saved == null) {
      setState(() => _busy = false);
      return;
    }
    Navigator.of(context).pop(CategoryAction.saved);
  }

  Future<void> _delete() async {
    final id = widget.category?.id;
    if (id == null) return;
    final sure = await confirmSheet(
      context,
      title: context.tr('Delete category?', 'वर्ग मेटाउने हो?'),
      message: context.tr('Deleting keeps the items. They just have no category.', 'मेटाउँदा सामान हट्दैनन्। तिनको वर्ग मात्र खाली हुन्छ।'),
      confirmLabel: context.tr('Delete', 'मेटाउने'),
      danger: true,
    );
    if (!sure || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final done = await guard(
      () async {
        await ref.read(categoryRepositoryProvider).remove(id);
        return true;
      },
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    if (done == null) {
      setState(() => _busy = false);
      return;
    }
    Navigator.of(context).pop(CategoryAction.deleted);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final general = error != null && error.errors.isEmpty ? error.message : null;
    final canSave = !_busy && _name.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PField(
          label: context.tr('Category name', 'वर्गको नाम'),
          controller: _name,
          hint: context.tr('Example: Spices', 'उदाहरण: मसला'),
          maxLength: 100,
          error: error?.field('name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _label(context, context.tr('Icon', 'आइकन')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final entry in categoryIconNames.entries) _iconTile(context, entry.key, entry.value)],
        ),
        const SizedBox(height: 16),
        _label(context, context.tr('Colour', 'रंग')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final color in _categoryColors) _swatch(context, color)],
        ),
        if (general != null) ...[
          const SizedBox(height: 12),
          AlertBox(general),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save', 'सेभ गर्ने'),
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: canSave ? _save : null,
        ),
        if (widget.category != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(context.tr('Delete category', 'वर्ग मेटाउने')),
            style: OutlinedButton.styleFrom(foregroundColor: context.colors.bad),
          ),
        ],
      ],
    );
  }

  Widget _label(BuildContext context, String text) =>
      Text(text, style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700));

  Widget _iconTile(BuildContext context, String name, IconData icon) {
    final scheme = context.scheme;
    final selected = _icon == name;
    return Semantics(
      label: name,
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => setState(() => _icon = name),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2),
          ),
          child: Icon(icon, color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _swatch(BuildContext context, Color color) {
    final hex = hexFromColor(color);
    final selected = _color == hex;
    return Semantics(
      label: hex,
      button: true,
      selected: selected,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _color = hex),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? context.scheme.onSurface : Colors.transparent, width: 3),
          ),
        ),
      ),
    );
  }
}
