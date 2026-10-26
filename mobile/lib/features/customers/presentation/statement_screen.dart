import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/launch.dart';
import 'package:pasal_mobile/core/widgets/bs_date.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/customers/data/customer_repository.dart';
import 'package:pasal_mobile/features/customers/data/ledger_entries.dart';
import 'package:pasal_mobile/features/customers/data/statement.dart';
import 'package:pasal_mobile/features/customers/data/statement_range.dart';
import 'package:pasal_mobile/features/customers/presentation/customer_widgets.dart';

/// Statement (website E6). Bills and payments for a period, with a running balance.
/// The phone has no PDF or print. The Share button sends the statement as plain text.
class StatementScreen extends ConsumerWidget {
  const StatementScreen({required this.customerId, super.key});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerLedgerProvider(customerId));
    return PageScaffold(
      title: context.tr('Statement', 'हिसाब विवरण'),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(customerLedgerProvider(customerId)),
        data: (l) => _StatementBody(ledger: l),
      ),
    );
  }
}

class _StatementBody extends ConsumerStatefulWidget {
  const _StatementBody({required this.ledger});

  final CustomerLedger ledger;

  @override
  ConsumerState<_StatementBody> createState() => _StatementBodyState();
}

class _StatementBodyState extends ConsumerState<_StatementBody> {
  late String _from;
  late String _to;

  static const _presetLabels = {
    StatementPreset.month: ('This month', 'यो महिना'),
    StatementPreset.last: ('Last month', 'अघिल्लो महिना'),
    StatementPreset.three: ('Last 3 months', 'पछिल्ला ३ महिना'),
    StatementPreset.year: ('This year', 'यो वर्ष'),
    StatementPreset.all: ('All', 'सबै'),
  };

  @override
  void initState() {
    super.initState();
    final range = statementRange(StatementPreset.month, earliest: earliestDay(widget.ledger));
    _from = range.from;
    _to = range.to;
  }

  void _usePreset(StatementPreset preset) {
    final range = statementRange(preset, earliest: earliestDay(widget.ledger));
    setState(() {
      _from = range.from;
      _to = range.to;
    });
  }

  /// The preset whose days match the picked range, or null after a manual change.
  StatementPreset? _activePreset() {
    final earliest = earliestDay(widget.ledger);
    for (final p in StatementPreset.values) {
      final range = statementRange(p, earliest: earliest);
      if (range.from == _from && range.to == _to) return p;
    }
    return null;
  }

  Future<void> _share(Statement s, String shop) async {
    await shareText(_shareText(s, shop), subject: context.tr('Statement for ${widget.ledger.customer.name}', '${widget.ledger.customer.name}को हिसाब विवरण'));
  }

