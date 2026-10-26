import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/selling/data/cart.dart';
import 'package:pasal_mobile/features/selling/data/selling_repository.dart';
import 'package:pasal_mobile/features/selling/presentation/selling_widgets.dart';

/// Owner only (/sales/:id/return). Pick the goods that come back, then save the return.
class SaleReturnScreen extends ConsumerWidget {
  const SaleReturnScreen({required this.saleId, super.key});

  final int saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = ref.watch(saleProvider(saleId));
    return AsyncBody<Sale>(
      value: sale,
      onRetry: () => ref.invalidate(saleProvider(saleId)),
      data: (s) => _ReturnForm(sale: s),
    );
  }
}

class _ReturnForm extends ConsumerStatefulWidget {
  const _ReturnForm({required this.sale});

  final Sale sale;

  @override
  ConsumerState<_ReturnForm> createState() => _ReturnFormState();
}

class _ReturnFormState extends ConsumerState<_ReturnForm> {
  final _note = TextEditingController();
  final Map<int, int> _picked = {};
  bool _restock = true;
  bool _busy = false;
  ApiException? _error;
  String _key = newKey();
  String _keyBody = '';

  static const _reasons = [
    ('Damaged', 'बिग्रिएको'),
    ('Wrong item', 'गलत सामान'),
    ('Customer changed mind', 'ग्राहकले मन बदले'),
    ('Expired', 'म्याद सकियो'),
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int _returnable(SaleLine line) => line.quantity - line.returnedQuantity;

  int _qty(SaleLine line) {
    final picked = _picked[line.id] ?? 0;
    final max = _returnable(line);
    return picked > max ? max : picked;
  }

  void _set(SaleLine line, int qty) {
    final max = _returnable(line);
    setState(() => _picked[line.id] = qty < 0 ? 0 : (qty > max ? max : qty));
  }

  Future<void> _save(Sale sale) async {
    final lines = sale.items ?? const <SaleLine>[];
    final note = _note.text.trim();
    final body = <String, Object?>{
      'items': [
        for (final line in lines)
          if (_qty(line) > 0) {'sale_item_id': line.id, 'quantity': _qty(line)},
      ],
      'restock': _restock,
      if (note.isNotEmpty) 'note': note,
    };
    final text = jsonEncode(body);
    if (text != _keyBody) {
      _key = newKey();
      _keyBody = text;
    }
    final repo = ref.read(sellingRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await repo.returnItems(sale.id, body, _key);
      if (!mounted) return;
      _key = newKey();
      _keyBody = '';
      showToast(
        context,
        'Return saved. Refunded ${context.rs(res.refunded)}. Balance ${context.rs(res.saleBalance)}.',
        'फिर्ता सेभ भयो। ${context.rs(res.refunded)} फिर्ता। बाँकी ${context.rs(res.saleBalance)}।',
      );
      ref.invalidate(saleProvider(sale.id));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/sales/${sale.id}');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final lines = sale.items ?? const <SaleLine>[];
    final count = lines.fold<int>(0, (sum, l) => sum + _qty(l));
    final value = lines.fold<int>(0, (sum, l) => sum + returnValue(_qty(l), l.lineTotal, l.quantity));
    final split = returnPreview(value, sale.balance);
    final blocked = count == 0 || _busy || sale.isCancelled;
    final error = _error;
    final general = error != null && error.field('note') == null ? error.message : null;

    return PageScaffold(
      title: context.tr('Sale return', 'बिक्री फिर्ता'),
      bottom: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.canPop() ? context.pop() : context.go('/sales/${sale.id}'),
              child: Text(context.tr('Back', 'फर्कनुहोस्')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save return', 'फिर्ता सेभ गर्ने'),
              icon: Icons.check_rounded,
              busy: _busy,
              onPressed: blocked ? null : () => _save(sale),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr('Bill', 'बिल')} ${sale.billNo ?? '#${sale.id}'}',
                        style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                      ),
                      Text(
                        sale.customer?.name ?? context.tr('Walk-in customer', 'पसलमा आएका ग्राहक'),
                        style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                if (sale.balance > 0)
                  PBadge(context.tr('Credit', 'उधारो'), tone: Tone.warn)
                else
                  PBadge(context.tr('Paid', 'तिरेको'), tone: Tone.good),
              ],
            ),
          ),
          if (sale.isCancelled) ...[
            const SizedBox(height: 12),
            AlertBox(context.tr('This sale is cancelled. Nothing is left to return.', 'यो बिक्री रद्द भएको छ। फिर्ता गर्ने सामान छैन।')),
          ],
          SectionTitle(context.tr('Items to return', 'फिर्ता दिने सामान')),
          ListCard(
            children: [
              for (final line in lines)
                _ReturnRow(
                  line: line,
                  qty: _qty(line),
                  max: _returnable(line),
                  onQty: (q) => _set(line, q),
                ),
            ],
          ),
          SectionTitle(context.tr('Reason', 'कारण')),
          ChipsRow<String>(
            value: _note.text,
            options: {for (final r in _reasons) r.$1: context.tr(r.$1, r.$2)},
            onChanged: (v) => setState(() => _note.text = v),
          ),
          const SizedBox(height: 12),
          PField(
            label: context.tr('Note (optional)', 'नोट (ऐच्छिक)'),
            controller: _note,
            error: error?.field('note'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          PCard(
            child: Row(
              children: [
                Expanded(child: Text(context.tr('Put returned items back in stock', 'फिर्ता सामान स्टकमा राख्ने'), style: context.text.bodyLarge)),
                Switch(value: _restock, onChanged: (v) => setState(() => _restock = v)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MoneyRows([
            MoneyRow(context.tr('Items returned', 'फिर्ता सामान'), context.num(count)),
            MoneyRow(context.tr('Refund value', 'फिर्ता रकम'), context.rs(value), bold: true),
            MoneyRow(context.tr('Debt taken off', 'उधारोबाट घटाइने'), context.rs(split.debtDown)),
            MoneyRow(
              context.tr('Cash to give back', 'नगद फिर्ता दिनु पर्ने'),
              context.rs(split.cashBack),
              tone: split.cashBack > 0 ? Tone.warn : null,
            ),
            MoneyRow(context.tr('Credit left after return', 'फिर्ता पछिको उधारो'), context.rs(split.balanceAfter)),
          ]),
          const SizedBox(height: 12),
          AlertBox(
            _restock
                ? context.tr('Stock goes back up for returned items', 'फिर्ता सामानको स्टक फेरि बढ्छ')
                : context.tr('Returned items will not go back on the shelf', 'फिर्ता सामान स्टकमा फर्किने छैन'),
            tone: Tone.info,
            icon: _restock ? Icons.inventory_2_rounded : Icons.block_rounded,
          ),
          if (general != null) ...[
            const SizedBox(height: 12),
            AlertBox(general),
          ],
        ],
      ),
    );
  }
}

class _ReturnRow extends StatelessWidget {
  const _ReturnRow({required this.line, required this.qty, required this.max, required this.onQty});

  final SaleLine line;
  final int qty;
  final int max;
  final ValueChanged<int> onQty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.itemName, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  max > 0
                      ? '${context.tr('Sold', 'बिक्री')} ${context.num(line.quantity)} · ${context.rs(line.unitPrice)}'
                      : context.tr('Already returned', 'पहिले नै फिर्ता भयो'),
                  style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          QtyStepper(
            value: qty,
            onLess: qty <= 0 ? null : () => onQty(qty - 1),
            onMore: qty >= max ? null : () => onQty(qty + 1),
          ),
        ],
      ),
    );
  }
}
