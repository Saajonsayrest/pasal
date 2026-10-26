import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/customers/data/customer_repository.dart';
import 'package:pasal_mobile/features/selling/data/cart.dart';
import 'package:pasal_mobile/features/selling/data/selling_repository.dart';
import 'package:pasal_mobile/features/selling/presentation/selling_widgets.dart';

/// Cart and payment (/sell/checkout). Saves the sale, then opens its bill.
/// [customerId] selects a customer that was just added (`?customer=ID` in the path).
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({this.customerId, super.key});

  final int? customerId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _note = TextEditingController();
  bool _busy = false;
  bool _ignoreLimit = false;
  ApiException? _error;
  String _key = newKey();
  String _keyBody = '';

  @override
  void initState() {
    super.initState();
    _note.text = ref.read(cartProvider).note;
    final id = widget.customerId;
    if (id != null) WidgetsBinding.instance.addPostFrameCallback((_) => _selectCustomerById(id));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _selectCustomerById(int id) async {
    final repo = ref.read(customerRepositoryProvider);
    try {
      final customer = await repo.get(id);
      if (!mounted) return;
      ref.read(cartProvider.notifier).setCustomer(customer);
      setState(() => _ignoreLimit = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      showProblem(context, e.message);
    }
  }

  Future<void> _openDiscount() async {
    final cart = ref.read(cartProvider);
    final isOwner = ref.read(sessionProvider).isOwner;
    final paisa = await showPasalSheet<int>(
      context,
      title: context.tr('Bill discount', 'बिलमा छुट'),
      builder: (_) => DiscountSheet(subtotal: cart.subtotal, current: cart.discount, isOwner: isOwner),
    );
    if (paisa == null || !mounted) return;
    ref.read(cartProvider.notifier).setDiscount(paisa);
  }

  Future<void> _pickCustomer() async {
    final pick = await showPasalSheet<CustomerPick>(
      context,
      title: context.tr('Choose customer', 'ग्राहक छान्नुहोस्'),
      builder: (_) => const CustomerPickerSheet(),
    );
    if (pick == null || !mounted) return;
    if (pick.addNew) {
      final id = await context.push<int>('/customers/new?next=checkout');
      if (id == null || !mounted) return;
      await _selectCustomerById(id);
      return;
    }
    ref.read(cartProvider.notifier).setCustomer(pick.customer);
    setState(() => _ignoreLimit = false);
  }

  Future<void> _openPaid() async {
    final cart = ref.read(cartProvider);
    final paisa = await showPasalSheet<int>(
      context,
      title: context.tr('Amount paid', 'तिरेको रकम'),
      builder: (_) => PaidSheet(total: cart.total, current: cart.paidAmount),
    );
    if (paisa == null || !mounted) return;
    ref.read(cartProvider.notifier).setPaid(paisa == cart.total ? null : paisa);
  }

  bool _limitHit(CartState cart) => cart.customer != null && overLimit(cart.customer!.owes ?? 0, cart.balance, cart.customer!.creditLimit);

  Future<void> _finish() async {
    final cart = ref.read(cartProvider);
    final isOwner = ref.read(sessionProvider).isOwner;
    final limitHit = _limitHit(cart);
    final body = <String, Object?>{
      if (cart.customer != null) 'customer_id': cart.customer!.id,
      'paid': cart.paidAmount,
      'discount': cart.discount,
      'method': cart.method,
      if (cart.note.trim().isNotEmpty) 'note': cart.note.trim(),
      'items': [for (final l in cart.lines) {'item_id': l.item.id, 'quantity': l.qty}],
      if (limitHit && isOwner && _ignoreLimit) 'ignore_credit_limit': true,
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
      final sale = await repo.createSale(body, _key);
      if (!mounted) return;
      final billNo = sale.billNo ?? '${sale.id}';
      ref.read(cartProvider.notifier).clear();
      _key = newKey();
      _keyBody = '';
      showToast(context, 'Sale saved as $billNo', 'बिक्री सेभ भयो: $billNo');
      context.pushReplacement('/sales/${sale.id}/bill');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e;
      });
    }
  }

  static const _fieldErrors = {'discount', 'customer_id', 'paid', 'note', 'ignore_credit_limit'};

  bool _isStockError(String key) => key == 'quantity' || key.startsWith('items');

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final session = ref.watch(sessionProvider);
    final isOwner = session.isOwner;
    final rate = session.business?.vatRate ?? 0.0;

    if (cart.lines.isEmpty) {
      return PageScaffold(
        title: context.tr('Cart and checkout', 'कार्ट र भुक्तानी'),
        scroll: false,
        body: EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: context.tr('The cart is empty', 'कार्ट खाली छ'),
          text: context.tr('Add items on the sell screen first.', 'पहिले बिक्री पेजमा सामान थप्नुहोस्।'),
          actionLabel: context.tr('Go to sell', 'बेच्न जाने'),
          onAction: () => context.go('/sell'),
        ),
      );
    }

    final split = vatBreakdown(cart.lines, cart.discount, rate);
    final customer = cart.customer;
    final owes = customer?.owes ?? 0;
    final limit = customer?.creditLimit;
    final limitHit = _limitHit(cart);
    final limitBlocked = limitHit && !(isOwner && _ignoreLimit);
    final blocked = !cart.canCheckout || limitBlocked || _busy;

    String? stockMessage;
    final error = _error;
    if (error != null) {
      for (final entry in error.errors.entries) {
        if (_isStockError(entry.key) && entry.value.isNotEmpty) {
          stockMessage = entry.value.first;
          break;
        }
      }
    }
    final generalMessage = error == null
        ? null
        : (error.errors.isEmpty || error.errors.keys.any((k) => !_fieldErrors.contains(k) && !_isStockError(k)) ? error.message : null);
    CartLine? overLine;
    for (final line in cart.lines) {
      if (line.qty > line.item.quantity) {
        overLine = line;
        break;
      }
    }

    final methods = <String, String>{
      'cash': context.tr('Cash', 'नगद'),
      'qr': 'QR',
      'bank': context.tr('Bank', 'बैंक'),
      'card': context.tr('Card', 'कार्ड'),
    };

    return PageScaffold(
      title: context.tr('Cart and checkout', 'कार्ट र भुक्तानी'),
      bottom: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Total', 'जम्मा'), style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
              Text(context.rs(cart.total), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PrimaryButton(
              label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Finish sale', 'बिक्री पूरा गर्ने'),
              icon: Icons.check_rounded,
              busy: _busy,
              onPressed: blocked ? null : _finish,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (generalMessage != null) ...[AlertBox(generalMessage), const SizedBox(height: 12)],
          if (stockMessage != null)
            ...[AlertBox(stockMessage), const SizedBox(height: 12)]
          else if (overLine != null)
            ...[
              AlertBox(
                context.tr(
                  'Only ${context.num(overLine.item.quantity)} ${overLine.item.name} left. Lower the amount.',
                  '${overLine.item.name} मात्र ${context.num(overLine.item.quantity)} बाँकी छ। संख्या घटाउनुहोस्।',
                ),
                tone: Tone.warn,
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(height: 12),
            ],
          ListCard(
            children: [
              for (final line in cart.lines)
                _LineRow(
                  line: line,
                  onQty: (q) => ref.read(cartProvider.notifier).setQty(line.item.id, q),
                  onRemove: () => ref.read(cartProvider.notifier).remove(line.item.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              ListCard(
                children: [
                  ListRow(
                    leading: const IconTile(Icons.sell_rounded),
                    title: context.tr('Bill discount', 'बिलमा छुट'),
                    subtitle: cart.discount > 0 ? context.rs(cart.discount) : context.tr('None', 'छैन'),
                    onTap: _openDiscount,
                  ),
                ],
              ),
              if (error?.field('discount') != null) inlineError(context, error!.field('discount')!),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              ListCard(
                children: [
                  ListRow(
                    leading: customer == null
                        ? const IconTile(Icons.person_rounded, tone: Tone.good)
                        : AvatarCircle(customer.name, tone: owes > 0 ? Tone.warn : Tone.primary),
                    title: customer?.name ?? context.tr('Walk-in customer', 'पसलमा आएका ग्राहक'),
                    subtitle: customer == null
                        ? context.tr('Cash only', 'नगद मात्र')
                        : owes > 0
                            ? context.tr('Owes ${context.rs(owes)}', 'बाँकी ${context.rs(owes)}')
                            : context.tr('Paid up', 'सबै चुक्ता'),
                    onTap: _pickCustomer,
                  ),
                ],
              ),
              if (error?.field('customer_id') != null) inlineError(context, error!.field('customer_id')!),
            ],
          ),
          const SizedBox(height: 12),
          MoneyRows([
            MoneyRow(context.tr('Subtotal', 'उप-जम्मा'), context.rs(cart.subtotal)),
            MoneyRow(context.tr('Discount', 'छुट'), context.rs(cart.discount)),
            MoneyRow(context.tr('Taxable amount', 'करयोग्य रकम'), context.rs(split.taxable, paisaDigits: true)),
            MoneyRow('${context.tr('VAT', 'भ्याट')} ${digits(_rateText(rate))}%', context.rs(split.vat, paisaDigits: true)),
            MoneyRow(context.tr('Total', 'जम्मा'), context.rs(cart.total), bold: true),
            MoneyRow(context.tr('Paid', 'तिरेको'), context.rs(cart.paidAmount), tone: Tone.good),
            MoneyRow(
              context.tr('Balance on credit', 'उधारोमा बाँकी'),
              context.rs(cart.balance),
              tone: cart.balance > 0 ? Tone.warn : null,
            ),
          ]),
          const SizedBox(height: 12),
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: StatBlock(label: context.tr('Amount paid', 'तिरेको रकम'), value: context.rs(cart.paidAmount), large: true)),
                    TextButton.icon(
                      onPressed: _openPaid,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text(context.tr('Change', 'बदल्ने')),
                    ),
                  ],
                ),
                if (error?.field('paid') != null) inlineError(context, error!.field('paid')!),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Seg<String>(
            value: cart.method,
            options: methods,
            icons: const {
              'cash': Icons.payments_rounded,
              'qr': Icons.qr_code_2_rounded,
              'bank': Icons.account_balance_rounded,
              'card': Icons.credit_card_rounded,
            },
            onChanged: (v) => ref.read(cartProvider.notifier).setMethod(v),
          ),
          const SizedBox(height: 12),
          PField(
            label: context.tr('Note (optional)', 'नोट (ऐच्छिक)'),
            controller: _note,
            error: error?.field('note'),
            onChanged: (v) => ref.read(cartProvider.notifier).setNote(v),
          ),
          if (cart.balance > 0 && customer == null) ...[
            const SizedBox(height: 12),
            AlertBox(
              context.tr(
                'Paid is less than the total. Pick a customer for credit (udhar).',
                'तिरेको रकम जम्माभन्दा कम छ। उधारोका लागि ग्राहक छान्नुहोस्।',
              ),
              tone: Tone.warn,
              icon: Icons.warning_amber_rounded,
            ),
          ],
          if (limitHit && customer != null) ...[
            const SizedBox(height: 12),
            PCard(
              tone: Tone.warn,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr(
                      '${customer.name} would owe ${context.rs(owes + cart.balance)}. The limit is ${context.rs(limit ?? 0)}.',
                      '${customer.name} ले ${context.rs(owes + cart.balance)} बाँकी राख्छन्। सीमा ${context.rs(limit ?? 0)} हो।',
                    ),
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (isOwner)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Sell past the limit', 'सीमा नाघेर बेच्ने')),
                      value: _ignoreLimit,
                      onChanged: (v) => setState(() => _ignoreLimit = v),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        context.tr('Ask the owner to allow this sale.', 'यो बिक्री गर्न मालिकलाई सोध्नुहोस्।'),
                        style: context.text.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _rateText(double rate) => rate % 1 == 0 ? rate.toInt().toString() : rate.toString();

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.onQty, required this.onRemove});

  final CartLine line;
  final ValueChanged<int> onQty;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final qty = line.qty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(context.rs(lineAmount(line)), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${context.rs(line.item.sellPrice)} ${context.tr('each', 'प्रति')}',
                  style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ),
              QtyStepper(
                value: qty,
                onLess: qty <= 1 ? null : () => onQty(qty - 1),
                onMore: qty >= line.item.quantity ? null : () => onQty(qty + 1),
              ),
              IconButton(
                tooltip: context.tr('Remove item', 'सामान हटाउने'),
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
