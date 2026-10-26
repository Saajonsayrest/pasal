import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/customers/data/customer_repository.dart';

/// Add or edit a customer (website E4). The credit limit is for the owner only.
/// [afterCheckout] (`?next=checkout`): after an add, go back to the checkout with the new customer picked.
class CustomerFormScreen extends ConsumerWidget {
  const CustomerFormScreen({this.customerId, this.afterCheckout = false, super.key});

  /// Null when adding a new customer.
  final int? customerId;
  final bool afterCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = customerId;
    if (id == null) {
      return PageScaffold(
        title: context.tr('Add customer', 'ग्राहक थप्ने'),
        body: _CustomerForm(afterCheckout: afterCheckout),
      );
    }
    final async = ref.watch(customerProvider(id));
    return PageScaffold(
      title: context.tr('Edit customer', 'ग्राहक सच्याउने'),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(customerProvider(id)),
        data: (c) => _CustomerForm(customer: c, afterCheckout: afterCheckout),
      ),
    );
  }
}

class _CustomerForm extends ConsumerStatefulWidget {
  const _CustomerForm({this.customer, this.afterCheckout = false});

  final Customer? customer;
  final bool afterCheckout;

  @override
  ConsumerState<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends ConsumerState<_CustomerForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _pan;
  late final TextEditingController _limit;

  bool _busy = false;
  ApiException? _error;
  String? _nameError;
  String? _limitError;

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _pan = TextEditingController(text: c?.pan ?? '');
    _limit = TextEditingController(text: c?.creditLimit == null ? '' : fromPaisa(c!.creditLimit!));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _pan.dispose();
    _limit.dispose();
    super.dispose();
  }

  static String? _orNull(String text) => text.trim().isEmpty ? null : text.trim();

  Future<void> _save() async {
    final name = _name.text.trim();
    final limitText = _limit.text.trim();
    final limit = limitText.isEmpty ? null : toPaisa(limitText);
    final nameError = name.isEmpty ? context.tr('Type the customer name.', 'ग्राहकको नाम लेख्नुहोस्।') : null;
    final limitError = limitText.isNotEmpty && limit == null ? context.tr('Type an amount, for example 10,000.', 'रकम लेख्नुहोस्, जस्तै 10,000।') : null;
    setState(() {
      _nameError = nameError;
      _limitError = limitError;
      _error = null;
    });
    if (nameError != null || limitError != null) return;

    final body = <String, dynamic>{
      'name': name,
      'phone': _orNull(_phone.text),
      'address': _orNull(_address.text),
      'pan': _orNull(_pan.text),
    };
    if (ref.read(sessionProvider).isOwner) body['credit_limit'] = limit;

    setState(() => _busy = true);
    final repo = ref.read(customerRepositoryProvider);
    final saved = await guard(
      () => _isEdit ? repo.update(widget.customer!.id, body) : repo.create(body),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;

    ref.invalidate(customersProvider);
    if (_isEdit) ref.invalidate(customerProvider(saved.id));
    showToast(context, 'Customer saved', 'ग्राहक सेभ भयो');
    if (!_isEdit && widget.afterCheckout) {
      context.go('/sell/checkout?customer=${saved.id}');
    } else {
      context.go('/customers/${saved.id}');
    }
  }

  Future<void> _delete() async {
    final customer = widget.customer;
    if (customer == null) return;
    final ok = await confirmSheet(
      context,
      title: context.tr('Delete customer?', 'ग्राहक हटाउने हो?'),
      message: context.tr(
        'The customer will be hidden from lists and new sales. Old bills keep the name.',
        'ग्राहक सूची र नयाँ बिक्रीबाट हट्छ। पुराना बिलमा नाम रहन्छ।',
      ),
      confirmLabel: context.tr('Delete', 'हटाउने'),
      danger: true,
    );
    if (!ok || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(customerRepositoryProvider);
    final done = await guard(
      () async {
        await repo.delete(customer.id);
        return true;
      },
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (done ?? false) {
      ref.invalidate(customersProvider);
      showToast(
        context,
        'Customer deleted. Old bills keep the name.',
        'ग्राहक हटाइयो। पुराना बिलमा नाम रहन्छ।',
      );
      context.go('/customers');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(sessionProvider).isOwner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCard(
          child: Column(
            children: [
              PField(
                label: context.tr('Name (required)', 'नाम (आवश्यक)'),
                controller: _name,
                hint: context.tr('e.g. Hari Thapa', 'जस्तै: हरि थापा'),
                error: _nameError ?? _error?.field('name'),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              PField(
                label: context.tr('Phone', 'फोन'),
                controller: _phone,
                hint: '98000000xx',
                keyboardType: TextInputType.phone,
                error: _error?.field('phone'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              PField(
                label: context.tr('Address', 'ठेगाना'),
                controller: _address,
                hint: context.tr('Tole, ward, area', 'टोल, वडा, क्षेत्र'),
                maxLines: 2,
                error: _error?.field('address'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              PField(
                label: context.tr('PAN number (optional)', 'PAN नम्बर (ऐच्छिक)'),
                controller: _pan,
                hint: '600000000',
                keyboardType: TextInputType.number,
                helper: context.tr('Only needed when the customer wants a VAT bill.', 'VAT बिल चाहिएमा मात्र भर्नुहोस्।'),
                error: _error?.field('pan'),
                textInputAction: TextInputAction.done,
              ),
              if (isOwner) ...[
                const SizedBox(height: 14),
                MoneyField(
                  label: context.tr('Credit limit', 'उधारो सीमा'),
                  controller: _limit,
                  hint: '10,000',
                  error: _limitError ?? _error?.field('credit_limit'),
                  helper: context.tr(
                    'Credit above this is refused at the sale. Leave empty for no limit. 0 means cash only.',
                    'यो रकमभन्दा बढी उधारो बिक्रीमा रोकिन्छ। खाली छोड्दा सीमा हुँदैन। ० भए नगद मात्र।',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
        if (_error?.general != null) ...[
          const SizedBox(height: 14),
          AlertBox(_error!.general!),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save', 'सेभ गर्ने'),
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: _busy ? null : _save,
        ),
        if (_isEdit) ...[
          const SizedBox(height: 20),
          ListCard(
            children: [
              ListRow(
                leading: IconTile(Icons.delete_rounded, tone: Tone.bad, size: 40),
                title: context.tr('Delete customer', 'ग्राहक हटाउने'),
                subtitle: context.tr('Old bills keep the name.', 'पुराना बिलमा नाम रहन्छ।'),
                chevron: false,
                onTap: _busy ? null : _delete,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