  String _shareText(Statement s, String shop) {
    final name = widget.ledger.customer.name;
    final phone = widget.ledger.customer.phone?.trim() ?? '';
    final lines = <String>[
      shop,
      context.tr('Statement for $name', '$nameको हिसाब विवरण'),
      if (phone.isNotEmpty) phone,
      context.tr('${formatDate(_from)} to ${formatDate(_to)}', '${formatDate(_from)} देखि ${formatDate(_to)} सम्म'),
      '',
      '${context.tr('Opening balance', 'शुरु बाँकी')}: ${context.rs(s.opening)}',
      for (final r in s.rows)
        '${formatDate(r.entry.day)}, ${entryDetail(context, r.entry)}, '
            '${r.entry.kind == EntryKind.received ? context.tr('received', 'पाइयो') : context.tr('given', 'दिइयो')} '
            '${context.rs(r.entry.kind == EntryKind.received ? r.entry.amount : r.entry.netAmount)}, '
            '${context.tr('balance', 'बाँकी')} ${context.rs(r.balance)}',
      '',
      '${context.tr('Total given', 'जम्मा दिइएको')}: ${context.rs(s.totalGiven)}',
      '${context.tr('Total received', 'जम्मा पाइएको')}: ${context.rs(s.totalReceived)}',
      '${context.tr('Closing balance', 'बन्द बाँकी')}: ${context.rs(s.closing)}',
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.ledger;
    final business = ref.watch(sessionProvider).business;
    final shop = business?.name ?? 'PASAL';
    final statement = buildStatement(l, from: _from, to: _to);
    final badRange = _from.compareTo(_to) > 0;
    final active = _activePreset();
    final customer = l.customer;
    final phone = customer.phone?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in StatementPreset.values)
              ChoiceChip(
                label: Text(context.tr(_presetLabels[p]!.$1, _presetLabels[p]!.$2)),
                selected: active == p,
                showCheckmark: false,
                onSelected: (_) => _usePreset(p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: BsDateField(
                label: context.tr('From', 'देखि'),
                value: _from,
                max: _to,
                onChanged: (v) => setState(() => _from = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BsDateField(
                label: context.tr('To', 'सम्म'),
                value: _to,
                min: _from,
                onChanged: (v) => setState(() => _to = v),
              ),
            ),
          ],
        ),
        if (badRange) ...[
          const SizedBox(height: 12),
          AlertBox(context.tr('The start date is after the end date.', 'सुरु मिति अन्तिम मितिभन्दा पछि छ।')),
        ],
        const SizedBox(height: 16),
        PCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shop, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (business?.pan != null) Text('PAN ${business!.pan}', style: _small(context)),
              if (business?.address != null || business?.phone != null)
                Text(
                  [business?.address, business?.phone].whereType<String>().where((t) => t.isNotEmpty).join(' · '),
                  style: _small(context),
                ),
              const Divider(height: 24),
              Text(context.tr('Customer', 'ग्राहक'), style: _small(context)),
              Text(
                phone.isEmpty ? customer.name : '${customer.name}  $phone',
                style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (customer.pan != null) Text('PAN ${customer.pan}', style: _small(context)),
              const SizedBox(height: 4),
              Text(
                context.tr('${formatDate(_from)} to ${formatDate(_to)}', '${formatDate(_from)} देखि ${formatDate(_to)} सम्म'),
                style: _small(context),
              ),
            ],
          ),
        ),
        if (statement.truncated) ...[
          const SizedBox(height: 12),
          AlertBox(
            context.tr(
              'This shows only the latest 200 bills or payments. Older records may be missing, so the opening balance may be wrong.',
              'यहाँ पछिल्ला २०० बिल वा भुक्तानी मात्र देखिन्छ। पुराना रेकर्ड नहुन सक्छ, त्यसैले शुरु बाँकी गलत हुन सक्छ।',
            ),
            tone: Tone.warn,
            icon: Icons.warning_amber_rounded,
          ),
        ],
        const SizedBox(height: 12),
        PCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${context.tr('Opening balance', 'शुरु बाँकी')} (${formatDate(_from)})',
                  style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(context.rs(statement.opening), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (statement.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.tr('No bills or payments in this period.', 'यो अवधिमा बिल वा भुक्तानी छैन।'),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          )
        else
          ListCard(children: [for (final r in statement.rows) _line(context, r)]),
        const SizedBox(height: 8),
        PCard(
          child: Column(
            children: [
              _totalRow(context, context.tr('Total', 'जम्मा'), context.rs(statement.totalGiven), context.tr('Total received', 'जम्मा पाइएको'), context.rs(statement.totalReceived)),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Closing balance', 'बन्द बाँकी'),
                      style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    context.rs(statement.closing),
                    style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: context.colors.warn),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('Returns are taken off on the day of the bill.', 'फिर्ता बिलको मितिमा घटाइन्छ।'),
          style: _small(context),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _share(statement, shop),
          icon: const Icon(Icons.share_rounded),
          label: Text(context.tr('Share', 'साझा गर्ने')),
        ),
      ],
    );
  }

  TextStyle? _small(BuildContext context) => context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant);

  Widget _totalRow(BuildContext context, String givenLabel, String given, String receivedLabel, String received) {
    return Row(
      children: [
        Expanded(child: Text(givenLabel, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
        Text(given, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: context.colors.warn)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(receivedLabel, textAlign: TextAlign.end, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
        ),
        const SizedBox(width: 6),
        Text(received, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: context.colors.good)),
      ],
    );
  }

  Widget _line(BuildContext context, StatementRow r) {
    final e = r.entry;
    final received = e.kind == EntryKind.received;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDate(e.day), style: _small(context)),
                Text(entryDetail(context, e), style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                received ? context.rs(e.amount) : context.rs(e.netAmount),
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: received ? context.colors.good : context.colors.warn,
                ),
              ),
              Text('${context.tr('Balance', 'बाँकी')} ${context.rs(r.balance)}', style: _small(context)),
            ],
          ),
        ],
      ),
    );
  }
}
