import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/core/widgets/bs_date.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/money/data/cash_count_store.dart';
import 'package:pasal_mobile/features/money/data/money_repository.dart';
import 'package:pasal_mobile/features/money/presentation/money_labels.dart';

/// Note values for the count sheet, biggest first (rupees).
const _notes = [1000, 500, 100, 50, 20, 10, 5];

/// G3. Every rupee in and out of one day, the cash that should be in the drawer, and the counted cash.
class CashBookScreen extends ConsumerStatefulWidget {
  const CashBookScreen({super.key});

  @override
  ConsumerState<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends ConsumerState<CashBookScreen> {
  final _counted = TextEditingController();
  late final String _today = todayAd();
  late String _day = _today;
  String? _countError;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  /// Fills the counted box with the count saved for [_day], if there is one.
  void _loadCount() {
    final saved = ref.read(cashCountStoreProvider).read(_day);
    _counted.text = saved == null ? '' : fromPaisa(saved.counted);
    _countError = null;
  }

  void _selectDay(String day) => setState(() {
        _day = day;
        _loadCount();
      });

  int? get _countedPaisa => _counted.text.trim().isEmpty ? null : toPaisa(_counted.text);

  Future<void> _saveDay(int expected) async {
    final counted = _countedPaisa;
    if (counted == null) {
      setState(() => _countError = context.tr('Type the counted cash in rupees first', 'पहिले गनिएको नगद रुपैयाँमा लेख्नुहोस्'));
      return;
    }
    await ref.read(cashCountStoreProvider).save(CashCount(day: _day, counted: counted, expected: expected));
    if (!mounted) return;
    ref.invalidate(savedCashCountsProvider);
    setState(() => _countError = null);
    showToast(context, 'Count saved', 'गन्ती सेभ भयो');
  }

  void _openCount(BuildContext context, int expected) {
    showPasalSheet<void>(
      context,
      title: context.tr('Count cash', 'नगद गन्ने'),
      builder: (_) => _CountSheet(
        expected: expected,
        onUse: (paisa) => setState(() {
          _counted.text = fromPaisa(paisa);
          _countError = null;
        }),
      ),
    );
  }

  Widget _kv(String label, String value, {Color? color, bool total = false}) {
    final style = total ? context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800) : context.text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style?.copyWith(color: total ? null : context.scheme.onSurfaceVariant))),
          Text(value, style: style?.copyWith(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _verdict(int diff) {
    if (diff < 0) {
      return AlertBox(
        context.tr('${context.rs(-diff)} short', '${context.rs(-diff)} कम छ'),
        tone: Tone.warn,
        icon: Icons.warning_amber_rounded,
      );
    }
    if (diff > 0) {
      return AlertBox(
        context.tr('${context.rs(diff)} over', '${context.rs(diff)} बढी छ'),
        tone: Tone.info,
        icon: Icons.info_outline_rounded,
      );
    }
    return AlertBox(context.tr('Matches', 'मिल्यो'), tone: Tone.good, icon: Icons.check_circle_outline_rounded);
  }

  Widget _content(CashBook data, List<CashCount> saved) {
    final expected = data.closingBalance;
    final countedPaisa = _countedPaisa;
    final invalid = _counted.text.trim().isNotEmpty && countedPaisa == null;
    final diff = countedPaisa == null ? null : countedPaisa - expected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          child: StatBlock(
            large: true,
            label: context.tr('Expected cash in drawer', 'ड्रअरमा अपेक्षित नगद'),
            value: context.rs(expected),
            sub: context.tr('Opening balance + money in - money out', 'सुरुको रकम + आएको - गएको'),
          ),
        ),
        const SizedBox(height: 12),
        PCard(
          child: Column(
            children: [
              _kv(context.tr('Opening cash', 'सुरुको नगद'), context.rs(data.openingBalance)),
              _kv(context.tr('Money in', 'आएको पैसा'), '+ ${context.rs(data.moneyIn)}', color: context.colors.good),
              _kv(context.tr('Money out', 'गएको पैसा'), '- ${context.rs(data.moneyOut)}', color: context.colors.bad),
              const Divider(height: 20),
              _kv(context.tr('Expected in drawer', 'ड्रअरमा अपेक्षित'), context.rs(expected), total: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MoneyField(
                label: context.tr('Counted cash (rupees)', 'गनिएको नगद (रुपैयाँ)'),
                controller: _counted,
                error: invalid ? context.tr('Type a number in rupees', 'रुपैयाँमा संख्या लेख्नुहोस्') : _countError,
                onChanged: (_) => setState(() {}),
              ),
              if (diff != null) ...[
                const SizedBox(height: 12),
                _verdict(diff),
              ],
            ],
          ),
        ),
        if (saved.isNotEmpty) ...[
          SectionTitle(context.tr('Past days', 'पछिल्ला दिनहरू')),
          const SizedBox(height: 4),
          ListCard(
            children: [
              for (final s in saved)
                ListRow(
                  leading: IconTile(
                    s.diff == 0 ? Icons.check_rounded : (s.diff < 0 ? Icons.warning_amber_rounded : Icons.info_outline_rounded),
                    tone: s.diff == 0 ? Tone.good : (s.diff < 0 ? Tone.warn : Tone.info),
                  ),
                  title: formatDate(s.day),
                  subtitle: '${context.tr('Counted', 'गनिएको')} ${context.rs(s.counted)}',
                  trailing: PBadge(
                    s.diff == 0
                        ? context.tr('Matched', 'मिल्यो')
                        : s.diff < 0
                            ? context.tr('${context.rs(-s.diff)} short', '${context.rs(-s.diff)} कम')
                            : context.tr('${context.rs(s.diff)} over', '${context.rs(s.diff)} बढी'),
                    tone: s.diff == 0 ? Tone.good : (s.diff < 0 ? Tone.warn : Tone.info),
                  ),
                  onTap: () => _selectDay(s.day),
                ),
            ],
          ),
        ],
        SectionTitle(context.tr('Entries', 'लेनदेन')),
        const SizedBox(height: 4),
        if (data.entries.isEmpty)
          SizedBox(
            height: 260,
            child: EmptyState(
              icon: Icons.receipt_long_rounded,
              title: context.tr('No cash moved on this day', 'यस दिन नगद चलेन'),
              text: context.tr(
                'Payments, supplier payments, refunds and expenses show here.',
                'भुक्तानी, डिलरलाई तिरेको, फिर्ता र खर्च यहाँ देखिन्छ।',
              ),
            ),
          )
        else
          ListCard(
            children: [
              for (final e in data.entries)
                ListRow(
                  leading: IconTile(_kindOf(e.kind).icon, tone: _kindOf(e.kind).tone),
                  title: e.label ?? context.tr(_kindOf(e.kind).en, _kindOf(e.kind).ne),
                  subtitle:
                      '${context.tr(_kindOf(e.kind).en, _kindOf(e.kind).ne)} · ${methodName(context, e.method)} · ${formatTime(e.at)}',
                  amount: context.rs(e.amount),
                  amountTone: e.amount < 0 ? Tone.bad : Tone.good,
                  amountLabel: '${context.tr('Balance', 'बाँकी')} ${context.rs(e.balance)}',
                  chevron: false,
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(cashBookProvider(_day));
    final saved = ref.watch(savedCashCountsProvider);
    final fresh = book.value?.from == _day;
    final expected = book.value?.closingBalance ?? 0;
    final dayChips = <String, String>{
      _today: '${context.tr('Today', 'आज')} · ${formatDate(_today)}',
      addDaysAd(_today, -1): formatDate(addDaysAd(_today, -1)),
      addDaysAd(_today, -2): formatDate(addDaysAd(_today, -2)),
    };

    return PageScaffold(
      title: context.tr('Cash book', 'नगद किताब'),
      bottom: Row(
        children: [
          Expanded(
            flex: 10,
            child: OutlinedButton.icon(
              onPressed: fresh ? () => _openCount(context, expected) : null,
              icon: const Icon(Icons.calculate_rounded),
              label: Text(context.tr('Count cash', 'नगद गन्ने')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 12,
            child: PrimaryButton(
              label: context.tr('Save count', 'गन्ती सेभ गर्ने'),
              icon: Icons.save_rounded,
              onPressed: fresh ? () => _saveDay(expected) : null,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BsDateField(
            label: context.tr('Day', 'दिन'),
            value: _day,
            max: _today,
            onChanged: _selectDay,
          ),
          const SizedBox(height: 10),
          ChipsRow<String>(value: _day, onChanged: _selectDay, options: dayChips),
          const SizedBox(height: 12),
          loadedOr(book, (data) => _content(data, saved), onRetry: () => ref.invalidate(cashBookProvider(_day))),
        ],
      ),
    );
  }
}

({String en, String ne, IconData icon, Tone tone}) _kindOf(String kind) => switch (kind) {
      'payment_in' => (en: 'Received from customer', ne: 'ग्राहकबाट पाइयो', icon: Icons.arrow_downward_rounded, tone: Tone.good),
      'payment_out' => (en: 'Paid to supplier', ne: 'डिलरलाई तिरियो', icon: Icons.arrow_upward_rounded, tone: Tone.info),
      'refund' => (en: 'Refund to customer', ne: 'ग्राहकलाई फिर्ता', icon: Icons.undo_rounded, tone: Tone.warn),
      _ => (en: 'Expense', ne: 'खर्च', icon: Icons.receipt_long_rounded, tone: Tone.bad),
    };

/// The note counter. Pressing "Use this count" hands the total in paisa back to the screen.
class _CountSheet extends StatefulWidget {
  const _CountSheet({required this.expected, required this.onUse});

  final int expected;
  final void Function(int paisa) onUse;

  @override
  State<_CountSheet> createState() => _CountSheetState();
}

class _CountSheetState extends State<_CountSheet> {
  final _counts = List<int>.filled(_notes.length, 0);

  /// Total of the notes, in rupees.
  int get _totalRupees {
    var total = 0;
    for (var i = 0; i < _notes.length; i++) {
      total += _notes[i] * _counts[i];
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final counted = _totalRupees * 100;
    final diff = counted - widget.expected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListCard(
          children: [
            for (var i = 0; i < _notes.length; i++)
              ListRow(
                title: context.rs(_notes[i] * 100),
                subtitle: '${context.tr('Total', 'जम्मा')} ${context.rs(_notes[i] * _counts[i] * 100)}',
                chevron: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: context.tr('Less', 'कम'),
                      onPressed: _counts[i] == 0
                          ? null
                          : () => setState(() {
                                _counts[i]--;
                              }),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(width: 36, child: Text(context.num(_counts[i]), textAlign: TextAlign.center)),
                    IconButton(
                      tooltip: context.tr('More', 'थप'),
                      onPressed: () => setState(() {
                        _counts[i]++;
                      }),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('${context.tr('Expected', 'अपेक्षित')}: ${context.rs(widget.expected)}'),
        Text('${context.tr('Counted total', 'गनिएको जम्मा')}: ${context.rs(counted)}', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        AlertBox(
          diff < 0
              ? context.tr('${context.rs(-diff)} short', '${context.rs(-diff)} कम छ')
              : diff > 0
                  ? context.tr('${context.rs(diff)} over', '${context.rs(diff)} बढी छ')
                  : context.tr('Matches', 'मिल्यो'),
          tone: diff < 0 ? Tone.warn : (diff > 0 ? Tone.info : Tone.good),
          icon: diff == 0 ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: context.tr('Use this count', 'यो गन्ती प्रयोग गर्ने'),
          onPressed: () {
            widget.onUse(counted);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
