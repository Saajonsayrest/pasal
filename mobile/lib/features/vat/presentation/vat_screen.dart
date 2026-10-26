import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/core/widgets/bs_date.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/vat/data/vat_helpers.dart';
import 'package:pasal_mobile/features/vat/data/vat_repository.dart';
import 'package:pasal_mobile/features/vat/presentation/vat_widgets.dart';

/// I1. VAT for one Nepali month: the numbers so far, and a button to save the month as a filing.
class VatScreen extends ConsumerStatefulWidget {
  const VatScreen({super.key});

  @override
  ConsumerState<VatScreen> createState() => _VatScreenState();
}

class _VatScreenState extends ConsumerState<VatScreen> {
  int _year = todayBs().year;
  int _month = todayBs().month;
  final _opening = TextEditingController(text: '0');
  final _openingDebounce = Debouncer();
  final _key = RequestKey();
  int _openingCarry = 0;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _opening.dispose();
    _openingDebounce.dispose();
    super.dispose();
  }

  void _openingChanged(String text) {
    setState(() {});
    _openingDebounce.run(() {
      final paisa = toPaisa(text);
      if (paisa != null) setState(() => _openingCarry = paisa);
    });
  }

  Future<void> _save() async {
    final range = bsMonthRange(_year, _month);
    final period = periodLabel(_year, _month);
    final key = _key.forInputs((period, range.from, range.to, _openingCarry));
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await guard(
      () => ref.read(vatRepositoryProvider).saveComputed(
            period: period,
            from: range.from,
            to: range.to,
            openingCarry: _openingCarry,
            key: key,
          ),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;
    _key.reset();
    ref.invalidate(vatFilingsProvider);
    final title = monthTitle(_year, _month);
    showToast(context, 'Saved as $title filing', '$title फाइलिङमा सेभ भयो');
    context.go('/vat/filings');
  }

  @override
  Widget build(BuildContext context) {
    final range = bsMonthRange(_year, _month);
    final period = periodLabel(_year, _month);
    final title = monthTitle(_year, _month);
    final today = todayAd();
    final isCurrent = range.from.compareTo(today) <= 0 && today.compareTo(range.to) <= 0;
    final query = (from: range.from, to: range.to, openingCarry: _openingCarry);
    final preview = ref.watch(vatPreviewProvider(query));
    final existing = filingForPeriod(ref.watch(vatFilingsProvider(50)).value?.items ?? const [], period);
    final openingError = toPaisa(_opening.text) == null ? context.tr('Type an amount, for example 1250', 'रकम लेख्नुहोस्, जस्तै 1250') : null;
    final existingStyle = existing == null ? null : statusStyle(context, filingStatus(existing));
    final p = preview.value;
    final errText = errorText(_error);

    final children = <Widget>[
      MonthNav(
        year: _year,
        month: _month,
        onChanged: (y, m) => setState(() {
          _year = y;
          _month = m;
        }),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: VatNote('${formatDate(range.from)} ${context.tr('to', 'सम्म')} ${formatDate(range.to)}'),
      ),
    ];

    if (preview.hasError && !preview.hasValue) {
      children.add(ErrorView(error: preview.error!, onRetry: () => ref.invalidate(vatPreviewProvider(query))));
    } else if (p == null) {
      children.add(const SkeletonList(rows: 3));
    } else {
      final days = daysUntil(p.dueDate);
      final showOpening = p.carryInSource.toLowerCase().contains('opening');
      final canSave = existing == null && openingError == null && !_busy;
      children.addAll([
        PCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Due date', 'तिर्ने अन्तिम मिति'), style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant)),
                    Text(formatDate(p.dueDate), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(context.num(days.abs()), style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: days < 0 ? context.colors.bad : null)),
                  Text(
                    days < 0 ? context.tr('days past due', 'म्याद नाघेको दिन') : context.tr('days left', 'दिन बाँकी'),
                    style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        HeroCard(
          child: StatBlock(
            large: true,
            label: context.tr('VAT to pay this month', 'यो महिनाको तिर्नुपर्ने भ्याट'),
            value: context.rs(p.payable, paisaDigits: true),
            sub: isCurrent
                ? context.tr('Numbers up to today (${formatDate(today)})', 'आजसम्मको अंक (${formatDate(today)} सम्म)')
                : context.tr('Numbers for the whole month', 'महिना भरिको अंक'),
          ),
        ),
        const SizedBox(height: 12),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Breakdown', 'हिसाब'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              VatKv(
                lines: [
                  VatKvLine(context.tr('Sales bills', 'बिक्री बिल'), context.num(p.salesBills)),
                  VatKvLine(context.tr('Taxable sales', 'करयोग्य बिक्री'), context.rs(p.salesTaxable, paisaDigits: true)),
                  VatKvLine(context.tr('Exempt sales', 'करमुक्त बिक्री'), context.rs(p.salesExempt, paisaDigits: true)),
                  VatKvLine(context.tr('Output VAT', 'बिक्रीमा लागेको भ्याट'), context.rs(p.outputVat, paisaDigits: true)),
                  VatKvLine(context.tr('Purchase bills with VAT', 'भ्याट भएका खरिद बिल'), context.num(p.purchaseBillsWithVat)),
                  VatKvLine(context.tr('Taxable purchases', 'करयोग्य खरिद'), context.rs(p.purchasesTaxable, paisaDigits: true)),
                  VatKvLine(context.tr('Input VAT', 'खरिदमा तिरेको भ्याट'), context.rs(p.inputVat, paisaDigits: true)),
                  VatKvLine(context.tr('Carried from last month', 'अघिल्लो महिनाबाट सरेको'), context.rs(p.carryIn, paisaDigits: true)),
                  VatKvLine(context.tr('Payable', 'तिर्नुपर्ने'), context.rs(p.payable, paisaDigits: true), total: true),
                  VatKvLine(context.tr('Carry to next month', 'अर्को महिनामा सर्ने'), context.rs(p.carryOut, paisaDigits: true)),
                ],
              ),
              const SizedBox(height: 10),
              VatNote(
                context.tr(
                  'Payable = output VAT - input VAT - carried from last month. If that is below zero, nothing is paid and the rest is carried to next month.',
                  'तिर्नुपर्ने = बिक्रीको भ्याट - खरिदको भ्याट - अघिल्लो बाँकी। शून्यभन्दा कम भए केही तिर्नु पर्दैन र बाँकी अर्को महिनामा सर्छ।',
                ),
              ),
            ],
          ),
        ),
        if (showOpening) ...[
          const SizedBox(height: 12),
          PCard(
            child: MoneyField(
              label: context.tr('Opening carry (rupees)', 'सुरुको बाँकी (रुपैयाँ)'),
              controller: _opening,
              error: openingError,
              helper: context.tr(
                'Set once. Type the credit from your last IRD return. If you are not sure, keep 0.',
                'एक पटक मात्र। अन्तिम IRD रिटर्नको बाँकी लेख्नुहोस्। थाहा छैन भने 0 राख्नुहोस्।',
              ),
              onChanged: _openingChanged,
            ),
          ),
        ],
        const SizedBox(height: 12),
        VatNote(
          context.tr(
            'These numbers are building blocks to copy into the IRD form. Check the box names with the IRD portal before you file.',
            'यी अंक IRD फारममा सार्नका लागि आधार हुन्। फाइल गर्नु अघि IRD पोर्टलमा खानाहरूको नाम जाँच गर्नुहोस्।',
          ),
        ),
        if (existing != null) ...[
          const SizedBox(height: 12),
          PCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('$title is already saved', '$title पहिले नै सेभ भइसकेको छ'), style: context.text.bodySmall),
                      TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => context.push('/vat/filings/${existing.id}'),
                        child: Text(context.tr('Open the filing', 'फाइलिङ खोल्ने')),
                      ),
                    ],
                  ),
                ),
                PBadge(existingStyle!.label, tone: existingStyle.tone),
              ],
            ),
          ),
        ],
        if (errText != null) ...[
          const SizedBox(height: 12),
          AlertBox(errText),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save $title as filing', '$title फाइलिङमा सेभ गर्ने'),
          icon: Icons.save_rounded,
          busy: _busy,
          onPressed: canSave ? _save : null,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.push('/vat/filings'),
              icon: const Icon(Icons.folder_rounded),
              label: Text(context.tr('See filings', 'फाइलिङ हेर्ने')),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/vat/old-return'),
              icon: const Icon(Icons.history_rounded),
              label: Text(context.tr('Add old return', 'पुरानो रिटर्न थप्ने')),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/vat/books'),
              icon: const Icon(Icons.menu_book_rounded),
              label: Text(context.tr('Sales and purchase books', 'बिक्री र खरिद खाता')),
            ),
          ],
        ),
      ]);
    }

    return PageScaffold(
      title: context.tr('VAT this month', 'यो महिनाको भ्याट'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}
