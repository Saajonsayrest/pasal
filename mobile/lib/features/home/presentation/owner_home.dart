import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/home/data/home_prefs.dart';
import 'package:pasal_mobile/features/home/data/home_repository.dart';
import 'package:pasal_mobile/features/home/data/vat_period.dart';
import 'package:pasal_mobile/features/home/presentation/home_widgets.dart';

/// Owner home. Every card loads on its own, so one slow answer does not hold up the others.
/// The owner can move the cards up and down. The order is saved on the phone.
class OwnerHome extends ConsumerStatefulWidget {
  const OwnerHome({super.key});

  @override
  ConsumerState<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends ConsumerState<OwnerHome> {
  bool _editing = false;

  Future<void> _refresh() async {
    ref
      ..invalidate(todaySalesProvider)
      ..invalidate(moneyInTodayProvider)
      ..invalidate(customersOweProvider)
      ..invalidate(weOweProvider)
      ..invalidate(lowStockCountProvider)
      ..invalidate(vatPreviewProvider)
      ..invalidate(weekDaysProvider)
      ..invalidate(monthSummaryProvider)
      ..invalidate(recentSalesProvider);
  }

  Widget _card(HomeCard card) {
    return switch (card) {
      HomeCard.sales => const _SalesHero(),
      HomeCard.cash => const _CashCard(),
      HomeCard.collect => const _CollectCard(),
      HomeCard.owe => const _OweCard(),
      HomeCard.low => const _LowStockCard(),
      HomeCard.vat => const _VatCard(),
      HomeCard.week => const _WeekCard(),
      HomeCard.profit => const _ProfitCard(),
    };
  }

  Widget _editBar(int index, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: context.tr('Move up', 'माथि सार्ने'),
          onPressed: index == 0 ? null : () => ref.read(homeOrderProvider.notifier).move(index, -1),
          icon: const Icon(Icons.arrow_upward_rounded),
        ),
        IconButton(
          tooltip: context.tr('Move down', 'तल सार्ने'),
          onPressed: index == count - 1 ? null : () => ref.read(homeOrderProvider.notifier).move(index, 1),
          icon: const Icon(Icons.arrow_downward_rounded),
        ),
      ],
    );
  }

  /// Narrow cards go two in a row. A wide card takes a whole row.
  Widget _cards(List<HomeCard> order) {
    final rows = <Widget>[];
    var i = 0;
    while (i < order.length) {
      final first = order[i];
      final pairs = !first.wide && i + 1 < order.length && !order[i + 1].wide;
      if (pairs) {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _slot(order, i)),
              const SizedBox(width: 12),
              Expanded(child: _slot(order, i + 1)),
            ],
          ),
        );
        i += 2;
      } else if (first.wide) {
        rows.add(_slot(order, i));
        i += 1;
      } else {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: _slot(order, i)), const SizedBox(width: 12), const Expanded(child: SizedBox())],
          ),
        );
        i += 1;
      }
    }
    return Column(
      children: [
        for (final row in rows) Padding(padding: const EdgeInsets.only(bottom: 12), child: row),
      ],
    );
  }

  Widget _slot(List<HomeCard> order, int index) {
    final card = _card(order[index]);
    if (!_editing) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_editBar(index, order.length), card],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    final name = user?.name ?? '';
    final first = name.split(' ').first;
    final order = ref.watch(homeOrderProvider);
    final today = todayAd();

    return PageScaffold(
      title: context.tr('Namaste, $first', 'नमस्ते, $first'),
      onRefresh: _refresh,
      actions: [
        IconButton(
          tooltip: context.tr('Notifications', 'सूचनाहरू'),
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_rounded),
        ),
        IconButton(
          tooltip: context.tr('Profile', 'प्रोफाइल'),
          onPressed: () => context.push('/profile'),
          icon: AvatarCircle(name, size: 34),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              '${weekday(today)}, ${formatDate(today)} · ${formatDateSub(today)}',
              style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ),
          const _QuickActions(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(context.tr('Your cards', 'तपाईंका कार्ड'), style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant)),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _editing = !_editing),
                icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded, size: 18),
                label: Text(_editing ? context.tr('Done', 'भयो') : context.tr('Edit', 'सम्पादन')),
              ),
            ],
          ),
          _cards(order),
          SectionHeader(
            context.tr('Recent sales', 'भर्खरका बिक्री'),
            action: context.tr('See all', 'सबै'),
            onAction: () => context.push('/sales'),
          ),
          const SizedBox(height: 8),
          const _RecentSales(),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <({IconData icon, String en, String ne, String path})>[
      (icon: Icons.add_shopping_cart_rounded, en: 'New sale', ne: 'नयाँ बिक्री', path: '/sell'),
      (icon: Icons.add_box_rounded, en: 'Add item', ne: 'सामान थप्ने', path: '/items/new'),
      (icon: Icons.call_received_rounded, en: 'Take payment', ne: 'पैसा लिने', path: '/customers'),
      (icon: Icons.payments_rounded, en: 'Add expense', ne: 'खर्च थप्ने', path: '/expenses/new'),
    ];
    return Row(
      children: [
        for (final action in actions)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: () => context.push(action.path),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: context.scheme.primaryContainer, shape: BoxShape.circle),
                      child: Icon(action.icon, color: context.scheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(action.en, action.ne),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SalesHero extends ConsumerWidget {
  const _SalesHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(todaySalesProvider);
    final value = sales.value;
    return HeroCard(
      child: value == null
          ? (sales.hasError ? CardError(onRetry: () => ref.invalidate(todaySalesProvider)) : const CardLoading())
          : Row(
              children: [
                Expanded(
                  child: StatBlock(
                    label: context.tr("Today's sales", 'आजको बिक्री'),
                    value: context.rs(value.total),
                    large: true,
                  ),
                ),
                PBadge('${context.num(value.bills)} ${context.tr('bills', 'बिल')}'),
              ],
            ),
    );
  }
}

/// A card with one number. Shows loading and error states on its own.
class _StatCard<T> extends StatelessWidget {
  const _StatCard({required this.state, required this.onRetry, required this.onTap, required this.icon, required this.tone, required this.text});

  final AsyncValue<T> state;
  final VoidCallback onRetry;
  final VoidCallback onTap;
  final IconData icon;
  final Tone tone;
  final ({String label, String value, String? sub}) Function(T data) text;

  @override
  Widget build(BuildContext context) {
    final data = state.value;
    return PCard(
      onTap: data == null ? null : onTap,
      child: data == null
          ? (state.hasError ? CardError(onRetry: onRetry) : const CardLoading())
          : Row(
              children: [
                IconTile(icon, tone: tone, size: 44),
                const SizedBox(width: 12),
                Expanded(child: _content(text(data))),
              ],
            ),
    );
  }

  Widget _content(({String label, String value, String? sub}) t) =>
      StatBlock(label: t.label, value: t.value, sub: t.sub);
}

class _CashCard extends ConsumerWidget {
  const _CashCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StatCard<int>(
      state: ref.watch(moneyInTodayProvider),
      onRetry: () => ref.invalidate(moneyInTodayProvider),
      onTap: () => context.push('/cash-book'),
      icon: Icons.account_balance_wallet_rounded,
      tone: Tone.good,
      text: (v) => (label: context.tr('Money received today', 'आज प्राप्त रकम'), value: context.rs(v), sub: null),
    );
  }
}

