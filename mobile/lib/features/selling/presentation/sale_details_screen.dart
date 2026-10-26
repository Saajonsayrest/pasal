import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/features/selling/data/selling_repository.dart';
import 'package:pasal_mobile/features/selling/presentation/selling_widgets.dart';

/// One sale: items, money, payments and returns (/sales/:id). Owners can return or cancel.
class SaleDetailsScreen extends ConsumerWidget {
  const SaleDetailsScreen({required this.saleId, super.key});

  final int saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = ref.watch(saleProvider(saleId));
    final isOwner = ref.watch(sessionProvider).isOwner;
    return PageScaffold(
      title: context.tr('Sale details', 'बिक्री विवरण'),
      body: AsyncBody<Sale>(
        value: sale,
        onRetry: () => ref.invalidate(saleProvider(saleId)),
        data: (s) => _Details(sale: s, isOwner: isOwner),
      ),
    );
  }
}

const _methodNames = {
  'cash': ('Cash', 'नगद'),
  'qr': ('QR', 'QR'),
  'bank': ('Bank', 'बैंक'),
  'card': ('Card', 'कार्ड'),
  'esewa': ('eSewa', 'eSewa'),
  'khalti': ('Khalti', 'Khalti'),
};

class _Details extends ConsumerWidget {
  const _Details({required this.sale, required this.isOwner});

  final Sale sale;
  final bool isOwner;

  Future<void> _openPage(BuildContext context, WidgetRef ref, String path) async {
    await context.push(path);
    if (context.mounted) ref.invalidate(saleProvider(sale.id));
  }

  Future<void> _takePayment(BuildContext context, WidgetRef ref) async {
    final paid = await showPasalSheet<bool>(
      context,
      title: context.tr('Take payment', 'पैसा लिने'),
      builder: (_) => TakePaymentSheet(sale: sale),
    );
    if (paid == true && context.mounted) ref.invalidate(saleProvider(sale.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = saleStatus(context, sale);
    final customer = sale.customer;
    final cancelled = sale.isCancelled;
    final lines = sale.items ?? const <SaleLine>[];
    final payments = sale.payments ?? const <Payment>[];
    final returns = sale.returns ?? const <SaleReturn>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          customer?.name ?? context.tr('Walk-in customer', 'पसलमा आएका ग्राहक'),
                          style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  PBadge(status.text, tone: status.tone),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${context.tr('Sold by', 'बेच्ने')} ${sale.soldBy ?? context.tr('Not known', 'थाहा छैन')} · ${formatTime(sale.soldAt)} · ${formatDate(sale.soldAt)}',
                style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
              if (customer != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.push('/customers/${customer.id}'),
                    child: Text(context.tr('Open customer', 'ग्राहक हेर्ने')),
                  ),
                ),
            ],
          ),
        ),
        if (cancelled) ...[
          const SizedBox(height: 12),
          AlertBox(
            context.tr('This bill is cancelled. Nothing more can be paid or returned.', 'यो बिल रद्द भएको छ। अब भुक्तानी वा फिर्ता हुँदैन।'),
            icon: Icons.cancel_rounded,
          ),
        ],
        SectionTitle(context.tr('Items', 'सामान')),
        ListCard(
          children: [
            for (final line in lines)
              ListRow(
                leading: const IconTile(Icons.inventory_2_rounded, size: 40),
                title: line.itemName,
                subtitle: [
                  '${context.num(line.quantity)} × ${context.rs(line.unitPrice)}',
                  if (line.returnedQuantity > 0)
                    '${context.num(line.returnedQuantity)} ${context.tr('returned', 'फिर्ता')}',
                ].join(' · '),
                amount: context.rs(line.lineTotal),
                chevron: false,
              ),
          ],
        ),
        const SizedBox(height: 12),
        MoneyRows([
          MoneyRow(context.tr('Subtotal', 'उप-जम्मा'), context.rs(sale.subtotal)),
          if (sale.discount > 0) MoneyRow(context.tr('Discount', 'छुट'), context.rs(sale.discount)),
          MoneyRow(context.tr('Total', 'जम्मा'), context.rs(sale.total), bold: true),
          if (sale.returnedTotal > 0) MoneyRow(context.tr('Returned goods', 'फिर्ता सामान'), context.rs(sale.returnedTotal)),
          MoneyRow(context.tr('Paid', 'तिरेको'), context.rs(sale.paid), tone: Tone.good),
          MoneyRow(
            context.tr('Balance on credit', 'उधारो बाँकी'),
            context.rs(sale.balance),
            tone: sale.balance > 0 ? Tone.warn : null,
          ),
        ]),
        SectionTitle(context.tr('Payments', 'भुक्तानी')),
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
              for (final p in payments)
                ListRow(
                  leading: IconTile(
                    p.direction == 'refund' ? Icons.undo_rounded : Icons.call_received_rounded,
                    tone: p.direction == 'refund' ? Tone.warn : Tone.good,
                    size: 40,
                  ),
                  title: '${p.direction == 'refund' ? context.tr('Given back', 'फिर्ता दिइयो') : context.tr('Received', 'प्राप्त')} · ${_methodLabel(context, p.method)}',
                  subtitle: '${formatDate(p.paidAt)} · ${formatTime(p.paidAt)}',
                  amount: context.rs(p.direction == 'refund' ? -p.amount : p.amount),
                  amountTone: p.direction == 'refund' ? Tone.warn : Tone.good,
                  chevron: false,
                ),
            ],
          ),
        if (returns.isNotEmpty) ...[
          SectionTitle(context.tr('Returns', 'फिर्ता')),
          ListCard(
            children: [
              for (final r in returns)
                ListRow(
                  leading: const IconTile(Icons.undo_rounded, tone: Tone.info, size: 40),
                  title: r.kind == 'cancel' ? context.tr('Sale cancelled', 'बिक्री रद्द') : context.tr('Items returned', 'सामान फिर्ता'),
                  subtitle: [
                    formatDate(r.returnedAt),
                    if (!r.restocked) context.tr('not put back in stock', 'स्टकमा फर्किएन'),
                    if (r.note != null) r.note!,
                    '${context.tr('Refunded', 'फिर्ता रकम')} ${context.rs(r.refunded)}',
                  ].join(' · '),
                  amount: context.rs(r.total),
                  chevron: false,
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (!cancelled && sale.balance > 0) ...[
          PrimaryButton(
            label: context.tr('Take payment', 'पैसा लिने'),
            icon: Icons.call_received_rounded,
            tone: context.colors.good,
            onPressed: () => _takePayment(context, ref),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/sales/${sale.id}/bill'),
                icon: const Icon(Icons.receipt_long_rounded),
                label: Text(context.tr('View bill', 'बिल हेर्ने')),
              ),
            ),
            if (isOwner && !cancelled) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openPage(context, ref, '/sales/${sale.id}/return'),
                  icon: const Icon(Icons.undo_rounded),
                  label: Text(context.tr('Return items', 'सामान फिर्ता')),
                ),
              ),
            ],
          ],
        ),
        if (isOwner && !cancelled) ...[
          const SizedBox(height: 10),
          PrimaryButton(
            label: context.tr('Cancel sale', 'बिक्री रद्द गर्ने'),
            icon: Icons.cancel_rounded,
            tone: context.colors.bad,
            onPressed: () => _openPage(context, ref, '/sales/${sale.id}/cancel'),
          ),
        ],
      ],
    );
  }
}

String _methodLabel(BuildContext context, String method) {
  final names = _methodNames[method];
  if (names == null) return method;
  return context.tr(names.$1, names.$2);
}
