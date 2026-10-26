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
import 'package:pasal_mobile/features/customers/data/allocation.dart';
import 'package:pasal_mobile/features/customers/data/customer_repository.dart';
import 'package:pasal_mobile/features/customers/data/payment_methods.dart';

/// Take payment (website E3). The amount pays the oldest bills first. The preview shows where the money goes.
class TakePaymentScreen extends ConsumerStatefulWidget {
  const TakePaymentScreen({required this.customerId, super.key});

  final int customerId;

  @override
  ConsumerState<TakePaymentScreen> createState() => _TakePaymentScreenState();
}

class _TakePaymentScreenState extends ConsumerState<TakePaymentScreen> {
  /// What the person typed, in rupees. Null means the full amount owed.
  String? _typed;
  String _method = 'cash';
  bool _busy = false;
  ApiException? _error;

  /// One key per amount and method. A new key when either changes, so a retry of the same tap is safe.
  String _key = newKey();
  (int, String)? _keyedFor;

  String _keyFor(int amount) {
    final body = (amount, _method);
    if (_keyedFor != body) {
      _keyedFor = body;
      _key = newKey();
    }
    return _key;
  }

  String _raw(CustomerLedger l) => _typed ?? fromPaisa(l.owes);

  List<OpenBill> _openBills(CustomerLedger l) {
    final open = l.sales.where((s) => s.balance > 0 && s.cancelledAt == null).map(OpenBill.fromSale).toList()
      ..sort((a, b) => DateTime.parse(a.soldAt).compareTo(DateTime.parse(b.soldAt)));
    return open;
  }

  String? _amountError(BuildContext context, CustomerLedger l, int? paisa) {
    if (paisa == null || paisa == 0) return context.tr('Type an amount more than zero.', 'शून्यभन्दा बढी रकम लेख्नुहोस्।');
    if (paisa > l.owes) {
      return context.tr(
        'The amount is more than ${l.customer.name} owes (${context.rs(l.owes)}).',
        'रकम ${l.customer.name}ले दिनुपर्ने ${context.rs(l.owes)} भन्दा बढी छ।',
      );
    }
    return null;
  }

