import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/items/data/item_providers.dart';
import 'package:pasal_mobile/features/items/presentation/item_widgets.dart';

const _maxQty = 1000000;

/// Quick reasons. The note that is saved is always the English word, as on the website.
const _reasons = [
  ('Damaged', 'बिग्रिएको'),
  ('Expired', 'म्याद सकिएको'),
  ('Counted again', 'फेरि गनेको'),
  ('Gift', 'उपहार'),
  ('Other', 'अन्य'),
];

/// Add or remove stock by hand, with a reason. Used in the item details sheet and on the Adjust stock page.
class AdjustStockSheet extends ConsumerStatefulWidget {
  const AdjustStockSheet({required this.item, required this.onSaved, super.key});

  final Item item;

  /// Called with the updated item after the server saved the change.
  final ValueChanged<Item> onSaved;

  @override
  ConsumerState<AdjustStockSheet> createState() => _AdjustStockSheetState();
}

class _AdjustStockSheetState extends ConsumerState<AdjustStockSheet> {
  final _qty = TextEditingController(text: '1');
  final _note = TextEditingController();
  bool _add = false;
  bool _busy = false;
  ApiException? _error;

  /// One key per save. A new key whenever the change in the form changes.
  String _key = newKey();

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _amount {
    final v = int.tryParse(_qty.text.trim());
    return v != null && v >= 1 && v <= _maxQty ? v : 0;
  }

  int get _change => _add ? _amount : -_amount;
  int get _next => widget.item.quantity + _change;
  bool get _tooLow => _next < 0;
  bool get _canSave => !_busy && _amount > 0 && _note.text.trim().isNotEmpty && !_tooLow;

  void _changed(VoidCallback change) {
    setState(() {
      change();
      _key = newKey();
    });
  }

  void _step(int by) {
    var next = _amount + by;
    if (next < 1) next = 1;
    if (next > _maxQty) next = _maxQty;
    _changed(() => _qty.text = '$next');
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final change = _change;
    final note = _note.text.trim();
    final key = _key;
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await guard(
      () => ref.read(itemRepositoryProvider).adjustStock(itemId: widget.item.id, change: change, note: note, key: key),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    if (saved == null) {
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = false;
      _key = newKey();
    });
    ref.invalidate(itemDetailProvider(widget.item.id));
    ref.invalidate(itemMovementsProvider(widget.item.id));
    ref.invalidate(itemListProvider);
    ref.invalidate(lowStockCountProvider);
    ref.invalidate(stockValueProvider);
    showToast(
      context,
      'Stock updated: ${saved.name} now ${saved.quantity} ${saved.unit}',
      'स्टक मिलाइयो: ${saved.name} अब ${context.num(saved.quantity)} ${saved.unit}',
    );
    widget.onSaved(saved);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final qtyError = error?.field('quantity') ?? error?.field('change');
    final noteError = error?.field('note');
    final generalError = error != null && error.errors.isEmpty ? error.message : null;
    final unit = widget.item.unit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Seg<bool>(
          value: _add,
          onChanged: (v) => _changed(() => _add = v),
          options: {true: context.tr('Add', 'थप्ने'), false: context.tr('Remove', 'घटाउने')},
          icons: const {true: Icons.add_rounded, false: Icons.remove_rounded},
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                '${context.tr('How many', 'कति')} ($unit)',
                style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: context.tr('Less', 'कम'),
              onPressed: () => _step(-1),
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 72,
              child: TextField(
                controller: _qty,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(),
                onChanged: (_) => _changed(() {}),
              ),
            ),
            IconButton(
              tooltip: context.tr('More', 'थप'),
              onPressed: () => _step(1),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        if (qtyError != null) ...[
          const SizedBox(height: 8),
          AlertBox(qtyError),
        ],
        const SizedBox(height: 16),
        FormLabel(context.tr('Reason', 'कारण')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in _reasons)
              ChoiceChip(
                label: Text(context.tr(r.$1, r.$2)),
                selected: _note.text.trim() == r.$1,
                showCheckmark: false,
                onSelected: (_) => _changed(() => _note.text = r.$1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PField(
          label: context.tr('Note (required)', 'नोट (अनिवार्य)'),
          controller: _note,
          maxLines: 2,
          hint: context.tr('Example: 2 trays broke on the way', 'उदाहरण: बाटोमा २ ट्रे फुट्यो'),
          error: noteError,
          onChanged: (_) => _changed(() {}),
        ),
        if (_tooLow) ...[
          const SizedBox(height: 12),
          AlertBox(context.tr('Stock cannot go below 0.', 'स्टक ० भन्दा कम हुन सक्दैन।'), tone: Tone.warn, icon: Icons.warning_amber_rounded),
        ],
        const SizedBox(height: 12),
        PCard(
          tone: Tone.primary,
          child: Row(
            children: [
              Expanded(child: Text(context.tr('New stock', 'नयाँ स्टक'), style: context.text.titleSmall)),
              Text(
                '${context.num(_next)} $unit',
                style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: _tooLow ? context.colors.bad : null),
              ),
            ],
          ),
        ),
        if (generalError != null) ...[
          const SizedBox(height: 12),
          AlertBox(generalError),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save', 'सेभ गर्ने'),
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: _canSave ? _save : null,
        ),
      ],
    );
  }
}
