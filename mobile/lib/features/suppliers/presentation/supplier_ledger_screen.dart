import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/launch.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/suppliers/data/purchase_math.dart';
import 'package:pasal_mobile/features/suppliers/data/supplier_repository.dart';
import 'package:pasal_mobile/features/suppliers/presentation/supplier_widgets.dart';

/// F2. One supplier's ledger: what we owe, the quick actions, and every bill and payment by day.
class SupplierLedgerScreen extends ConsumerWidget {
  const SupplierLedgerScreen({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(supplierLedgerProvider(id));
    final ledger = data.value;

    return PageScaffold(
      title: ledger?.supplier.name ?? context.tr('Supplier ledger', 'डिलर खाता'),
      onRefresh: () async => ref.invalidate(supplierLedgerProvider(id)),
      body: ledger != null
          ? _LedgerBody(id: id, ledger: ledger)
          : data.hasError
              ? ErrorView(error: data.error!, onRetry: () => ref.invalidate(supplierLedgerProvider(id)))
              : const SkeletonList(),
    );
  }
}

class _LedgerBody extends StatelessWidget {
  const _LedgerBody({required this.id, required this.ledger});

  final int id;
  final SupplierLedger ledger;

  @override
  Widget build(BuildContext context) {
    final supplier = ledger.supplier;
    final open = openBillsOldestFirst(ledger.purchases);
    final oldest = open.isEmpty ? null : open.first;
    final entries = _timeline(ledger);
    final timeline = <Widget>[
      for (final day in _groupByDay(entries).entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Text(formatDate(day.key), style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        ),
        for (final e in day.value)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _EntryCard(entry: e),
          ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          tone: Tone.info,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatBlock(
                  large: true,
                  tone: Tone.info,
                  label: context.tr('We owe ${supplier.name}', '${supplier.name} लाई हामीले तिर्ने'),
                  value: context.rs(ledger.weOwe),
                  sub: oldest == null
                      ? context.tr('No open bills', 'कुनै बिल बाँकी छैन')
                      : context.tr(
                          'Oldest open bill is ${context.num(daysAgo(oldest.boughtAt))} days old',
                          'सबैभन्दा पुरानो खुला बिल ${context.num(daysAgo(oldest.boughtAt))} दिन अघिको',
                        ),
                ),
              ),
              const SizedBox(width: 12),
              AvatarCircle(supplier.name, tone: Tone.info, size: 52),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: QuickActionTile(
                icon: Icons.call_rounded,
                label: context.tr('Call', 'फोन'),
                onTap: supplier.phone == null ? null : () => callPhone(context, supplier.phone!),
              ),
            ),
            Expanded(
              child: QuickActionTile(
                icon: Icons.shopping_bag_rounded,
                label: context.tr('New purchase', 'नयाँ खरिद'),
                onTap: () => context.push('/purchases/new?supplier=$id'),
              ),
            ),
            Expanded(
              child: QuickActionTile(
                icon: Icons.call_made_rounded,
                label: context.tr('Pay supplier', 'डिलरलाई भुक्तानी'),
                onTap: () => context.push('/suppliers/$id/pay'),
              ),
            ),
            Expanded(
              child: QuickActionTile(
                icon: Icons.edit_rounded,
                label: context.tr('Edit', 'सच्याउने'),
                onTap: () => context.push('/suppliers/$id/edit'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: PCard(
                child: StatBlock(label: context.tr('Total bought', 'जम्मा खरिद'), value: context.rs(ledger.totalPurchases)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PCard(
                child: StatBlock(label: context.tr('Total paid', 'जम्मा तिरेको'), value: context.rs(ledger.totalPaid), tone: Tone.good),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          SizedBox(
            height: 320,
            child: EmptyState(
              icon: Icons.receipt_long_rounded,
              title: context.tr('No purchases yet', 'अहिलेसम्म खरिद छैन'),
              text: context.tr('Buy stock from this supplier to start the ledger.', 'यो डिलरबाट सामान किनेर खाता सुरु गर्नुहोस्।'),
              actionLabel: context.tr('New purchase', 'नयाँ खरिद'),
              onAction: () => context.push('/purchases/new?supplier=$id'),
            ),
          )
        else
          ...timeline,
      ],
    );
  }
}

/// One line of the ledger: a bill we bought, or a payment we made.
class _Entry {
  const _Entry({
    required this.at,
    required this.bought,
    required this.amount,
    this.purchaseId,
    this.bill,
    this.balance = 0,
    this.method = '',
  });

  final String at;
  final bool bought;
  final int amount;
  final int? purchaseId;
  final String? bill;

  /// Still to pay on a bought bill.
  final int balance;
  final String method;
}

List<_Entry> _timeline(SupplierLedger ledger) {
  final bills = {for (final p in ledger.purchases) p.id: p.billNo};
  final entries = [
    for (final p in ledger.purchases)
      _Entry(at: p.boughtAt, bought: true, amount: p.total, purchaseId: p.id, bill: p.billNo, balance: p.balance),
    for (final p in ledger.payments)
      _Entry(
        at: p.paidAt,
        bought: false,
        amount: p.amount,
        purchaseId: p.purchaseId,
        bill: p.purchaseId == null ? null : bills[p.purchaseId],
        method: p.method,
      ),
  ];
  entries.sort((a, b) => DateTime.parse(b.at).compareTo(DateTime.parse(a.at)));
  return entries;
}

/// Entries grouped by their AD day, newest day first (the list is already sorted).
Map<String, List<_Entry>> _groupByDay(List<_Entry> entries) {
  final groups = <String, List<_Entry>>{};
  for (final e in entries) {
    groups.putIfAbsent(adOfStamp(e.at), () => []).add(e);
  }
  return groups;
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final bill = entry.bill;
    final bought = entry.bought;
    final method = methodLabel(context, entry.method);
    final title = bought
        ? (bill == null ? context.tr('Bought', 'खरिद') : context.tr('Bought (bill $bill)', 'खरिद (बिल $bill)'))
        : context.tr('Paid · $method', 'भुक्तानी · $method');
    final sub = bought
        ? (entry.balance > 0
            ? context.tr('Still to pay ${context.rs(entry.balance)}', 'बाँकी ${context.rs(entry.balance)}')
            : context.tr('Paid in full', 'पूरा तिरेको'))
        : (bill == null ? null : context.tr('For $bill', '$bill को लागि'));

    return PCard(
      onTap: entry.purchaseId == null ? null : () => context.push('/purchases/${entry.purchaseId}'),
      child: Row(
        children: [
          IconTile(
            bought ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            tone: bought ? Tone.warn : Tone.good,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (sub != null) Text(sub, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(context.rs(entry.amount), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
