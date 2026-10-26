import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/core/widgets/bs_date.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/suppliers/data/purchase_math.dart';
import 'package:pasal_mobile/features/suppliers/data/purchase_repository.dart';
import 'package:pasal_mobile/features/suppliers/data/save_key.dart';
import 'package:pasal_mobile/features/suppliers/data/supplier_repository.dart';
import 'package:pasal_mobile/features/suppliers/presentation/pickers.dart';
import 'package:pasal_mobile/features/suppliers/presentation/supplier_widgets.dart';

/// F3. Record a bill from a supplier: pick the supplier, the items and their unit cost, the VAT on the bill and
/// what was paid now. Stock goes up on save. A photo of the paper bill is not supported.
class NewPurchaseScreen extends ConsumerStatefulWidget {
  const NewPurchaseScreen({this.supplierId, this.prefillItems, super.key});

  /// The supplier to start with (a link from a supplier ledger: `?supplier=3`).
  final int? supplierId;

  /// Items to start with, as `itemId:quantity` pairs separated by commas (`?items=7:100,9:20`).
  final String? prefillItems;

  @override
  ConsumerState<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

/// One item line. The text boxes are owned here and disposed with the screen.
class _Line {
  _Line(this.item, int quantity, {String? unitCost})
      : qty = TextEditingController(text: '$quantity'),
        cost = TextEditingController(text: unitCost ?? (item.costPrice == null ? '' : fromPaisa(item.costPrice!)));

  final Item item;
  final TextEditingController qty;
  final TextEditingController cost;

  void dispose() {
    qty.dispose();
    cost.dispose();
  }
}

String? _optionalText(TextEditingController c) {
  final text = c.text.trim();
  return text.isEmpty ? null : text;
}

class _NewPurchaseScreenState extends ConsumerState<NewPurchaseScreen> {
  /// Server errors shown under their own box. Other field errors go to the alert at the bottom.
  static const _inlineFields = {'bill_no', 'vat_amount', 'paid'};

  int? _supplierId;
  final _billNo = TextEditingController();
  String _billDate = todayAd();
  final _lines = <_Line>[];

  /// Lines removed from the bill. Their boxes are disposed with the screen, not at once.
  final _removed = <_Line>[];
  final _vat = TextEditingController();
  final _paid = TextEditingController();
  final _note = TextEditingController();
  String _method = 'cash';
  bool _busy = false;
  bool _prefillFailed = false;
  ApiException? _error;
  final _saveKey = SaveKey();

  @override
  void initState() {
    super.initState();
    _supplierId = widget.supplierId;
    final prefill = widget.prefillItems;
    if (prefill != null && prefill.isNotEmpty) unawaited(_prefill(prefill));
  }

