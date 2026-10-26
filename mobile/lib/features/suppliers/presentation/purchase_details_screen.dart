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
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/suppliers/data/purchase_repository.dart';
import 'package:pasal_mobile/features/suppliers/data/save_key.dart';
import 'package:pasal_mobile/features/suppliers/data/supplier_repository.dart';
import 'package:pasal_mobile/features/suppliers/presentation/supplier_widgets.dart';

/// F4d. One bill: the supplier, the items, the totals, the payments made, and a button to pay the bill.
class PurchaseDetailsScreen extends ConsumerWidget {
  const PurchaseDetailsScreen({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(purchaseProvider(id));
    final purchase = data.value;

    return PageScaffold(
      title: context.tr('Purchase details', 'खरिद विवरण'),
      onRefresh: () async => ref.invalidate(purchaseProvider(id)),
      body: purchase != null
          ? _PurchaseBody(purchase: purchase)
          : data.hasError
              ? ErrorView(error: data.error!, onRetry: () => ref.invalidate(purchaseProvider(id)))
              : const SkeletonList(),
    );
  }
}

class _PurchaseBody extends ConsumerWidget {
  const _PurchaseBody({required this.purchase});

  final Purchase purchase;

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final bill = purchase;
    final left = await showPasalSheet<int>(
      context,
      title: context.tr('Pay supplier for this bill', 'यो बिलको भुक्तानी'),
      builder: (ctx) => _PayBillSheet(purchase: bill),
    );
    if (left == null || !context.mounted) return;
    ref.invalidate(purchaseProvider(bill.id));
    ref.invalidate(purchasePageProvider);
    ref.invalidate(purchaseSummaryProvider);
    ref.invalidate(suppliersProvider);
    ref.invalidate(supplierLedgerProvider(bill.supplierId));
    showToast(
      context,
      'Payment saved. We owe ${context.rs(left)} on this bill.',
      'भुक्तानी सेभ भयो। यो बिलमा हामीले ${context.rs(left)} तिर्नुपर्छ।',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = purchase;
    final lines = p.items ?? const <PurchaseLine>[];
    final payments = p.payments ?? const <Payment>[];
    final owes = p.balance > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.billNo == null ? context.tr('No bill number', 'बिल नम्बर छैन') : context.tr('Bill ${p.billNo}', 'बिल ${p.billNo}'),
                          style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: () => context.push('/suppliers/${p.supplierId}'),
                          child: Text(
                            p.supplier?.name ?? context.tr('Deleted supplier', 'हटाइएको डिलर'),
                            style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PBadge(
                    owes ? context.tr('We owe', 'हामीले तिर्ने') : context.tr('Paid', 'तिरेको'),
                    tone: owes ? Tone.warn : Tone.good,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              KeyValueRow(
                label: context.tr('Bill date', 'बिल मिति'),
                value: p.billDate == null ? context.tr('Not set', 'छैन') : formatDate(p.billDate!),
              ),
              KeyValueRow(label: context.tr('Bought on', 'खरिद मिति'), value: formatDate(p.boughtAt)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionHeading(context.tr('Items', 'सामान')),
        ListCard(
          children: [
            for (final line in lines)
              ListRow(
                leading: const IconTile(Icons.inventory_2_rounded, tone: Tone.info),
                title: line.itemName,
                subtitle: '${context.num(line.quantity)} × ${context.rs(line.unitCost)}',
                amount: context.rs(line.lineTotal),
                chevron: false,
              ),
          ],
        ),
        const SizedBox(height: 14),
        PCard(
          child: Column(
            children: [
              KeyValueRow(label: context.tr('Lines total', 'सामानको जम्मा'), value: context.rs(p.total - p.vatAmount)),
              KeyValueRow(label: context.tr('VAT', 'भ्याट'), value: context.rs(p.vatAmount)),
              KeyValueRow(label: context.tr('Total', 'जम्मा'), value: context.rs(p.total), strong: true),
              KeyValueRow(label: context.tr('Paid', 'तिरेको'), value: context.rs(p.paid), valueColor: context.colors.good),
              KeyValueRow(
                label: context.tr('Balance', 'बाँकी'),
                value: context.rs(p.balance),
                valueColor: owes ? context.colors.warn : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionHeading(context.tr('Payments', 'भुक्तानी')),
        if (payments.isEmpty)
          PCard(
            child: Text(
              context.tr('No payment yet', 'अहिलेसम्म कुनै भुक्तानी छैन'),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          )
        else
          ListCard(
            children: [
              for (final pm in payments)
                ListRow(
                  leading: const IconTile(Icons.call_made_rounded, tone: Tone.good),
                  title: context.rs(pm.amount),
                  subtitle: '${methodLabel(context, pm.method)} · ${formatDate(pm.paidAt)}',
                  chevron: false,
                ),
            ],
          ),
        if (owes) ...[
          const SizedBox(height: 16),
          PrimaryButton(
            label: context.tr('Pay supplier', 'डिलरलाई भुक्तानी'),
            icon: Icons.call_made_rounded,
            tone: context.colors.good,
            onPressed: () => _pay(context, ref),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/suppliers/${p.supplierId}'),
            icon: const Icon(Icons.storefront_rounded),
            label: Text(context.tr('Supplier ledger', 'डिलर खाता')),
          ),
        ),
      ],
    );
  }
}

/// Pays one bill. Pops with the paisa still owed on the bill when the payment is saved.
class _PayBillSheet extends ConsumerStatefulWidget {
  const _PayBillSheet({required this.purchase});

  final Purchase purchase;

  @override
  ConsumerState<_PayBillSheet> createState() => _PayBillSheetState();
}

class _PayBillSheetState extends ConsumerState<_PayBillSheet> {
  late String _amount = fromPaisa(widget.purchase.balance);
  String _method = 'cash';
  bool _busy = false;
  ApiException? _error;
  final _saveKey = SaveKey();

  Future<void> _save() async {
    final amount = toPaisa(_amount);
    if (_busy || amount == null || amount <= 0) return;
    final bill = widget.purchase;
    final method = _method;
    setState(() {
      _busy = true;
      _error = null;
    });
    final key = _saveKey.forBody(jsonEncode({'purchase_id': bill.id, 'amount': amount, 'method': method}));
    final left = await guard(
      () => ref.read(purchaseRepositoryProvider).payBill(purchaseId: bill.id, amount: amount, method: method, key: key),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (left == null) return;
    _saveKey.reset();
    Navigator.of(context).pop(left);
  }

  @override
  Widget build(BuildContext context) {
    final amount = toPaisa(_amount);
    final canSave = !_busy && amount != null && amount > 0;
    final error = _error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AmountPad(value: _amount, onChanged: (v) => setState(() => _amount = v)),
        const SizedBox(height: 8),
        PaymentMethodPicker(value: _method, onChanged: (v) => setState(() => _method = v)),
        if (error != null) ...[
          const SizedBox(height: 12),
          AlertBox(error.field('amount') ?? error.message),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save payment', 'सेभ गर्ने'),
          icon: Icons.check_rounded,
          tone: context.colors.good,
          busy: _busy,
          onPressed: canSave ? _save : null,
        ),
      ],
    );
  }
}
