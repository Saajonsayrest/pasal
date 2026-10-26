import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/customers/data/customer_repository.dart';

/// Tab 4. The customers list: total to collect, search, filters, sort. Reference screen for list pages.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _search = TextEditingController();
  final _debounce = Debouncer();
  String _term = '';
  String _filter = 'all';
  String _sort = 'owed';

  @override
  void dispose() {
    _search.dispose();
    _debounce.dispose();
    super.dispose();
  }

  String _lastBill(BuildContext context, Customer c) {
    if (c.lastSaleAt == null) return context.tr('No bills yet', 'बिल छैन');
    final days = -daysUntil(adOfStamp(c.lastSaleAt!));
    if (days <= 0) return context.tr('last bill today', 'अन्तिम बिल आज');
    if (days == 1) return context.tr('last bill yesterday', 'अन्तिम बिल हिजो');
    return context.tr('last bill $days days ago', 'अन्तिम बिल ${context.num(days)} दिन अघि');
  }

  @override
  Widget build(BuildContext context) {
    final query = (search: _term, filter: _filter, sort: _sort);
    final data = ref.watch(customersProvider(query));

    return PageScaffold(
      title: context.tr('Customers', 'ग्राहकहरू'),
      scroll: false,
      onRefresh: null,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push('/customers/new'),
        icon: const Icon(Icons.person_add_rounded),
        label: Text(context.tr('Add customer', 'ग्राहक थप्ने')),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(customersProvider(query)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            HeroCard(
              tone: Tone.warn,
              child: StatBlock(
                large: true,
                tone: Tone.warn,
                label: context.tr('To collect', 'उठाउन बाँकी'),
                value: context.rs(data.value?.owedTotal ?? 0),
                sub: context.tr('from ${data.value?.owingCustomers ?? 0} customers', '${context.num(data.value?.owingCustomers ?? 0)} ग्राहकबाट'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: context.tr('Search name or phone', 'नाम वा फोन खोज्नुहोस्'),
              ),
              onChanged: (v) => _debounce.run(() => setState(() => _term = v.trim())),
            ),
            const SizedBox(height: 12),
            ChipsRow<String>(
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
              options: {
                'all': context.tr('All', 'सबै'),
                'owes': context.tr('Owes money', 'बाँकी छ'),
                'over_limit': context.tr('Over limit', 'सीमा नाघेको'),
                'paid_up': context.tr('Paid up', 'सबै चुक्ता'),
              },
            ),
            const SizedBox(height: 12),
            Seg<String>(
              value: _sort,
              onChanged: (v) => setState(() => _sort = v),
              options: {
                'owed': context.tr('Most owed', 'सबैभन्दा बढी बाँकी'),
                'name': context.tr('Name', 'नाम'),
                'oldest': context.tr('Oldest', 'सबैभन्दा पुरानो'),
              },
            ),
            const SizedBox(height: 12),
            if (data.hasError && !data.hasValue)
              ErrorView(error: data.error!, onRetry: () => ref.invalidate(customersProvider(query)))
            else if (!data.hasValue)
              const SkeletonList()
            else if (data.requireValue.customers.isEmpty)
              SizedBox(
                height: 420,
                child: EmptyState(
                  icon: Icons.group_rounded,
                  title: context.tr('No customers found', 'ग्राहक भेटिएन'),
                  text: context.tr('Add your first customer to start keeping credit (udhar).', 'उधारो राख्न पहिलो ग्राहक थप्नुहोस्।'),
                  actionLabel: context.tr('Add customer', 'ग्राहक थप्ने'),
                  onAction: () => context.push('/customers/new'),
                ),
              )
            else
              ListCard(
                children: [
                  for (final c in data.requireValue.customers)
                    ListRow(
                      leading: AvatarCircle(c.name, tone: (c.owes ?? 0) > 0 ? Tone.warn : Tone.good),
                      title: c.name,
                      subtitle: '${c.phone == null ? '' : '${c.phone} · '}${_lastBill(context, c)}',
                      amount: (c.owes ?? 0) > 0 ? context.rs(c.owes) : context.rs(0),
                      amountTone: (c.owes ?? 0) > 0 ? Tone.warn : Tone.neutral,
                      amountLabel: (c.owes ?? 0) > 0 ? context.tr('To collect', 'उठाउन बाँकी') : context.tr('Paid up', 'सबै चुक्ता'),
                      onTap: () => context.push('/customers/${c.id}'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