  Future<void> _save(CustomerLedger l, int amount) async {
    final key = _keyFor(amount);
    setState(() {
      _busy = true;
      _error = null;
    });
    final owesLeft = await guard(
      () => ref.read(customerRepositoryProvider).takePayment(
            customerId: widget.customerId,
            amount: amount,
            method: _method,
            key: key,
          ),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (owesLeft == null) return;

    _key = newKey();
    _keyedFor = null;
    ref
      ..invalidate(customerLedgerProvider(widget.customerId))
      ..invalidate(customersProvider);
    showToast(
      context,
      'Payment saved. ${l.customer.name} now owes ${rs(owesLeft)}.',
      'भुक्तानी सेभ भयो। अब ${l.customer.name}को बाँकी ${rs(owesLeft)}।',
    );
    context.go('/customers/${widget.customerId}');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customerLedgerProvider(widget.customerId));
    final data = async.value;

    return PageScaffold(
      title: context.tr('Take payment', 'भुक्तानी लिने'),
      bottom: data == null ? null : _saveBar(context, data),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(customerLedgerProvider(widget.customerId)),
        data: (l) => _body(context, l),
      ),
    );
  }

  Widget _saveBar(BuildContext context, CustomerLedger l) {
    final paisa = toPaisa(_raw(l));
    final error = _amountError(context, l, paisa);
    final canSave = !_busy && error == null && paisa != null && _openBills(l).isNotEmpty;
    return PrimaryButton(
      label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save payment', 'भुक्तानी सेभ गर्ने'),
      icon: Icons.check_rounded,
      tone: context.colors.good,
      busy: _busy,
      onPressed: canSave ? () => _save(l, paisa) : null,
    );
  }

  Widget _body(BuildContext context, CustomerLedger l) {
    final owes = l.owes;
    final name = l.customer.name;
    final open = _openBills(l);
    final raw = _raw(l);
    final paisa = toPaisa(raw);
    final error = _amountError(context, l, paisa);
    final plan = error == null && paisa != null ? allocateOldestFirst(open, paisa) : null;
    final half = percentOf(owes, 50);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          tone: Tone.warn,
          child: StatBlock(
            large: true,
            tone: Tone.warn,
            label: context.tr('To collect from $name', '$nameबाट उठाउन बाँकी'),
            value: context.rs(owes),
            sub: context.tr(
              '${context.num(open.length)} open ${context.plural(open.length, 'bill', 'bills')}',
              '${context.num(open.length)} खुला बिल',
            ),
          ),
        ),
        SectionTitle(context.tr('Oldest bills are paid first', 'सबैभन्दा पुरानो बिल पहिले तिरिन्छ')),
        const SizedBox(height: 8),
        if (open.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.tr('No open bills. Nothing to take.', 'खुला बिल छैन। लिने रकम छैन।'),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          )
        else
          ListCard(
            children: [
              for (var i = 0; i < open.length; i++)
                ListRow(
                  leading: IconTile(Icons.receipt_long_rounded, tone: Tone.warn, size: 40),
                  title: open[i].billNo ?? '#${open[i].id}',
                  subtitle: _billSub(context, open[i]),
                  amount: context.rs(open[i].balance),
                  amountTone: Tone.warn,
                  amountLabel: _orderLabel(context, i),
                  chevron: false,
                ),
            ],
          ),
        const SizedBox(height: 12),
        PCard(
          child: Row(
            children: [
              Text(context.tr('Total owed', 'जम्मा बाँकी'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(context.rs(owes), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AmountPad(value: raw, onChanged: (v) => setState(() => _typed = v)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chip in [
              (label: '${context.tr('Full', 'पूरा')} ${context.rs(owes)}', value: owes),
              (label: '${context.tr('Half', 'आधा')} ${context.rs(half)}', value: half),
              (label: context.rs(100000), value: 100000),
            ])
              ChoiceChip(
                label: Text(chip.label),
                selected: paisa == chip.value,
                showCheckmark: false,
                onSelected: (_) => setState(() => _typed = fromPaisa(chip.value)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Seg<String>(
          value: _method,
          onChanged: (v) => setState(() => _method = v),
          icons: const {
            'cash': Icons.payments_rounded,
            'qr': Icons.qr_code_2_rounded,
            'bank': Icons.account_balance_rounded,
            'esewa': Icons.account_balance_wallet_rounded,
            'khalti': Icons.account_balance_wallet_rounded,
          },
          options: {for (final m in paymentMethods) m.key: paymentMethodName(m.key, ne: context.isNe)},
        ),
        const SizedBox(height: 12),
        if (error != null)
          AlertBox(error, icon: Icons.error_rounded)
        else if (plan != null)
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('The money will be used like this', 'पैसा यसरी मिलाइन्छ'),
                  style: context.text.labelMedium?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                for (final a in plan.allocations)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(child: Text(a.bill.billNo ?? '#${a.bill.id}')),
                        Text(
                          a.paidOff
                              ? context.tr('${context.rs(a.pays)} paid off', '${context.rs(a.pays)} चुक्ता')
                              : context.tr(
                                  '${context.rs(a.pays)} paid, ${context.rs(a.bill.balance - a.pays)} left',
                                  '${context.rs(a.pays)} तिरियो, ${context.rs(a.bill.balance - a.pays)} बाँकी',
                                ),
                          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(child: Text(context.tr('After this, $name owes', '$nameको त्यसपछिको बाँकी'))),
                    Text(context.rs(owes - (paisa ?? 0)), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          context.tr('The money pays the oldest bills first.', 'पैसा सबैभन्दा पुरानो बिलबाट मिलाइन्छ।'),
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        if (_error?.field('amount') != null) ...[
          const SizedBox(height: 12),
          AlertBox(_error!.field('amount')!),
        ] else if (_error?.general != null) ...[
          const SizedBox(height: 12),
          AlertBox(_error!.message),
        ],
      ],
    );
  }

  String _billSub(BuildContext context, OpenBill bill) {
    final days = -daysUntil(adOfStamp(bill.soldAt));
    final ago = days <= 0 ? context.tr('Today', 'आज') : context.tr('${context.num(days)} days ago', '${context.num(days)} दिन अघि');
    return '${formatDate(bill.soldAt)} · $ago';
  }

  String _orderLabel(BuildContext context, int index) {
    const neOrder = ['पहिलो', 'दोस्रो', 'तेस्रो', 'चौथो', 'पाँचौं', 'छैटौं', 'सातौं', 'आठौं', 'नवौं', 'दसौं'];
    final n = index + 1;
    if (n > neOrder.length) return context.tr('${n}th', '${context.num(n)}औं');
    final en = switch (n) {
      1 => '1st',
      2 => '2nd',
      3 => '3rd',
      _ => '${n}th',
    };
    return context.tr(en, neOrder[index]);
  }
}