  @override
  void dispose() {
    _billNo.dispose();
    _vat.dispose();
    _paid.dispose();
    _note.dispose();
    for (final line in [..._lines, ..._removed]) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _prefill(String text) async {
    final repo = ref.read(purchaseRepositoryProvider);
    for (final pair in text.split(',')) {
      final parts = pair.split(':');
      final itemId = wholeNumber(parts.first);
      final quantity = parts.length < 2 ? null : wholeNumber(parts[1]);
      if (itemId == null || quantity == null || quantity < 1) continue;
      try {
        final item = await repo.item(itemId);
        if (!mounted) return;
        if (_lines.any((l) => l.item.id == item.id)) continue;
        setState(() => _lines.add(_Line(item, quantity)));
      } on ApiException {
        if (!mounted) return;
        setState(() => _prefillFailed = true);
      }
    }
  }

  int get _linesTotal {
    var sum = 0;
    for (final line in _lines) {
      sum += lineTotalPaisa(parseQuantity(line.qty.text), parseUnitCost(line.cost.text)) ?? 0;
    }
    return sum;
  }

  int? get _vatPaisa => optionalPaisa(_vat.text);
  int? get _paidPaisa => optionalPaisa(_paid.text);
  int get _total => _linesTotal + (_vatPaisa ?? 0);
  int get _balance => _total - (_paidPaisa ?? 0);

  /// The body for POST /purchases, or null when the form is not complete and valid.
  Json? _payload() {
    final supplier = _supplierId;
    final vat = _vatPaisa;
    final paid = _paidPaisa;
    if (supplier == null || vat == null || paid == null || paid > _total || _lines.isEmpty) return null;
    final items = <Json>[];
    for (final line in _lines) {
      final quantity = parseQuantity(line.qty.text);
      final unitCost = parseUnitCost(line.cost.text);
      if (quantity == null || unitCost == null) return null;
      items.add({'item_id': line.item.id, 'quantity': quantity, 'unit_cost': unitCost});
    }
    return {
      'supplier_id': supplier,
      'bill_no': _optionalText(_billNo),
      'bill_date': _billDate,
      'vat_amount': vat,
      'paid': paid,
      'method': _method,
      'note': _optionalText(_note),
      'items': items,
    };
  }

  Future<void> _save() async {
    final body = _payload();
    if (body == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final key = _saveKey.forBody(jsonEncode(body));
    final saved = await guard(
      () => ref.read(purchaseRepositoryProvider).create(body, key),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;

    _saveKey.reset();
    ref.invalidate(purchasePageProvider);
    ref.invalidate(purchaseSummaryProvider);
    ref.invalidate(suppliersProvider);
    ref.invalidate(allSuppliersProvider);
    ref.invalidate(supplierLedgerProvider(saved.supplierId));
    showToast(
      context,
      'Purchase saved. We owe ${context.rs(saved.balance)}.',
      'खरिद सेभ भयो। हामीले ${context.rs(saved.balance)} तिर्नुपर्छ।',
    );
    context.pushReplacement('/purchases/${saved.id}');
  }

  Future<void> _pickSupplier(List<Supplier> suppliers) async {
    final pick = await showSupplierPicker(context, suppliers: suppliers);
    final supplier = pick?.supplier;
    if (supplier == null || !mounted) return;
    setState(() => _supplierId = supplier.id);
  }

  Future<void> _addItem() async {
    final item = await showItemPicker(context, added: {for (final l in _lines) l.item.id});
    if (item == null || !mounted) return;
    setState(() {
      final existing = findFirst(_lines, (l) => l.item.id == item.id);
      if (existing == null) {
        _lines.add(_Line(item, 1));
      } else {
        existing.qty.text = '${(parseQuantity(existing.qty.text) ?? 0) + 1}';
      }
    });
  }

  void _removeLine(_Line line) {
    setState(() {
      _lines.remove(line);
      _removed.add(line);
    });
  }

  void _bump(_Line line, int by) {
    setState(() {
      final next = (parseQuantity(line.qty.text) ?? 0) + by;
      line.qty.text = '${next < 1 ? 1 : next}';
    });
  }

  String? _vatProblem(BuildContext context) {
    if (_vatPaisa == null) return context.tr('Type the VAT as a number, for example 2,327.', 'भ्याट संख्यामा लेख्नुहोस्, जस्तै: २,३२७।');
    return _error?.field('vat_amount');
  }

  String? _paidProblem(BuildContext context) {
    final paid = _paidPaisa;
    if (paid == null) return context.tr('Type the amount as a number.', 'रकम संख्यामा लेख्नुहोस्।');
    if (paid > _total) {
      return context.tr('Paid cannot be more than the total (${context.rs(_total)}).', 'तिरेको रकम जम्मा (${context.rs(_total)}) भन्दा बढी हुन सक्दैन।');
    }
    return _error?.field('paid');
  }

  /// Server problems that no box shows.
  String? _generalProblem() {
    final err = _error;
    if (err == null) return null;
    if (err.errors.isEmpty) return err.message;
    for (final entry in err.errors.entries) {
      if (!_inlineFields.contains(entry.key) && entry.value.isNotEmpty) return entry.value.first;
    }
    return null;
  }

  Widget _lineCard(BuildContext context, _Line line) {
    final quantity = parseQuantity(line.qty.text);
    final unitCost = parseUnitCost(line.cost.text);
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(line.item.name, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
              Text(context.rs(lineTotalPaisa(quantity, unitCost) ?? 0), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              IconButton(
                tooltip: context.tr('Remove item', 'सामान हटाउने'),
                onPressed: () => _removeLine(line),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: context.tr('One less', 'एउटा कम'),
                          onPressed: () => _bump(line, -1),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        SizedBox(
                          width: 64,
                          child: TextField(
                            controller: line.qty,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            decoration: const InputDecoration(filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          tooltip: context.tr('One more', 'एउटा थप'),
                          onPressed: () => _bump(line, 1),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    if (quantity == null)
                      Text(
                        context.tr('Type a quantity of 1 or more.', 'मात्रा १ वा बढी लेख्नुहोस्।'),
                        style: context.text.bodySmall?.copyWith(color: context.colors.bad),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                child: MoneyField(
                  label: context.tr('Unit cost', 'प्रति एकाइ मूल्य'),
                  controller: line.cost,
                  helper: context.tr('each, before VAT', 'प्रति एकाइ, भ्याट बाहेक'),
                  error: unitCost == null ? context.tr('Type the price in rupees.', 'मूल्य रुपैयामा लेख्नुहोस्।') : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(allSuppliersProvider);
    final supplierList = suppliers.value ?? const <Supplier>[];
    final supplier = findFirst(supplierList, (s) => s.id == _supplierId);
    final ready = _payload() != null;
    final general = _generalProblem();

    return PageScaffold(
      title: context.tr('New purchase', 'नयाँ खरिद'),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!ready)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                context.tr('Pick a supplier, add at least one item and check the amounts.', 'डिलर छान्नुहोस्, कम्तीमा एउटा सामान थप्नुहोस्, र रकम जाँच गर्नुहोस्।'),
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
            ),
          PrimaryButton(
            label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save purchase', 'खरिद सेभ गर्ने'),
            icon: Icons.check_rounded,
            busy: _busy,
            onPressed: ready ? _save : null,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(context.tr('Supplier', 'डिलर')),
          if (suppliers.hasError && !suppliers.hasValue)
            ErrorView(error: suppliers.error!, onRetry: () => ref.invalidate(allSuppliersProvider))
          else
            ListCard(
              children: [
                ListRow(
                  leading: AvatarCircle(supplier?.name ?? '?', tone: Tone.info),
                  title: supplier?.name ?? context.tr('Pick a supplier', 'डिलर छान्नुहोस्'),
                  subtitle: supplier == null
                      ? context.tr('Tap to choose who you bought from', 'कसबाट किनुभयो छान्न ट्याप गर्नुहोस्')
                      : context.tr(
                          'We owe ${context.rs(supplier.weOwe ?? 0)} · tap to change',
                          'हामीले तिर्ने ${context.rs(supplier.weOwe ?? 0)} · फेर्न ट्याप गर्नुहोस्',
                        ),
                  onTap: () => _pickSupplier(supplierList),
                ),
              ],
            ),
          const SizedBox(height: 8),
          SectionHeading(context.tr('Bill', 'बिल')),
          PField(
            label: context.tr('Bill number', 'बिल नम्बर'),
            hint: context.tr('For example: INV-902', 'जस्तै: INV-902'),
            controller: _billNo,
            error: _error?.field('bill_no'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          BsDateField(
            label: context.tr('Bill date (BS)', 'बिल मिति (BS)'),
            value: _billDate,
            max: todayAd(),
            onChanged: (v) => setState(() => _billDate = v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              context.tr('VAT counts in the month of the bill date.', 'VAT बिलको मितिको महिनामा गणना हुन्छ।'),
              style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 14),
          AlertBox(
            context.tr(
              'A photo of the paper bill is not supported yet. Type the bill number and VAT instead.',
              'कागजी बिलको फोटो अहिले राख्न मिल्दैन। बिल नम्बर र भ्याट लेख्नुहोस्।',
            ),
            tone: Tone.info,
            icon: Icons.photo_camera_rounded,
          ),
          const SizedBox(height: 8),
          SectionHeading(
            context.tr('Items', 'सामान'),
            action: context.tr('Add item', 'सामान थप्ने'),
            onAction: _addItem,
          ),
          if (_prefillFailed) ...[
            AlertBox(context.tr('Some items could not be loaded. Add them again.', 'केहि सामान लोड भएनन्। फेरि थप्नुहोस्।')),
            const SizedBox(height: 10),
          ],
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.tr('No items yet. Tap Add item.', 'अहिलेसम्म सामान छैन। सामान थप्न ट्याप गर्नुहोस्।'),
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
            ),
          for (final line in _lines) ...[
            _lineCard(context, line),
            const SizedBox(height: 10),
          ],
          if (_lines.isNotEmpty) ...[
            AlertBox(
              context.tr('The buying price of each item changes to this cost.', 'हरेक सामानको किन्ने मूल्य यो लागतमा बदलिन्छ।'),
              tone: Tone.info,
              icon: Icons.update_rounded,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          MoneyField(
            label: context.tr('VAT on the bill', 'बिलमा भएको भ्याट'),
            controller: _vat,
            error: _vatProblem(context),
            helper: context.tr('Copy the VAT amount from the paper bill. Leave empty if there is none.', 'कागजी बिलमा लेखिएको भ्याट राख्नुहोस्। बिलमा नभए खाली छोड्नुहोस्।'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          PCard(
            child: Column(
              children: [
                KeyValueRow(label: context.tr('Lines total', 'सामानको जम्मा'), value: context.rs(_linesTotal)),
                KeyValueRow(label: context.tr('VAT (from bill)', 'भ्याट (बिलबाट)'), value: context.rs(_vatPaisa ?? 0)),
                KeyValueRow(label: context.tr('Total', 'जम्मा'), value: context.rs(_total), strong: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          MoneyField(
            label: context.tr('Paid now', 'अहिले तिरेको'),
            controller: _paid,
            error: _paidProblem(context),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          PaymentMethodPicker(value: _method, onChanged: (v) => setState(() => _method = v)),
          const SizedBox(height: 14),
          KeyValueRow(
            label: context.tr('We owe after this', 'अब हामीले तिर्ने'),
            value: context.rs(_balance < 0 ? 0 : _balance),
            valueColor: context.colors.warn,
            strong: true,
          ),
          const SizedBox(height: 14),
          PField(
            label: context.tr('Note (optional)', 'नोट (ऐच्छिक)'),
            controller: _note,
            maxLines: 2,
          ),
          if (general != null) ...[
            const SizedBox(height: 14),
            AlertBox(general),
          ],
        ],
      ),
    );
  }
}
