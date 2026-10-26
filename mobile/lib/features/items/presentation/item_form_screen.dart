import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/items/data/item_pricing.dart';
import 'package:pasal_mobile/features/items/data/item_providers.dart';
import 'package:pasal_mobile/features/items/data/item_repository.dart';
import 'package:pasal_mobile/features/items/presentation/item_widgets.dart';

const _photoMaxBytes = 2 * 1024 * 1024;
const _photoExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
const _maxLowStock = 1000000;

/// Unit code, English, Nepali.
const _units = [
  ('pcs', 'pcs', 'पिस'),
  ('kg', 'kg', 'केजी'),
  ('litre', 'litre', 'लिटर'),
  ('packet', 'packet', 'प्याकेट'),
  ('dozen', 'dozen', 'दर्जन'),
];

/// D3. Add an item, or edit one (owner only). Suggests names as you type, handles a duplicate name, photo and barcode.
class ItemFormScreen extends ConsumerWidget {
  const ItemFormScreen({this.id, super.key});

  /// The item to edit, or null for a new item.
  final int? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(itemCategoriesProvider);
    final current = id == null ? null : ref.watch(itemDetailProvider(id!));
    final title = id == null ? context.tr('Add item', 'सामान थप्ने') : context.tr('Edit item', 'सामान सच्याउने');
    final ready = categories.hasValue && (current == null || current.hasValue);
    if (!ready) {
      final error = categories.hasError ? categories.error : current?.error;
      return PageScaffold(
        title: title,
        scroll: false,
        body: error != null
            ? ErrorView(
                error: error,
                onRetry: () {
                  ref.invalidate(itemCategoriesProvider);
                  if (id != null) ref.invalidate(itemDetailProvider(id!));
                },
              )
            : const SkeletonList(),
      );
    }
    return _ItemForm(editId: id, categories: categories.requireValue, item: current?.requireValue);
  }
}