class _CollectCard extends ConsumerWidget {
  const _CollectCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StatCard<OwedToUs>(
      state: ref.watch(customersOweProvider),
      onRetry: () => ref.invalidate(customersOweProvider),
      onTap: () => context.push('/customers'),
      icon: Icons.call_received_rounded,
      tone: Tone.warn,
      text: (v) => (
        label: context.tr('To collect', 'उठाउन बाँकी'),
        value: context.rs(v.owed),
        sub: context.tr('from ${context.num(v.customers)} customers', '${context.num(v.customers)} ग्राहकबाट'),
      ),
    );
  }
}

class _OweCard extends ConsumerWidget {
  const _OweCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StatCard<int>(
      state: ref.watch(weOweProvider),
      onRetry: () => ref.invalidate(weOweProvider),
      onTap: () => context.push('/suppliers'),
      icon: Icons.call_made_rounded,
      tone: Tone.info,
      text: (v) => (label: context.tr('We owe', 'हामीले तिर्न बाँकी'), value: context.rs(v), sub: context.tr('to suppliers', 'डिलरलाई')),
    );
  }
}

class _LowStockCard extends ConsumerWidget {
  const _LowStockCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StatCard<int>(
      state: ref.watch(lowStockCountProvider),
      onRetry: () => ref.invalidate(lowStockCountProvider),
      onTap: () => context.push('/low-stock'),
      icon: Icons.production_quantity_limits_rounded,
      tone: Tone.warn,
      text: (v) => (label: context.tr('Items low on stock', 'कम स्टकका सामान'), value: context.num(v), sub: null),
    );
  }
}

