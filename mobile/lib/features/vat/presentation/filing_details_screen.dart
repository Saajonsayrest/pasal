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
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/vat/data/vat_helpers.dart';
import 'package:pasal_mobile/features/vat/data/vat_repository.dart';
import 'package:pasal_mobile/features/vat/presentation/vat_widgets.dart';

/// I3. One saved filing. The numbers are frozen. The person adds the filed date, the paid amount and the receipt.
class FilingDetailsScreen extends ConsumerWidget {
  const FilingDetailsScreen({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filing = ref.watch(vatFilingProvider(id));
    if (filing.hasError && !filing.hasValue) {
      return PageScaffold(
        title: context.tr('Filing details', 'फाइलिङ विवरण'),
        body: ErrorView(error: filing.error!, onRetry: () => ref.invalidate(vatFilingProvider(id))),
      );
    }
    if (!filing.hasValue) {
      return PageScaffold(title: context.tr('Filing details', 'फाइलिङ विवरण'), body: const SkeletonList(rows: 4));
    }
    return _FilingForm(id: id, filing: filing.requireValue);
  }
}

class _FilingForm extends ConsumerStatefulWidget {
  const _FilingForm({required this.id, required this.filing});

  final int id;
  final VatFiling filing;

  @override
  ConsumerState<_FilingForm> createState() => _FilingFormState();
}

class _FilingFormState extends ConsumerState<_FilingForm> {
  late String? _filedOn = widget.filing.filedOn;
  late String? _paidOn = widget.filing.paidOn;
  late final _paid = TextEditingController(text: fromPaisa(widget.filing.paidAmount));
  late final _receipt = TextEditingController(text: widget.filing.receiptNo ?? '');
  late final _note = TextEditingController(text: widget.filing.note ?? '');
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _paid.dispose();
    _receipt.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final paid = toPaisa(_paid.text);
    if (paid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await guard(
      () => ref.read(vatRepositoryProvider).updateMarks(
            widget.id,
            FilingMarks(
              filedOn: _filedOn,
              paidAmount: paid,
              paidOn: _paidOn,
              receiptNo: blankToNull(_receipt.text),
              note: blankToNull(_note.text),
            ),
          ),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;
    ref.invalidate(vatFilingProvider(widget.id));
    ref.invalidate(vatFilingsProvider);
    showToast(context, 'Filing saved', 'फाइलिङ सेभ भयो');
    context.go('/vat/filings');
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filing;
    final status = filingStatus(f);
    final style = statusStyle(context, status);
    final days = dueInDays(f.periodTo);
    final paid = toPaisa(_paid.text);
    final paidError = paid == null ? context.tr('Enter an amount, for example 500', 'रकम लेख्नुहोस्, जस्तै 500') : null;
    final shownInline = ['paid_amount', 'receipt_no', 'note'];
    final errText = errorText(_error, shown: shownInline);
    final isManual = f.source == 'manual';

    return PageScaffold(
      title: context.tr('Filing details', 'फाइलिङ विवरण'),
      bottom: PrimaryButton(
        label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save', 'सेभ गर्ने'),
        icon: Icons.check_rounded,
        busy: _busy,
        onPressed: paid == null || _busy ? null : _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeroCard(
            tone: switch (status) {
              FilingStatus.notFiled => Tone.warn,
              FilingStatus.paid => Tone.good,
              FilingStatus.filed => Tone.primary,
            },
            child: StatBlock(
              large: true,
              tone: style.tone,
              label: '${periodTitle(f.period)} · ${style.label}',
              value: context.rs(f.payable, paisaDigits: true),
              sub: '${context.tr('Due', 'तिर्ने अन्तिम मिति')} ${formatDate(dueDate(f.periodTo))} · ${daysLeftSentence(context, days)}',
            ),
          ),
          const SizedBox(height: 12),
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(context.tr('Frozen numbers', 'जमेका अंक'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    PBadge(
                      isManual ? context.tr('Typed in', 'हातले भरेको') : context.tr('Computed', 'हिसाबबाट बनेको'),
                      tone: isManual ? Tone.info : Tone.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                VatNote(
                  context.tr('These numbers are frozen. They cannot be edited.', 'यी अंक जमेका छन्। यी सच्याउन मिल्दैन।'),
                ),
                const SizedBox(height: 4),
                VatKv(
                  lines: [
                    VatKvLine(context.tr('Period', 'अवधि'), f.period),
                    VatKvLine(context.tr('From', 'देखि'), formatDate(f.periodFrom)),
                    VatKvLine(context.tr('To', 'सम्म'), formatDate(f.periodTo)),
                    VatKvLine(context.tr('Sales taxable', 'करयोग्य बिक्री'), context.rs(f.salesTaxable, paisaDigits: true)),
                    VatKvLine(context.tr('Sales exempt', 'करमुक्त बिक्री'), context.rs(f.salesExempt, paisaDigits: true)),
                    VatKvLine(context.tr('Output VAT', 'बिक्रीमा भ्याट'), context.rs(f.outputVat, paisaDigits: true)),
                    VatKvLine(context.tr('Purchases taxable', 'करयोग्य खरिद'), context.rs(f.purchasesTaxable, paisaDigits: true)),
                    VatKvLine(context.tr('Input VAT', 'खरिदमा भ्याट'), context.rs(f.inputVat, paisaDigits: true)),
                    VatKvLine(context.tr('Carry in', 'अघिल्लो बाँकी'), context.rs(f.carryIn, paisaDigits: true)),
                    VatKvLine(context.tr('Payable', 'तिर्नुपर्ने'), context.rs(f.payable, paisaDigits: true), total: true),
                    VatKvLine(context.tr('Carry out', 'अर्को महिनामा सर्ने'), context.rs(f.carryOut, paisaDigits: true)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('Your entries', 'आफूले भरेको विवरण'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                VatKv(
                  lines: [
                    VatKvLine(
                      context.tr('Remaining to pay', 'अझै तिर्नुपर्ने'),
                      paid == null ? '' : context.rs(f.payable - paid, paisaDigits: true),
                      total: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                twoUp([
                  OptionalBsDate(
                    label: context.tr('Filed on', 'फाइल गरेको मिति'),
                    value: _filedOn,
                    onChanged: (v) => setState(() => _filedOn = v),
                  ),
                  OptionalBsDate(
                    label: context.tr('Paid on', 'तिरेको मिति'),
                    value: _paidOn,
                    onChanged: (v) => setState(() => _paidOn = v),
                  ),
                  MoneyField(
                    label: context.tr('Paid amount', 'तिरेको रकम'),
                    controller: _paid,
                    error: _error?.field('paid_amount') ?? paidError,
                    onChanged: (_) => setState(() {}),
                  ),
                  PField(
                    label: context.tr('Receipt number', 'रसिद नम्बर'),
                    controller: _receipt,
                    hint: context.tr('R-', 'आर-'),
                    error: _error?.field('receipt_no'),
                  ),
                ]),
                PField(
                  label: context.tr('Note', 'टिप्पणी'),
                  controller: _note,
                  hint: context.tr('For example: paid at the bank', 'जस्तै: बैंकमा तिरियो'),
                  error: _error?.field('note'),
                  maxLines: 3,
                ),
              ],
            ),
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
