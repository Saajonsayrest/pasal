import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/vat/data/vat_helpers.dart';
import 'package:pasal_mobile/features/vat/data/vat_repository.dart';
import 'package:pasal_mobile/features/vat/presentation/vat_widgets.dart';

/// The amount boxes of an old return, in the order the website shows them.
enum ReturnAmount {
  salesTaxable('sales_taxable', 'Sales taxable', 'करयोग्य बिक्री'),
  salesExempt('sales_exempt', 'Sales exempt', 'करमुक्त बिक्री'),
  outputVat('output_vat', 'Output VAT', 'बिक्रीमा भ्याट'),
  purchasesTaxable('purchases_taxable', 'Purchases taxable', 'करयोग्य खरिद'),
  inputVat('input_vat', 'Input VAT', 'खरिदमा भ्याट'),
  carryIn('carry_in', 'Carry in', 'अघिल्लो बाँकी'),
  payable('payable', 'Payable', 'तिर्नुपर्ने'),
  carryOut('carry_out', 'Carry out', 'अर्को महिनामा सर्ने');

  const ReturnAmount(this.apiKey, this.en, this.ne);

  final String apiKey;
  final String en;
  final String ne;
}

/// I4. Type in a return that was filed before the app existed. Save months in date order.
class OldReturnScreen extends ConsumerStatefulWidget {
  const OldReturnScreen({super.key});

  @override
  ConsumerState<OldReturnScreen> createState() => _OldReturnScreenState();
}

class _OldReturnScreenState extends ConsumerState<OldReturnScreen> {
  static final List<int> _years = List<int>.generate(13, (i) => 2078 + i);

  late int _year;
  late int _month;
  final _amounts = {for (final a in ReturnAmount.values) a: TextEditingController(text: '0')};
  final _paid = TextEditingController(text: '0');
  final _receipt = TextEditingController();
  final _key = RequestKey();
  String? _filedOn;
  bool _busy = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final previous = shiftMonth(todayBs().year, todayBs().month, -1);
    _year = previous.year;
    _month = previous.month;
  }

  @override
  void dispose() {
    for (final c in _amounts.values) {
      c.dispose();
    }
    _paid.dispose();
    _receipt.dispose();
    super.dispose();
  }

  bool get _valid => toPaisa(_paid.text) != null && ReturnAmount.values.every((a) => toPaisa(_amounts[a]!.text) != null);

  Future<void> _save() async {
    final range = bsMonthRange(_year, _month);
    final period = periodLabel(_year, _month);
    int amount(ReturnAmount a) => toPaisa(_amounts[a]!.text) ?? 0;
    final ret = ManualReturn(
      period: period,
      from: range.from,
      to: range.to,
      salesTaxable: amount(ReturnAmount.salesTaxable),
      salesExempt: amount(ReturnAmount.salesExempt),
      outputVat: amount(ReturnAmount.outputVat),
      purchasesTaxable: amount(ReturnAmount.purchasesTaxable),
      inputVat: amount(ReturnAmount.inputVat),
      carryIn: amount(ReturnAmount.carryIn),
      payable: amount(ReturnAmount.payable),
      carryOut: amount(ReturnAmount.carryOut),
      paidAmount: toPaisa(_paid.text) ?? 0,
      filedOn: _filedOn,
      receiptNo: blankToNull(_receipt.text),
    );
    final key = _key.forInputs(ret.toJson());
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await guard(
      () => ref.read(vatRepositoryProvider).saveManual(ret, key: key),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;
    _key.reset();
    ref.invalidate(vatFilingsProvider);
    showToast(context, '$period return saved', '${digits(period)} रिटर्न सेभ भयो');
    context.go('/vat/filings');
  }

  @override
  Widget build(BuildContext context) {
    final range = bsMonthRange(_year, _month);
    final period = periodLabel(_year, _month);
    final shownInline = [
      'period',
      'from',
      'to',
      'paid_amount',
      'receipt_no',
      for (final a in ReturnAmount.values) a.apiKey,
    ];
    final errText = errorText(_error, shown: shownInline);

    return PageScaffold(
      title: context.tr('Add old return', 'पुरानो रिटर्न थप्ने'),
      bottom: PrimaryButton(
        label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save return', 'रिटर्न सेभ गर्ने'),
        icon: Icons.save_rounded,
        busy: _busy,
        onPressed: _valid && !_busy ? _save : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AlertBox(
            context.tr(
              'Save months in date order. Each month reads the carry of the month before it.',
              'महिनाहरू मितिको क्रममा सेभ गर्नुहोस्। हरेक महिनाले अघिल्लो महिनाको बाँकी पढ्छ।',
            ),
            tone: Tone.info,
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              context.tr('Nepali month', 'बिक्रम सम्वत् महिना'),
              style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _year,
                  items: [for (final y in _years) DropdownMenuItem(value: y, child: Text(digits(y)))],
                  onChanged: (v) => setState(() => _year = v ?? _year),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _month,
                  items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(monthName(m)))],
                  onChanged: (v) => setState(() => _month = v ?? _month),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ReadOnlyValue(
            label: context.tr('Period label', 'अवधिको नाम'),
            value: period,
            hint: context.tr('Made from the month you picked', 'छानेको महिनाबाट बन्छ'),
          ),
          const SizedBox(height: 12),
          twoUp([
            ReadOnlyValue(label: context.tr('From', 'देखि'), value: formatDate(range.from)),
            ReadOnlyValue(label: context.tr('To', 'सम्म'), value: formatDate(range.to)),
          ]),
          twoUp([
            for (final a in ReturnAmount.values)
              MoneyField(
                label: context.tr(a.en, a.ne),
                controller: _amounts[a]!,
                error: _error?.field(a.apiKey) ?? amountError(context, _amounts[a]!.text),
                onChanged: (_) => setState(() {}),
              ),
          ]),
          twoUp([
            OptionalBsDate(
              label: context.tr('Filed on', 'फाइल गरेको मिति'),
              value: _filedOn,
              onChanged: (v) => setState(() => _filedOn = v),
            ),
            MoneyField(
              label: context.tr('Paid amount', 'तिरेको रकम'),
              controller: _paid,
              error: _error?.field('paid_amount') ?? amountError(context, _paid.text),
              onChanged: (_) => setState(() {}),
            ),
          ]),
          PField(
            label: context.tr('Receipt number', 'रसिद नम्बर'),
            controller: _receipt,
            hint: context.tr('R-', 'आर-'),
            error: _error?.field('receipt_no'),
          ),
          if (errText != null) ...[
            const SizedBox(height: 12),
            AlertBox(errText),
          ],
        ],
      ),
    );
  }
}