class _VatCard extends ConsumerWidget {
  const _VatCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = nextVatPeriod();
    final preview = ref.watch(vatPreviewProvider);
    final value = preview.value;
    final amount = value != null
        ? context.rs(value.payable)
        : preview.hasError
            ? '-'
            : '…';
    return PCard(
      onTap: () => context.push('/vat'),
      child: Row(
        children: [
          IconTile(Icons.receipt_long_rounded, tone: Tone.info, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: StatBlock(
              label: '${monthTitle(period.year, period.month)} ${context.tr('VAT to pay', 'भ्याट तिर्नुपर्ने')}',
              value: amount,
              sub: '${formatDate(period.due)} · ${dueLabel(context, period.daysLeft)}',
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends ConsumerWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weekDaysProvider);
    final days = week.value;
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(context.tr('Last 7 days', 'पछिल्लो ७ दिन'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              TextButton(onPressed: () => context.push('/reports/sales'), child: Text(context.tr('See all', 'सबै हेर्ने'))),
            ],
          ),
          if (days == null)
            week.hasError ? CardError(onRetry: () => ref.invalidate(weekDaysProvider)) : const CardLoading()
          else
            _WeekBody(days: days),
        ],
      ),
    );
  }
}

class _WeekBody extends StatelessWidget {
  const _WeekBody({required this.days});

  final List<DayTotal> days;

  @override
  Widget build(BuildContext context) {
    final split = days.length > 7 ? days.length - 7 : 0;
    final last7 = days.sublist(split);
    final before = days.sublist(0, split);
    final lastTotal = last7.fold<int>(0, (sum, d) => sum + d.sales);
    final beforeTotal = before.fold<int>(0, (sum, d) => sum + d.sales);
    final change = beforeTotal > 0 ? ((lastTotal - beforeTotal) * 100 / beforeTotal).round() : null;
    final peak = last7.fold<int>(1, (max, d) => d.sales > max ? d.sales : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(context.rs(lastTotal), style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
            if (change != null)
              PBadge(
                '${change >= 0 ? '↑' : '↓'} ${context.num(change.abs())}%',
                tone: change >= 0 ? Tone.good : Tone.bad,
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < last7.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: (last7[i].sales / peak).clamp(0.03, 1.0).toDouble(),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: i == last7.length - 1 ? context.scheme.primary : context.scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          i == last7.length - 1 ? context.tr('Today', 'आज') : shortWeekday(context, last7[i].date),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfitCard extends ConsumerWidget {
  const _ProfitCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    final s = summary.value;
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(context.tr('Profit this month', 'यो महिनाको नाफा'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              TextButton(onPressed: () => context.push('/reports'), child: Text(context.tr('Report', 'रिपोर्ट'))),
            ],
          ),
          if (s == null)
            summary.hasError ? CardError(onRetry: () => ref.invalidate(monthSummaryProvider)) : const CardLoading()
          else
            _ProfitBody(summary: s),
        ],
      ),
    );
  }
}

class _ProfitBody extends StatelessWidget {
  const _ProfitBody({required this.summary});

  final Summary summary;

  @override
  Widget build(BuildContext context) {
    final raw = summary.salesTotal > 0 ? (summary.profit * 100 / summary.salesTotal).round() : 0;
    final share = raw.clamp(0, 100).toInt();
    return Row(
      children: [
        SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: share / 100,
                strokeWidth: 10,
                backgroundColor: context.scheme.surfaceContainerHighest,
              ),
              Text('${context.num(share)}%', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Legend(color: context.scheme.primary, text: '${context.tr('Profit', 'नाफा')} · ${context.rs(summary.profit)}'),
              const SizedBox(height: 6),
              _Legend(color: context.scheme.outline, text: '${context.tr('Cost of goods', 'सामानको लागत')} · ${context.rs(summary.costOfGoods)}'),
              const SizedBox(height: 6),
              _Legend(color: context.colors.warn, text: '${context.tr('Expenses', 'खर्च')} · ${context.rs(summary.expensesTotal)}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: context.text.bodySmall)),
      ],
    );
  }
}

class _RecentSales extends ConsumerWidget {
  const _RecentSales();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSalesProvider);
    return AsyncBody<List<Sale>>(
      value: recent,
      onRetry: () => ref.invalidate(recentSalesProvider),
      data: (sales) {
        if (sales.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_rounded,
            title: context.tr('No sales yet', 'अहिलेसम्म बिक्री छैन'),
            text: context.tr('Your first bill will show here.', 'पहिलो बिल यहाँ देखिनेछ।'),
          );
        }
        return ListCard(children: [for (final sale in sales) RecentSaleRow(sale: sale)]);
      },
    );
  }
}
