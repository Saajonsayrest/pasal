import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/launch.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/customers/data/customer_repository.dart';
import 'package:pasal_mobile/features/customers/data/ledger_entries.dart';
import 'package:pasal_mobile/features/customers/presentation/customer_widgets.dart';

/// Customer ledger (website E2). What the customer owes, the credit limit, and bills and payments by day.
class CustomerLedgerScreen extends ConsumerStatefulWidget {
  const CustomerLedgerScreen({required this.customerId, super.key});

  final int customerId;

  @override
  ConsumerState<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  /// `all`, `given` or `received`.
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final id = widget.customerId;
    final async = ref.watch(customerLedgerProvider(id));
    final data = async.value;

    return PageScaffold(
      title: data?.customer.name ?? context.tr('Customer ledger', 'ग्राहक खाता'),
      actions: [
        IconButton(
          tooltip: context.tr('Edit customer', 'ग्राहक सच्याउने'),
          icon: const Icon(Icons.edit_rounded),
          onPressed: () => context.push('/customers/$id/edit'),
        ),
      ],
      bottom: data == null
          ? null
          : Row(
              children: [
                Expanded(
                  flex: 10,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/customers/$id/remind'),
                    icon: const Icon(Icons.chat_rounded),
                    label: Text(context.tr('Remind', 'सम्झाउने')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 14,
                  child: PrimaryButton(
                    label: context.tr('Take payment', 'भुक्तानी लिने'),
                    icon: Icons.call_received_rounded,
                    tone: context.colors.good,
                    onPressed: data.owes > 0 ? () => context.push('/customers/$id/payment') : null,
                  ),
                ),
              ],
            ),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(customerLedgerProvider(id)),
        data: (l) => _content(context, l),
      ),
    );
  }

  Widget _content(BuildContext context, CustomerLedger l) {
    final owes = l.owes;
    final limit = l.creditLimit;
    final overBy = limit == null || limit <= 0 || owes <= limit ? null : owes - limit;
    final phone = l.customer.phone?.trim() ?? '';
    final id = widget.customerId;

    final entries = customerEntries(l)..sort((a, b) => DateTime.parse(b.at).compareTo(DateTime.parse(a.at)));
    final shown = entries.where((e) {
      return switch (_filter) {
        'given' => e.kind != EntryKind.received,
        'received' => e.kind == EntryKind.received,
        _ => true,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          tone: Tone.warn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StatBlock(
                      large: true,
                      tone: Tone.warn,
                      label: context.tr('To collect', 'उठाउन बाँकी'),
                      value: context.rs(owes),
                      sub: _oldestLine(context, _oldestOpen(l)),
                    ),
                  ),
                  AvatarCircle(l.customer.name, tone: Tone.warn, size: 52),
                ],
              ),
              if (limit != null) ...[
                const SizedBox(height: 14),
                _LimitBar(owes: owes, limit: limit, over: overBy != null),
              ],
            ],
          ),
        ),
        if (overBy != null) ...[
          const SizedBox(height: 12),
          AlertBox(
            context.tr('Over the credit limit by ${context.rs(overBy)}.', 'उधारो सीमाभन्दा ${context.rs(overBy)} बढी छ।'),
            icon: Icons.warning_amber_rounded,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.call_rounded,
                label: context.tr('Call', 'फोन'),
                onTap: phone.isEmpty ? null : () => callPhone(context, phone),
              ),
            ),
            Expanded(
              child: _QuickAction(
                icon: Icons.notifications_active_rounded,
                label: context.tr('Remind', 'सम्झाउने'),
                onTap: () => context.push('/customers/$id/remind'),
              ),
            ),
            Expanded(
              child: _QuickAction(
                icon: Icons.receipt_long_rounded,
                label: context.tr('Statement', 'विवरण'),
                onTap: () => context.push('/customers/$id/statement'),
              ),
            ),
            Expanded(
              child: _QuickAction(
                icon: Icons.add_shopping_cart_rounded,
                label: context.tr('Credit sale', 'उधारो बिक्री'),
                onTap: () => context.go('/sell'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PCard(child: StatBlock(label: context.tr('Total bought', 'जम्मा किनेको'), value: context.rs(l.totalSales))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PCard(child: StatBlock(label: context.tr('Total paid', 'जम्मा तिरेको'), value: context.rs(l.totalPaid), tone: Tone.good)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Seg<String>(
          value: _filter,
          onChanged: (v) => setState(() => _filter = v),
          options: {
            'all': context.tr('All', 'सबै'),
            'given': context.tr('Given', 'दिइएको'),
            'received': context.tr('Received', 'पाइएको'),
          },
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          SizedBox(
            height: 320,
            child: EmptyState(
              icon: Icons.receipt_long_rounded,
              title: context.tr('No bills or payments yet', 'अहिलेसम्म बिल वा भुक्तानी छैन'),
              text: context.tr('Sell on credit to this customer and it shows here.', 'यो ग्राहकलाई उधारो बिक्री गर्दा यहाँ देखिन्छ।'),
            ),
          )
        else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.tr('Nothing in this filter.', 'यो छनोटमा केही छैन।'),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          )
        else
          ..._dayGroups(context, shown),
      ],
    );
  }

  List<Widget> _dayGroups(BuildContext context, List<LedgerEntry> shown) {
    final groups = <String, List<LedgerEntry>>{};
    for (final e in shown) {
      groups.putIfAbsent(e.day, () => []).add(e);
    }
    return [
      for (final group in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Text(
            dayLabel(context, group.key),
            style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
          ),
        ),
        ListCard(children: [for (final e in group.value) _entryRow(context, e)]),
      ],
    ];
  }

  Widget _entryRow(BuildContext context, LedgerEntry e) {
    final given = e.kind == EntryKind.given;
    final received = e.kind == EntryKind.received;
    final tone = given ? Tone.warn : (received ? Tone.good : Tone.info);
    final saleId = e.saleId;
    return ListRow(
      leading: IconTile(
        given ? Icons.arrow_upward_rounded : (received ? Icons.arrow_downward_rounded : Icons.undo_rounded),
        tone: tone,
        size: 40,
      ),
      title: entryTitle(context, e),
      subtitle: _subOf(context, e),
      amount: context.rs(e.amount),
      amountTone: tone,
      chevron: saleId != null,
      onTap: saleId == null ? null : () => context.push('/sales/$saleId'),
    );
  }

  String _subOf(BuildContext context, LedgerEntry e) {
    final parts = [
      e.billNo ?? '',
      formatTime(e.at),
      if (e.returned > 0) context.tr('${context.rs(e.returned)} returned', '${context.rs(e.returned)} फिर्ता'),
      if (e.cancelled) context.tr('Cancelled', 'रद्द'),
    ];
    return parts.where((p) => p.isNotEmpty).join(' · ');
  }

  LedgerSale? _oldestOpen(CustomerLedger l) {
    final open = l.sales.where((s) => s.balance > 0 && s.cancelledAt == null);
    if (open.isEmpty) return null;
    return open.reduce((a, b) => DateTime.parse(a.soldAt).isBefore(DateTime.parse(b.soldAt)) ? a : b);
  }

  String? _oldestLine(BuildContext context, LedgerSale? oldest) {
    if (oldest == null) return null;
    final days = -daysUntil(adOfStamp(oldest.soldAt));
    if (days <= 0) return context.tr('Oldest bill is from today', 'सबैभन्दा पुरानो बिल आजको हो');
    return context.tr(
      'Oldest bill is ${context.num(days)} ${context.plural(days, 'day', 'days')} old',
      'सबैभन्दा पुरानो बिल ${context.num(days)} दिन अघिको',
    );
  }
}

/// Owed amount against the credit limit. A limit of 0 means cash only.
class _LimitBar extends StatelessWidget {
  const _LimitBar({required this.owes, required this.limit, required this.over});

  final int owes;
  final int limit;
  final bool over;

  @override
  Widget build(BuildContext context) {
    if (limit == 0) {
      return Row(
        children: [
          Text(context.tr('Credit limit', 'उधारो सीमा'), style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant)),
          const Spacer(),
          Text(context.tr('Cash only', 'नगद मात्र'), style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      );
    }
    final percent = (owes * 100 ~/ limit).clamp(0, 100);
    final color = over ? context.colors.bad : context.colors.warn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(context.tr('Credit limit', 'उधारो सीमा'), style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${context.rs(owes)} / ${context.rs(limit)}',
                textAlign: TextAlign.end,
                style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 8,
            color: color,
            backgroundColor: context.scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: context.scheme.primaryContainer, borderRadius: BorderRadius.circular(Radii.md)),
                child: Icon(icon, color: context.scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
