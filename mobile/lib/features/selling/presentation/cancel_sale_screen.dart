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

/// Owner only (/sales/:id/cancel). Every item still with the customer comes back in one step.
class CancelSaleScreen extends ConsumerWidget {
  const CancelSaleScreen({required this.saleId, super.key});

  final int saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = ref.watch(saleProvider(saleId));
    return AsyncBody<Sale>(
      value: sale,
      onRetry: () => ref.invalidate(saleProvider(saleId)),
      data: (s) => _CancelForm(sale: s),
    );
  }
}

class _CancelForm extends ConsumerStatefulWidget {
  const _CancelForm({required this.sale});

  final Sale sale;

  @override
  ConsumerState<_CancelForm> createState() => _CancelFormState();
}

class _CancelFormState extends ConsumerState<_CancelForm> {
  final _reason = TextEditingController();
  bool _restock = true;
  bool _understood = false;
  bool _busy = false;
  ApiException? _error;
  String _key = newKey();
  String _keyBody = '';

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _cancelSale(Sale sale) async {
    final body = <String, Object?>{'restock': _restock, 'note': _reason.text.trim()};
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
      await repo.cancelSale(sale.id, body, _key);
      if (!mounted) return;
      _key = newKey();
      _keyBody = '';
      showToast(context, 'Sale cancelled', 'बिक्री रद्द भयो');
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
    final stillWith = lines.fold<int>(0, (sum, l) => sum + (l.quantity - l.returnedQuantity));
    final goodsValue = lines.fold<int>(
      0,
      (sum, l) => sum + returnValue(l.quantity - l.returnedQuantity, l.lineTotal, l.quantity),
    );
    final cashBack = returnPreview(goodsValue, sale.balance).cashBack;
    final reasonEmpty = _reason.text.trim().isEmpty;
    final blocked = reasonEmpty || !_understood || _busy || sale.isCancelled;
    final error = _error;

    return PageScaffold(
      title: context.tr('Cancel sale', 'बिक्री रद्द'),
      bottom: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.canPop() ? context.pop() : context.go('/sales/${sale.id}'),
              child: Text(context.tr('Keep sale', 'बिक्री राख्ने')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: _busy ? context.tr('Cancelling…', 'रद्द हुँदैछ…') : context.tr('Cancel sale', 'बिक्री रद्द गर्ने'),
              icon: Icons.cancel_rounded,
              busy: _busy,
              tone: context.colors.bad,
              onPressed: blocked ? null : () => _cancelSale(sale),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeroCard(
            tone: Tone.bad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 40, color: context.colors.bad),
                const SizedBox(height: 10),
                Text(
                  context.tr(
                    'Cancel bill ${sale.billNo ?? '#${sale.id}'}?',
                    'बिल ${sale.billNo ?? '#${sale.id}'} रद्द गर्ने?',
                  ),
                  style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('Here is what happens when you cancel:', 'रद्द गर्दा यी कुरा हुन्छन्:'),
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
          if (sale.isCancelled) ...[
            const SizedBox(height: 12),
            AlertBox(context.tr('This sale is already cancelled.', 'यो बिक्री पहिले नै रद्द भएको छ।')),
          ],
          const SizedBox(height: 12),
          AlertBox(
            context.tr('Every item still with the customer is returned in one step.', 'ग्राहकसँग भएका सबै सामान एकै पटक फिर्ता हुन्छन्।'),
            tone: Tone.warn,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 12),
          MoneyRows([
            MoneyRow(context.tr('Items coming back', 'फिर्ता आउने सामान'), context.num(stillWith)),
            MoneyRow(context.tr('Value of these items', 'यी सामानको मूल्य'), context.rs(goodsValue)),
            MoneyRow(
              context.tr('Cash to give back', 'नगद फिर्ता दिनु पर्ने'),
              context.rs(cashBack),
              tone: cashBack > 0 ? Tone.warn : null,
            ),
          ]),
          const SizedBox(height: 12),
          PField(
            label: context.tr('Reason (required)', 'कारण (अनिवार्य)'),
            controller: _reason,
            hint: context.tr('Why cancel this bill?', 'किन यो बिल रद्द गर्दै हुनुहुन्छ?'),
            error: error?.field('note'),
            helper: reasonEmpty ? context.tr('Please write a reason.', 'कारण लेख्नुहोस्।') : null,
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
          PCard(
            child: Row(
              children: [
                Expanded(child: Text(context.tr('I understand. This cannot be undone.', 'मैले बुझें। यो फिर्ता हुँदैन।'), style: context.text.bodyLarge)),
                Switch(value: _understood, onChanged: (v) => setState(() => _understood = v)),
              ],
            ),
          ),
          if (error != null && error.field('note') == null) ...[
            const SizedBox(height: 12),
            AlertBox(error.message),
          ],
        ],
      ),
    );
  }
}
