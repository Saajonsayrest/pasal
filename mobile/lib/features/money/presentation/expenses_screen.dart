import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/bs_date.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/money/data/money_repository.dart';
import 'package:pasal_mobile/features/money/presentation/money_labels.dart';

/// G1. Expenses of one Nepali month: total, split by category, then the rows by day.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  late int _year;
  late int _month;

  /// Category key shown alone, or null for every category.
  String? _picked;

  @override
  void initState() {
    super.initState();
    final now = todayBs();
    _year = now.year;
    _month = now.month;
  }

  void _openAdd() => context.push('/expenses/new');

  Widget _body(BuildContext context, List<Expense> rows) {
    final total = rows.fold<int>(0, (sum, e) => sum + e.amount);
    final monthLabel = monthTitle(_year, _month);

    if (rows.isEmpty) {
      return SizedBox(
        height: 420,
        child: EmptyState(
          icon: Icons.receipt_long_rounded,
          title: context.tr('No expenses this month', 'यो महिनामा खर्च छैन'),
          text: context.tr('Add what you spent, like rent or electricity.', 'भाडा वा बिजुली जस्ता खर्च थप्नुहोस्।'),
          actionLabel: context.tr('Add expense', 'खर्च थप्ने'),
          onAction: _openAdd,
        ),
      );
    }

    final totals = <String, int>{};
    for (final e in rows) {
      final key = categoryKey(e.category);
      totals[key] = (totals[key] ?? 0) + e.amount;
    }
    final cats = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final shown = _picked == null ? rows : rows.where((e) => categoryKey(e.category) == _picked).toList();
    final shownTotal = shown.fold<int>(0, (sum, e) => sum + e.amount);
    final days = <String, List<Expense>>{};
    for (final e in shown) {
      days.putIfAbsent(adDayOf(e.spentAt), () => []).add(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          child: StatBlock(
            large: true,
            label: context.tr('$monthLabel expenses', '$monthLabel को खर्च'),
            value: context.rs(total),
            sub: '${context.num(rows.length)} ${context.plural(rows.length, 'entry', 'entries', 'खर्च')}',
          ),
        ),
        const SizedBox(height: 12),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(context.tr('Where it went', 'खर्च कहाँ गयो')),
              const SizedBox(height: 8),
              for (final c in cats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(categoryName(context, c.key), style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
                          Text(context.rs(c.value), style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: total == 0 ? 0 : c.value / total, borderRadius: BorderRadius.circular(8)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ChipsRow<String?>(
          value: _picked,
          onChanged: (v) => setState(() => _picked = v),
          options: {
            null: context.tr('All', 'सबै'),
            for (final c in cats) c.key: categoryName(context, c.key),
          },
        ),
        if (_picked != null) ...[
          const SizedBox(height: 8),
          Text('${categoryName(context, _picked!)}: ${context.rs(shownTotal)}', style: context.text.bodySmall),
        ],
        const SizedBox(height: 8),
        for (final day in days.keys) ...[
          SectionTitle(day == todayAd() ? '${context.tr('Today', 'आज')} · ${formatDate(day)}' : formatDate(day)),
          const SizedBox(height: 4),
          ListCard(
            children: [
              for (final e in days[day]!)
                ListRow(
                  leading: IconTile(categoryIcon(categoryKey(e.category)), tone: Tone.neutral),
                  title: e.title,
                  subtitle: categoryName(context, categoryKey(e.category)),
                  amount: context.rs(e.amount),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = bsMonthRange(_year, _month);
    final data = ref.watch(expensesProvider(range));

    return PageScaffold(
      title: context.tr('Expenses', 'खर्चहरू'),
      onRefresh: () async => ref.invalidate(expensesProvider(range)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _openAdd,
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('Add expense', 'खर्च थप्ने')),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonthNav(
            year: _year,
            month: _month,
            onChanged: (y, m) => setState(() {
              _year = y;
              _month = m;
              _picked = null;
            }),
          ),
          const SizedBox(height: 4),
          loadedOr(data, (rows) => _body(context, rows), onRetry: () => ref.invalidate(expensesProvider(range))),
        ],
      ),
    );
  }
}
