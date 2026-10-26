import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/launch.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/home/data/home_repository.dart';
import 'package:pasal_mobile/features/home/presentation/home_widgets.dart';

/// Staff home: a big "New sale" button, the person's own sales today, customers to remind and low
/// stock. Staff never see buying prices or profit here.
class StaffHome extends ConsumerWidget {
  const StaffHome({super.key});

  Future<void> _refresh(WidgetRef ref, String name) async {
    ref
      ..invalidate(myTodayProvider(name))
      ..invalidate(remindProvider)
      ..invalidate(lowStockItemsProvider)
      ..invalidate(recentSalesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionProvider).user?.name ?? '';
    final first = name.split(' ').first;

    return PageScaffold(
      title: context.tr('Namaste, $first', 'नमस्ते, $first'),
      onRefresh: () => _refresh(ref, name),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(Radii.xl),
            onTap: () => context.push('/sell'),
            child: HeroCard(
              child: Row(
                children: [
                  Expanded(
                    child: StatBlock(
                      label: context.tr('For the next customer', 'अर्को ग्राहकलाई'),
                      value: context.tr('New sale', 'नयाँ बिक्री'),
                      large: true,
                    ),
                  ),
                  const IconTile(Icons.add_shopping_cart_rounded, size: 52),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MyToday(name: name),
          SectionHeader(
            context.tr('Customers to remind', 'सम्झाउनुपर्ने ग्राहक'),
            action: context.tr('See all', 'सबै'),
            onAction: () => context.push('/customers'),
          ),
          const _Reminders(),
          SectionHeader(
            context.tr('Low stock', 'कम स्टक'),
            action: context.tr('See all', 'सबै'),
            onAction: () => context.push('/low-stock'),
          ),
          const _LowStock(),
          SectionHeader(context.tr('My recent sales', 'मेरा भर्खरका बिक्री')),
          _MyRecent(name: name),
        ],
      ),
    );
  }
}

class _MyToday extends ConsumerWidget {
  const _MyToday({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myTodayProvider(name));
    final today = mine.value;
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('My sales today', 'आजको मेरो बिक्री'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (today == null)
            mine.hasError ? CardError(onRetry: () => ref.invalidate(myTodayProvider(name))) : const CardLoading()
          else
            Row(
              children: [
                Expanded(child: StatBlock(label: context.tr('Total amount', 'जम्मा रकम'), value: context.rs(today.total))),
                Expanded(child: StatBlock(label: context.tr('Bills', 'बिल'), value: context.num(today.bills))),
              ],
            ),
        ],
      ),
    );
  }
}

class _Reminders extends ConsumerWidget {
  const _Reminders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remind = ref.watch(remindProvider);
    return AsyncBody<List<Customer>>(
      value: remind,
      onRetry: () => ref.invalidate(remindProvider),
      data: (customers) {
        if (customers.isEmpty) {
          return EmptyState(icon: Icons.done_all_rounded, title: context.tr('No one owes money', 'कसैको उधारो बाँकी छैन'));
        }
        return ListCard(
          children: [
            for (final c in customers)
              ListRow(
                leading: AvatarCircle(c.name),
                title: c.name,
                subtitle: context.tr('To collect', 'उठाउन बाँकी'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.rs(c.owes), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    if (c.phone != null)
                      IconButton(
                        tooltip: context.tr('Call', 'फोन गर्ने'),
                        onPressed: () => callPhone(context, c.phone!),
                        icon: const Icon(Icons.call_rounded),
                      ),
                    IconButton(
                      tooltip: context.tr('Remind', 'सम्झाउने'),
                      onPressed: () => context.push('/customers/${c.id}/remind'),
                      icon: const Icon(Icons.notifications_active_rounded),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LowStock extends ConsumerWidget {
  const _LowStock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final low = ref.watch(lowStockItemsProvider);
    return AsyncBody<LowStock>(
      value: low,
      onRetry: () => ref.invalidate(lowStockItemsProvider),
      data: (lowStock) => ListCard(
        children: [
          for (final item in lowStock.items)
            ListRow(
              leading: const IconTile(Icons.production_quantity_limits_rounded, tone: Tone.warn, size: 44),
              title: item.name,
              subtitle: context.tr('Only ${context.num(item.quantity)} ${item.unit} left', 'मात्र ${context.num(item.quantity)} ${item.unit} बाँकी'),
              chevron: false,
            ),
          if (lowStock.count > lowStock.items.length)
            ListRow(
              leading: const IconTile(Icons.more_horiz_rounded, size: 44),
              title: context.tr('${context.num(lowStock.count - lowStock.items.length)} more items', 'अरू ${context.num(lowStock.count - lowStock.items.length)} सामान'),
              subtitle: context.tr('Their stock is low too', 'यिनीहरूको स्टक पनि कम छ'),
              onTap: () => context.push('/low-stock'),
            ),
          if (lowStock.items.isEmpty) ListRow(title: context.tr('No low stock', 'कम स्टक छैन'), chevron: false),
        ],
      ),
    );
  }
}

class _MyRecent extends ConsumerWidget {
  const _MyRecent({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myTodayProvider(name));
    return AsyncBody<MyToday>(
      value: mine,
      onRetry: () => ref.invalidate(myTodayProvider(name)),
      data: (today) {
        if (today.recent.isEmpty) {
          return EmptyState(icon: Icons.receipt_rounded, title: context.tr('No sales yet today', 'आज अहिलेसम्म बिक्री छैन'));
        }
        return ListCard(children: [for (final sale in today.recent) RecentSaleRow(sale: sale)]);
      },
    );
  }
}
