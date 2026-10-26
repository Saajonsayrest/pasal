import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/suppliers/data/supplier_repository.dart';

/// F1. The suppliers list: what we owe in total, search, and a filter for the suppliers we still owe.
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _search = TextEditingController();
  final _debounce = Debouncer();
  String _term = '';
  bool _owedOnly = false;

  @override
  void dispose() {
    _search.dispose();
    _debounce.dispose();
    super.dispose();
  }

  String _lastPurchase(BuildContext context, Supplier s) {
    if (s.lastPurchaseAt == null) return context.tr('No purchases yet', 'खरिद छैन');
    final day = formatDate(s.lastPurchaseAt!);
    return context.tr('Last purchase: $day', 'अन्तिम खरिद: $day');
  }

  @override
  Widget build(BuildContext context) {
    final query = (search: _term, owedOnly: _owedOnly);
    final data = ref.watch(suppliersProvider(query));
    final list = data.value;

    return PageScaffold(
      title: context.tr('Suppliers', 'डिलरहरू'),
      scroll: false,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push('/suppliers/new'),
        icon: const Icon(Icons.add_business_rounded),
        label: Text(context.tr('Add supplier', 'डिलर थप्ने')),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(suppliersProvider(query)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            HeroCard(
              tone: Tone.warn,
              child: StatBlock(
                large: true,
                tone: Tone.warn,
                label: context.tr('We owe', 'हामीले तिर्न बाँकी'),
                value: context.rs(list?.owedTotal ?? 0),
                sub: context.tr('Across all suppliers', 'सबै डिलरमा'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: context.tr('Search supplier name or phone', 'डिलरको नाम वा फोन खोज्नुहोस्'),
              ),
              onChanged: (v) => _debounce.run(() => setState(() => _term = v.trim())),
            ),
            const SizedBox(height: 12),
            ChipsRow<bool>(
              value: _owedOnly,
              onChanged: (v) => setState(() => _owedOnly = v),
              options: {
                false: context.tr('All', 'सबै'),
                true: context.tr('We owe', 'हामीले तिर्ने'),
              },
            ),
            const SizedBox(height: 12),
            if (data.hasError && !data.hasValue)
              ErrorView(error: data.error!, onRetry: () => ref.invalidate(suppliersProvider(query)))
            else if (list == null)
              const SkeletonList()
            else if (list.suppliers.isEmpty)
              SizedBox(
                height: 420,
                child: EmptyState(
                  icon: Icons.storefront_rounded,
                  title: _term.isEmpty && !_owedOnly
                      ? context.tr('No suppliers yet', 'अहिलेसम्म डिलर छैन')
                      : context.tr('No suppliers found', 'डिलर भेटिएन'),
                  text: context.tr('Add the shops and dealers you buy stock from.', 'सामान किन्ने पसल वा डिलर थप्नुहोस्।'),
                  actionLabel: context.tr('Add supplier', 'डिलर थप्ने'),
                  onAction: () => context.push('/suppliers/new'),
                ),
              )
            else
              ListCard(
                children: [
                  for (final s in list.suppliers)
                    ListRow(
                      leading: AvatarCircle(s.name, tone: (s.weOwe ?? 0) > 0 ? Tone.info : Tone.good),
                      title: s.name,
                      subtitle: '${s.phone == null ? '' : '${s.phone} · '}${_lastPurchase(context, s)}',
                      amount: context.rs(s.weOwe ?? 0),
                      amountTone: (s.weOwe ?? 0) > 0 ? Tone.warn : Tone.neutral,
                      amountLabel: (s.weOwe ?? 0) > 0 ? context.tr('We owe', 'हामीले तिर्ने') : context.tr('Paid up', 'सबै चुक्ता'),
                      onTap: () => context.push('/suppliers/${s.id}'),
                    ),
                ],
              ),
            if (list != null && list.total > list.suppliers.length) ...[
              const SizedBox(height: 12),
              Text(
                context.tr(
                  'Showing ${context.num(list.suppliers.length)} of ${context.num(list.total)}. Search to find the others.',
                  '${context.num(list.total)} मध्ये ${context.num(list.suppliers.length)} देखाइएको। बाँकी खोज्न नाम लेख्नुहोस्।',
                ),
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
