import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/core/widgets/amount_pad.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/customers/data/customer_repository.dart';
import 'package:pasal_mobile/features/selling/data/selling_repository.dart';

/// The label and colour of a sale in a list: cancelled, returned, to collect, or paid.
({String text, Tone tone}) saleStatus(BuildContext context, Sale sale) {
  if (sale.isCancelled) return (text: context.tr('Cancelled', 'रद्द'), tone: Tone.bad);
  if (sale.returnedTotal > 0) return (text: context.tr('Returned', 'फिर्ता'), tone: Tone.info);
  if (sale.balance > 0) return (text: '${context.tr('To collect', 'उठाउन बाँकी')} ${context.rs(sale.balance)}', tone: Tone.warn);
  return (text: context.tr('Paid', 'तिरेको'), tone: Tone.good);
}

/// Minus, count and plus for one line of a cart or a return.
class QtyStepper extends StatelessWidget {
  const QtyStepper({required this.value, required this.onLess, required this.onMore, super.key});

  final int value;
  final VoidCallback? onLess;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(tooltip: context.tr('Less', 'कम'), onPressed: onLess, icon: const Icon(Icons.remove_rounded)),
        SizedBox(
          width: 36,
          child: Text(
            context.num(value),
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(tooltip: context.tr('More', 'थप'), onPressed: onMore, icon: const Icon(Icons.add_rounded)),
      ],
    );
  }
}

class MoneyRow {
  const MoneyRow(this.label, this.value, {this.tone, this.bold = false});

  final String label;
  final String value;
  final Tone? tone;
  final bool bold;
}

/// Label on the left, amount on the right, one line each, with a thin card around.
class MoneyRows extends StatelessWidget {
  const MoneyRows(this.rows, {super.key});

  final List<MoneyRow> rows;

  @override
  Widget build(BuildContext context) {
    return PCard(
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: row.bold
                          ? context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)
                          : context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    row.value,
                    style: (row.bold ? context.text.titleMedium : context.text.bodyMedium)?.copyWith(
                      fontWeight: row.bold ? FontWeight.w800 : FontWeight.w700,
                      color: row.tone == null || row.tone == Tone.neutral ? context.scheme.onSurface : toneColors(context, row.tone!).fg,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Small red or green line under a field or a row, with an icon.
Widget inlineError(BuildContext context, String message) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: context.colors.bad),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: context.text.bodySmall?.copyWith(color: context.colors.bad, fontWeight: FontWeight.w600))),
        ],
      ),
    );

/// Bill discount in rupees or percent. Returns the discount in paisa.
class DiscountSheet extends StatefulWidget {
  const DiscountSheet({required this.subtotal, required this.current, required this.isOwner, super.key});

  final int subtotal;
  final int current;
  final bool isOwner;

  @override
  State<DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<DiscountSheet> {
  late final TextEditingController _text = TextEditingController(text: widget.current > 0 ? fromPaisa(widget.current) : '');
  bool _percent = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _apply() {
    final raw = _text.text.trim().isEmpty ? '0' : _text.text.trim();
    int? paisa;
    if (_percent) {
      final valid = RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(raw) && double.parse(raw) <= 100;
      paisa = valid ? percentOf(widget.subtotal, double.parse(raw)) : null;
    } else {
      paisa = toPaisa(raw);
    }
    if (paisa == null) {
      setState(() => _error = context.tr('Type an amount', 'रकम लेख्नुहोस्'));
      return;
    }
    if (paisa > widget.subtotal) {
      setState(() => _error = context.tr('The discount is more than the bill', 'छुट बिलभन्दा बढी छ'));
      return;
    }
    Navigator.of(context).pop(paisa);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Seg<bool>(
          value: _percent,
          options: {false: 'Rs', true: '%'},
          onChanged: (v) => setState(() {
            _percent = v;
            _error = null;
          }),
        ),
        const SizedBox(height: 14),
        PField(
          label: context.tr('Amount or percent', 'रकम वा प्रतिशत'),
          controller: _text,
          error: _error,
          hint: '0',
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          helper: widget.isOwner ? null : context.tr('Staff can give up to 10 percent of the bill.', 'कर्मचारीले बिलको १० प्रतिशतसम्म छुट दिन सक्छन्।'),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: context.tr('Apply discount', 'छुट लागू गर्ने'), onPressed: _apply),
      ],
    );
  }
}

/// How much the customer paid now. Returns paisa.
class PaidSheet extends StatefulWidget {
  const PaidSheet({required this.total, required this.current, super.key});

  final int total;
  final int current;

  @override
  State<PaidSheet> createState() => _PaidSheetState();
}

class _PaidSheetState extends State<PaidSheet> {
  late String _value = fromPaisa(widget.current);
  String? _error;

  void _preset(int paisa) => setState(() {
        _value = fromPaisa(paisa);
        _error = null;
      });

  void _done() {
    final paisa = toPaisa(_value);
    if (paisa == null) {
      setState(() => _error = context.tr('Type an amount', 'रकम लेख्नुहोस्'));
      return;
    }
    if (paisa > widget.total) {
      setState(() => _error = context.tr('The paid amount is more than the total, ${context.rs(widget.total)}', 'तिरेको रकम जम्माभन्दा बढी छ, ${context.rs(widget.total)}'));
      return;
    }
    Navigator.of(context).pop(paisa);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            ActionChip(label: Text(context.tr('Full', 'पूरा')), onPressed: () => _preset(widget.total)),
            ActionChip(label: Text(context.tr('Half', 'आधा')), onPressed: () => _preset(percentOf(widget.total, 50))),
            ActionChip(label: Text(context.tr('Nothing (credit)', 'केही होइन (उधारो)')), onPressed: () => _preset(0)),
          ],
        ),
        AmountPad(value: _value, onChanged: (v) => setState(() {
              _value = v;
              _error = null;
            })),
        if (_error != null) inlineError(context, _error!),
        const SizedBox(height: 12),
        PrimaryButton(label: context.tr('Done', 'सम्पन्न'), onPressed: _done),
      ],
    );
  }
}

