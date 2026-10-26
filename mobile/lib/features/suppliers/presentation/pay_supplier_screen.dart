import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/core/widgets/amount_pad.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/suppliers/data/purchase_math.dart';
import 'package:pasal_mobile/features/suppliers/data/purchase_repository.dart';
import 'package:pasal_mobile/features/suppliers/data/save_key.dart';
import 'package:pasal_mobile/features/suppliers/data/supplier_repository.dart';
import 'package:pasal_mobile/features/suppliers/presentation/supplier_widgets.dart';

/// F5. Pay a supplier in one amount. The money goes to the oldest open bills first, and the screen shows that
/// split before saving.
class PaySupplierScreen extends ConsumerWidget {
  const PaySupplierScreen({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(supplierLedgerProvider(id));
    final ledger = data.value;
    if (ledger != null) return _PayBody(id: id, ledger: ledger);

    return PageScaffold(
      title: context.tr('Pay supplier', 'डिलरलाई भुक्तानी'),
      body: data.hasError
          ? ErrorView(error: data.error!, onRetry: () => ref.invalidate(supplierLedgerProvider(id)))
          : const SkeletonList(),
    );
  }
}

/// Paisa for the quick amount buttons: Rs 10,000 and Rs 20,000.
const _quickAmounts = [1000000, 2000000];

class _PayBody extends ConsumerStatefulWidget {
  const _PayBody({required this.id, required this.ledger});

  final int id;
  final SupplierLedger ledger;

  @override
  ConsumerState<_PayBody> createState() => _PayBodyState();
}

class _PayBodyState extends ConsumerState<_PayBody> {
  late String _amount = fromPaisa(widget.ledger.weOwe);
  String _method = 'cash';
  bool _busy = false;
  ApiException? _error;
  final _saveKey = SaveKey();

  int get _owed => widget.ledger.weOwe;
  int get _amountPaisa => toPaisa(_amount) ?? 0;
  bool get _tooMuch => _amountPaisa > _owed;
  List<PaymentStep> get _plan => planOldestFirst(widget.ledger.purchases, _amountPaisa);
  int get _applied => _plan.fold<int>(0, (sum, step) => sum + step.take);

  Future<void> _save() async {
    final amount = _amountPaisa;
    if (_busy || amount <= 0 || _tooMuch) return;
    final supplierId = widget.id;
    final method = _method;
    setState(() {
      _busy = true;
      _error = null;
    });
    final key = _saveKey.forBody(jsonEncode({'supplier_id': supplierId, 'amount': amount, 'method': method}));
    final owesLeft = await guard(
      () => ref.read(supplierRepositoryProvider).payOldestFirst(supplierId: supplierId, amount: amount, method: method, key: key),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (owesLeft == null) return;

    _saveKey.reset();
    ref.invalidate(supplierLedgerProvider(supplierId));
    ref.invalidate(suppliersProvider);
    ref.invalidate(allSuppliersProvider);
    ref.invalidate(purchasePageProvider);
    ref.invalidate(purchaseSummaryProvider);
    showToast(
      context,
      'Payment saved. We owe ${context.rs(owesLeft)}.',
      'भुक्तानी सेभ भयो। हामीले ${context.rs(owesLeft)} तिर्नुपर्छ।',
    );
    context.pushReplacement('/suppliers/$supplierId');
  }

  @override
  Widget build(BuildContext context) {
    final ledger = widget.ledger;
    final open = openBillsOldestFirst(ledger.purchases);
    final plan = _plan;
    final canSave = !_busy && _amountPaisa > 0 && !_tooMuch;
    final error = _error;

    return PageScaffold(
      title: context.tr('Pay supplier', 'डिलरलाई भुक्तानी'),
      bottom: open.isEmpty
          ? null
          : PrimaryButton(
              label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save payment', 'सेभ गर्ने'),
              icon: Icons.check_rounded,
              tone: context.colors.good,
              busy: _busy,
              onPressed: canSave ? _save : null,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeroCard(
            tone: Tone.warn,
            child: StatBlock(
              large: true,
              tone: Tone.warn,
              label: context.tr('We owe ${ledger.supplier.name}', '${ledger.supplier.name} लाई हामीले तिर्ने'),
              value: context.rs(_owed),
              sub: context.tr(
                '${context.num(open.length)} open ${context.plural(open.length, 'bill', 'bills')}',
                '${context.num(open.length)} खुला बिल',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (open.isEmpty)
            SizedBox(
              height: 320,
              child: EmptyState(
                icon: Icons.task_alt_rounded,
                title: context.tr('Nothing to pay', 'तिर्नुपर्ने बाँकी छैन'),
                text: context.tr('All bills with this supplier are paid.', 'यो डिलरका सबै बिल चुक्ता छन्।'),
              ),
            )
          else ...[
            SectionHeading(context.tr('Oldest bills are paid first', 'सबैभन्दा पुरानो बिल पहिले तिरिन्छ')),
            ListCard(
              children: [
                for (var i = 0; i < open.length; i++)
                  ListRow(
                    leading: const IconTile(Icons.receipt_long_rounded, tone: Tone.info),
                    title: open[i].billNo ?? context.tr('No bill number', 'बिल नम्बर छैन'),
                    subtitle: '${formatDate(open[i].boughtAt)} · ${daysAgoText(context, daysAgo(open[i].boughtAt))}',
                    amount: context.rs(open[i].balance),
                    amountLabel: ordinalLabel(context, i + 1),
                    chevron: false,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            KeyValueRow(label: context.tr('Total we owe', 'जम्मा हामीले तिर्ने'), value: context.rs(_owed), strong: true),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(context.tr('Full ${context.rs(_owed)}', 'पूरा ${context.rs(_owed)}')),
                  selected: _amountPaisa == _owed,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _amount = fromPaisa(_owed)),
                ),
                for (final q in _quickAmounts)
                  ChoiceChip(
                    label: Text(context.rs(q)),
                    selected: _amountPaisa == q,
                    showCheckmark: false,
                    onSelected: q > _owed ? null : (_) => setState(() => _amount = fromPaisa(q)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AmountPad(value: _amount, onChanged: (v) => setState(() => _amount = v)),
            const SizedBox(height: 8),
            PaymentMethodPicker(value: _method, onChanged: (v) => setState(() => _method = v)),
            if (plan.isNotEmpty) ...[
              const SizedBox(height: 12),
              PCard(
                tone: Tone.neutral,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr('The money will be used like this', 'पैसा यसरी मिलाइन्छ'),
                      style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                    for (final step in plan)
                      KeyValueRow(
                        label: step.bill.billNo ?? context.tr('No bill number', 'बिल नम्बर छैन'),
                        value: context.tr('${context.rs(step.take)} paid off', '${context.rs(step.take)} चुक्ता'),
                      ),
                    KeyValueRow(
                      label: context.tr('After this, we owe', 'त्यसपछि हामीले तिर्ने'),
                      value: context.rs(_owed - _applied),
                      valueColor: context.colors.good,
                      strong: true,
                    ),
                  ],
                ),
              ),
            ],
            if (_tooMuch) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.error_rounded, size: 18, color: context.colors.bad),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.tr('The amount is more than we owe (${context.rs(_owed)}).', 'रकम हामीले तिर्नुपर्ने ${context.rs(_owed)} भन्दा बढी छ।'),
                      style: context.text.bodySmall?.copyWith(color: context.colors.bad, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              context.tr('The money pays the oldest bills first.', 'पैसा सबैभन्दा पुरानो बिलबाट मिलाइन्छ।'),
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              AlertBox(error.field('amount') ?? error.message),
            ],
          ],
        ],
      ),
    );
  }
}