class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm({required this.editId, required this.categories, required this.item});

  final int? editId;
  final List<Category> categories;
  final Item? item;

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _sell = TextEditingController();
  final _buy = TextEditingController();
  final _picker = ImagePicker();
  final _debounce = Debouncer();

  String _nameQuery = '';
  late String _unit;
  late bool _vat;
  late int? _categoryId;
  late int _lowStock;
  String? _photoUrl;
  XFile? _picked;
  String? _photoError;
  bool _photoBusy = false;

  bool _busy = false;
  ApiException? _error;
  Map<String, String> _clientErrors = {};

  bool _restoring = false;
  String? _restoreError;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _name.text = i?.name ?? '';
    _sku.text = i?.sku ?? '';
    _sell.text = i == null ? '' : fromPaisa(i.sellPrice);
    _buy.text = i?.costPrice == null ? '' : fromPaisa(i!.costPrice!);
    _unit = i?.unit ?? 'pcs';
    _vat = i?.vatApplies ?? true;
    _categoryId = i?.categoryId;
    _lowStock = i?.lowStockAt ?? 5;
    _photoUrl = i?.photoUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _sell.dispose();
    _buy.dispose();
    _debounce.dispose();
    super.dispose();
  }

  String? _fieldError(String field) => _clientErrors[field] ?? _error?.field(field);

  void _onNameChanged() {
    setState(() {});
    _debounce.run(() => setState(() => _nameQuery = _name.text.trim()));
  }

  String _sellHelper(int? sellPaisa, double vatRate) {
    if (!_vat) return context.tr('No VAT on this item', 'यो सामानमा भ्याट छैन');
    if (sellPaisa == null) return context.tr('VAT included', 'भ्याट सहित');
    final exVat = exVatPaisa(sellPaisa, vatRate);
    return '${context.tr('VAT included. Without VAT', 'भ्याट सहित। भ्याट बाहेक')}: ${context.rs(exVat, paisaDigits: true)}';
  }

  Future<void> _pickPhoto() async {
    final source = await showPasalSheet<ImageSource>(
      context,
      title: context.tr('Add photo', 'फोटो थप्ने'),
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.of(sheet).pop(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded),
            label: Text(context.tr('From gallery', 'ग्यालरीबाट')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(sheet).pop(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_rounded),
            label: Text(context.tr('Take a photo', 'फोटो खिच्ने')),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    XFile? file;
    try {
      file = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    } on Exception {
      if (mounted) showProblem(context, context.tr('Could not open the photo.', 'फोटो खोल्न सकिएन।'));
      return;
    }
    if (file == null || !mounted) return;

    final lower = file.path.toLowerCase();
    if (!_photoExtensions.any(lower.endsWith)) {
      setState(() => _photoError = context.tr('The photo must be a JPG, PNG or WebP file.', 'फोटो JPG, PNG वा WebP हुनुपर्छ।'));
      return;
    }
    final bytes = await file.length();
    if (!mounted) return;
    if (bytes > _photoMaxBytes) {
      setState(() => _photoError = context.tr('The photo must be 2 MB or smaller.', 'फोटो २ MB वा सानो हुनुपर्छ।'));
      return;
    }
    setState(() {
      _picked = file;
      _photoError = null;
    });
  }

  Future<void> _removePhoto() async {
    if (_picked != null) {
      setState(() => _picked = null);
      return;
    }
    final id = widget.editId;
    if (id == null) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    try {
      await ref.read(itemRepositoryProvider).deletePhoto(id);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _photoBusy = false;
          _photoError = e.message;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _photoBusy = false;
      _photoUrl = null;
    });
    showToast(context, 'Photo removed', 'फोटो हटाइयो');
  }

  Future<void> _scanCode() async {
    final code = await context.push<String>('/items/scan');
    if (!mounted || code == null || code.isEmpty) return;
    setState(() => _sku.text = code);
  }

  bool _check() {
    final errors = <String, String>{};
    if (_name.text.trim().isEmpty) errors['name'] = context.tr('Enter the item name.', 'सामानको नाम लेख्नुहोस्।');
    if (toPaisa(_buy.text) == null) errors['cost_price'] = context.tr('Enter the buying price, for example 86.50.', 'खरिद मूल्य लेख्नुहोस्।');
    if (toPaisa(_sell.text) == null) errors['sell_price'] = context.tr('Enter the selling price, for example 115.', 'बिक्री मूल्य लेख्नुहोस्।');
    setState(() => _clientErrors = errors);
    return errors.isEmpty;
  }

  Future<void> _save() async {
    final cost = toPaisa(_buy.text);
    final price = toPaisa(_sell.text);
    if (!_check() || cost == null || price == null) return;

    final sku = _sku.text.trim();
    final draft = ItemDraft(
      name: _name.text.trim(),
      sku: sku.isEmpty ? null : sku,
      unit: _unit,
      vatApplies: _vat,
      costPrice: cost,
      sellPrice: price,
      lowStockAt: _lowStock,
      categoryId: _categoryId,
    );
    final editId = widget.editId;
    final repo = ref.read(itemRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    final id = await guard<int>(
      () async {
        final saved = editId == null ? await repo.create(draft) : await repo.update(editId, draft);
        return saved.id;
      },
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    if (id == null) {
      setState(() => _busy = false);
      return;
    }

    var photoFailed = false;
    final picked = _picked;
    if (picked != null) {
      try {
        await repo.uploadPhoto(id, picked.path);
      } on Exception {
        photoFailed = true;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(itemListProvider);
    ref.invalidate(itemDetailProvider(id));
    ref.invalidate(lowStockCountProvider);
    ref.invalidate(stockValueProvider);
    if (photoFailed) {
      showProblem(context, context.tr('Item saved. The photo did not upload.', 'सामान सेभ भयो। फोटो अपलोड भएन।'));
    } else {
      showToast(context, 'Item saved', 'सामान सेभ भयो');
    }
    context.go('/items/$id');
  }

  Future<void> _restore(ExistingItem existing) async {
    setState(() {
      _restoring = true;
      _restoreError = null;
    });
    final restored = await guard(
      () => ref.read(itemRepositoryProvider).restore(existing.id),
      onError: (e) => _restoreError = e.message,
    );
    if (!mounted) return;
    if (restored == null) {
      setState(() => _restoring = false);
      return;
    }
    ref.invalidate(itemListProvider);
    ref.invalidate(lowStockCountProvider);
    ref.invalidate(deletedItemsProvider);
    showToast(context, 'Restored: ${existing.name}', 'फिर्ता ल्याइयो: ${existing.name}');
    context.go('/items/${existing.id}');
  }

  @override
  Widget build(BuildContext context) {
    final editId = widget.editId;
    final suggestions = ref.watch(itemSuggestProvider(_nameQuery)).value ?? const <Item>[];
    final others = [for (final s in suggestions) if (s.id != editId) s];
    final sameName = _sameNameItem(others, _name.text);
    final similar = [for (final s in others) if (s.id != sameName?.id) s];
    final error = _error;
    final existing = error == null ? null : ExistingItem.fromError(error);
    final vatRate = ref.watch(sessionProvider).business?.vatRate ?? 0;
    final sellPaisa = toPaisa(_sell.text);
    final unitOptions = <(String, String, String)>[
      ..._units,
      if (!_units.any((u) => u.$1 == _unit)) (_unit, _unit, _unit),
    ];

    return PageScaffold(
      title: editId == null ? context.tr('Add item', 'सामान थप्ने') : context.tr('Edit item', 'सामान सच्याउने'),
      bottom: PrimaryButton(
        label: context.tr('Save', 'सेभ गर्ने'),
        icon: Icons.check_rounded,
        busy: _busy,
        onPressed: _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _photoSection(),
          const SizedBox(height: 16),
          PField(
            label: context.tr('Item name', 'सामानको नाम'),
            controller: _name,
            error: _fieldError('name'),
            onChanged: (_) => _onNameChanged(),
          ),
          const SizedBox(height: 8),
          if (existing != null)
            _existingCard(existing)
          else if (sameName != null)
            _SuggestCard(
              message: context.tr(
                '${sameName.name} already exists. Use that item instead?',
                '${sameName.name} पहिल्यै छ। त्यही सामान प्रयोग गर्ने?',
              ),
              action: context.tr('Use', 'प्रयोग गर्ने'),
              onAction: () => context.go('/items/${sameName.id}'),
            ),
          if (similar.isNotEmpty && _name.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            ListCard(
              children: [
                for (final s in similar)
                  ListRow(
                    title: s.name,
                    subtitle: '${context.num(s.quantity)} ${s.unit}',
                    onTap: () => context.go('/items/${s.id}'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          PField(
            label: context.tr('Code or barcode (optional)', 'कोड वा बारकोड (वैकल्पिक)'),
            controller: _sku,
            error: _fieldError('sku'),
            suffix: IconButton(
              tooltip: context.tr('Scan code', 'कोड स्क्यान'),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: _scanCode,
            ),
          ),
          const SizedBox(height: 16),
          FormLabel(context.tr('Category', 'वर्ग')),
          DropdownButtonFormField<int?>(
            // A category that is not in the list (deleted, or not loaded yet) shows as "No category" instead of crashing.
            initialValue: widget.categories.any((c) => c.id == _categoryId) ? _categoryId : null,
            isExpanded: true,
            decoration: InputDecoration(errorText: _fieldError('category_id')),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(context.tr('No category', 'वर्ग छैन'))),
              for (final c in widget.categories) DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 16),
          FormLabel(context.tr('Unit', 'एकाइ')),
          DropdownButtonFormField<String>(
            initialValue: unitOptions.any((u) => u.$1 == _unit) ? _unit : null,
            isExpanded: true,
            decoration: InputDecoration(errorText: _fieldError('unit'), hintText: _unit),
            items: [
              for (final u in unitOptions) DropdownMenuItem<String>(value: u.$1, child: Text(context.tr(u.$2, u.$3))),
            ],
            onChanged: (v) => setState(() => _unit = v ?? _unit),
          ),
          const SizedBox(height: 16),
          MoneyField(
            label: context.tr('Selling price', 'बिक्री मूल्य'),
            controller: _sell,
            error: _fieldError('sell_price'),
            helper: _sellHelper(sellPaisa, vatRate),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          MoneyField(
            label: context.tr('Buying price', 'खरिद मूल्य'),
            controller: _buy,
            error: _fieldError('cost_price'),
            helper: context.tr('Without VAT', 'भ्याट बाहेक'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          PCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('VAT applies', 'भ्याट लाग्ने'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text(context.tr('Turn off for items with no VAT, like milk', 'दूध जस्तो भ्याट नलाग्ने सामानमा बन्द गर्नुहोस्')),
              value: _vat,
              onChanged: (v) => setState(() => _vat = v),
            ),
          ),
          const SizedBox(height: 12),
          PCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('Low stock level', 'कम स्टकको सीमा'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        context.tr('Alert me when stock is below this', 'यो भन्दा कम हुँदा सूचना आउँछ'),
                        style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Less', 'कम'),
                  onPressed: _lowStock <= 0 ? null : () => setState(() => _lowStock--),
                  icon: const Icon(Icons.remove_rounded),
                ),
                Text(context.num(_lowStock), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                IconButton(
                  tooltip: context.tr('More', 'थप'),
                  onPressed: _lowStock >= _maxLowStock ? null : () => setState(() => _lowStock++),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          if (editId == null) ...[
            const SizedBox(height: 16),
            AlertBox(
              context.tr('New items start at 0 stock. Stock comes in from purchases.', 'नयाँ सामानको स्टक ० बाट सुरु हुन्छ। स्टक खरिदबाट थपिन्छ।'),
              tone: Tone.info,
              icon: Icons.info_outline_rounded,
            ),
          ],
          if (error != null && error.errors.isEmpty && existing == null) ...[
            const SizedBox(height: 16),
            AlertBox(error.message),
          ],
        ],
      ),
    );
  }

  Widget _existingCard(ExistingItem existing) {
    return _SuggestCard(
      message: existing.deleted
          ? context.tr('"${existing.name}" was deleted before.', '"${existing.name}" पहिले हटाइएको थियो।')
          : context.tr('${existing.name} already exists. Use that item instead?', '${existing.name} पहिल्यै छ। त्यही सामान प्रयोग गर्ने?'),
      action: existing.deleted ? context.tr('Restore it?', 'फिर्ता ल्याउने?') : context.tr('Use', 'प्रयोग गर्ने'),
      onAction: existing.deleted ? () => _restore(existing) : () => context.go('/items/${existing.id}'),
      busy: _restoring,
      error: existing.deleted ? _restoreError : null,
    );
  }

  Widget _photoSection() {
    final scheme = context.scheme;
    final picked = _picked;
    final url = _photoUrl;
    final hasPhoto = picked != null || url != null;
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: _photoBusy ? null : _pickPhoto,
          child: Container(
            width: 88,
            height: 88,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: scheme.outline),
            ),
            child: picked != null
                ? Image.file(File(picked.path), fit: BoxFit.cover)
                : url != null
                    ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.broken_image_rounded, color: scheme.onSurfaceVariant))
                    : Icon(Icons.add_a_photo_rounded, color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Item photo', 'सामानको फोटो'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                context.tr('Optional. It helps you find the item when selling.', 'फोटो वैकल्पिक हो। बिक्री गर्दा सामान चिन्न सजिलो हुन्छ।'),
                style: context.text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (hasPhoto)
                TextButton.icon(
                  onPressed: _photoBusy ? null : _removePhoto,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(context.tr('Remove photo', 'फोटो हटाउने')),
                ),
              if (_photoError != null)
                Text(_photoError!, style: context.text.bodySmall?.copyWith(color: context.colors.bad)),
            ],
          ),
        ),
      ],
    );
  }
}

/// A tinted box with one message and one action (use the item that exists, restore a deleted one).
class _SuggestCard extends StatelessWidget {
  const _SuggestCard({required this.message, required this.action, required this.onAction, this.busy = false, this.error});

  final String message;
  final String action;
  final VoidCallback onAction;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return PCard(
      tone: Tone.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_rounded, color: context.colors.info),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(onPressed: busy ? null : onAction, child: Text(action)),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: context.text.bodySmall?.copyWith(color: context.colors.bad)),
            ),
        ],
      ),
    );
  }
}

/// The item whose name is the same as [name], ignoring capitals and spaces at the ends.
Item? _sameNameItem(List<Item> items, String name) {
  final wanted = name.trim().toLowerCase();
  if (wanted.isEmpty) return null;
  for (final item in items) {
    if (item.name.trim().toLowerCase() == wanted) return item;
  }
  return null;
}