/// The answer of [CustomerPickerSheet]: a customer, walk-in (null), or the wish to add a new one.
class CustomerPick {
  const CustomerPick({this.customer, this.addNew = false});

  final Customer? customer;
  final bool addNew;
}

/// Pick a customer for a credit sale, or walk-in. Search by name or phone.
class CustomerPickerSheet extends ConsumerStatefulWidget {
  const CustomerPickerSheet({super.key});

  @override
  ConsumerState<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<CustomerPickerSheet> {
  final _search = TextEditingController();
  final _debounce = Debouncer();
  String _term = '';

  @override
  void dispose() {
    _search.dispose();
    _debounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (search: _term, filter: 'all', sort: 'name');
    final data = ref.watch(customersProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: context.tr('Search name or phone', 'नाम वा फोन खोज्नुहोस्'),
          ),
          onChanged: (v) => _debounce.run(() => setState(() => _term = v.trim())),
        ),
        const SizedBox(height: 12),
        AsyncBody<CustomerList>(
          value: data,
          loading: const SizedBox(height: 240, child: SkeletonList(rows: 4)),
          onRetry: () => ref.invalidate(customersProvider(query)),
          data: (list) => ListCard(
            children: [
              ListRow(
                leading: const IconTile(Icons.person_rounded, tone: Tone.good, size: 44),
                title: context.tr('Walk-in customer', 'पसलमा आएका ग्राहक'),
                subtitle: context.tr('Cash only', 'नगद मात्र'),
                chevron: false,
                onTap: () => Navigator.of(context).pop(const CustomerPick()),
              ),
              for (final c in list.customers)
                ListRow(
                  leading: AvatarCircle(c.name, tone: (c.owes ?? 0) > 0 ? Tone.warn : Tone.primary),
                  title: c.name,
                  subtitle: (c.owes ?? 0) > 0 ? context.tr('Owes ${context.rs(c.owes)}', 'बाँकी ${context.rs(c.owes)}') : context.tr('Paid up', 'सबै चुक्ता'),
                  chevron: false,
                  onTap: () => Navigator.of(context).pop(CustomerPick(customer: c)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.of(context).pop(const CustomerPick(addNew: true)),
          icon: const Icon(Icons.person_add_rounded),
          label: Text(context.tr('Add new customer', 'नयाँ ग्राहक थप्ने')),
        ),
      ],
    );
  }
}

/// Take money against one bill. Saves the payment itself and pops `true` on success.
class TakePaymentSheet extends ConsumerStatefulWidget {
  const TakePaymentSheet({required this.sale, super.key});

  final Sale sale;

  @override
  ConsumerState<TakePaymentSheet> createState() => _TakePaymentSheetState();
}

class _TakePaymentSheetState extends ConsumerState<TakePaymentSheet> {
  late String _value = fromPaisa(widget.sale.balance);
  String _method = 'cash';
  bool _busy = false;
  ApiException? _error;
  String _key = newKey();
  String _keyBody = '';

  Future<void> _save() async {
    final amount = toPaisa(_value);
    if (amount == null || amount <= 0) return;
    final repo = ref.read(sellingRepositoryProvider);
    final body = jsonEncode({'sale_id': widget.sale.id, 'amount': amount, 'method': _method});
    if (body != _keyBody) {
      _key = newKey();
      _keyBody = body;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.takePayment(saleId: widget.sale.id, amount: amount, method: _method, key: _key);
      if (!mounted) return;
      _key = newKey();
      _keyBody = '';
      showToast(context, 'Payment saved', 'भुक्तानी सेभ भयो');
      Navigator.of(context).pop(true);
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
    final amount = toPaisa(_value);
    final payable = widget.sale.balance > 0 && amount != null && amount > 0;
    final methods = <String, (String, IconData)>{
      'cash': (context.tr('Cash', 'नगद'), Icons.payments_rounded),
      'qr': ('QR', Icons.qr_code_2_rounded),
      'bank': (context.tr('Bank', 'बैंक'), Icons.account_balance_rounded),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            ActionChip(
              label: Text('${context.tr('Full', 'पूरा')} ${context.rs(widget.sale.balance)}'),
              onPressed: () => setState(() => _value = fromPaisa(widget.sale.balance)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Seg<String>(
          value: _method,
          options: {for (final e in methods.entries) e.key: e.value.$1},
          icons: {for (final e in methods.entries) e.key: e.value.$2},
          onChanged: (v) => setState(() => _method = v),
        ),
        AmountPad(value: _value, onChanged: (v) => setState(() {
              _value = v;
              _error = null;
            })),
        if (_error != null) inlineError(context, _error!.field('amount') ?? _error!.message),
        const SizedBox(height: 4),
        Text(
          context.tr('The money goes to this bill.', 'यो पैसा यही बिलमा जान्छ।'),
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save payment', 'सेभ गर्ने'),
          icon: Icons.check_rounded,
          busy: _busy,
          tone: context.colors.good,
          onPressed: payable ? _save : null,
        ),
      ],
    );
  }
}
