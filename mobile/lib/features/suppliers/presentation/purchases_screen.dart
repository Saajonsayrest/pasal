import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/suppliers/data/purchase_math.dart';
import 'package:pasal_mobile/features/suppliers/data/purchase_repository.dart';
import 'package:pasal_mobile/features/suppliers/data/supplier_repository.dart';
import 'package:pasal_mobile/features/suppliers/presentation/pickers.dart';
import 'package:pasal_mobile/features/suppliers/presentation/supplier_widgets.dart';

/// F4. The purchases list: this month's buying, what we still owe, filters and "Load more".
class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final _search = TextEditingController();
  final _debounce = Debouncer();
  String _term = '';
  String _filter = 'all';
  int? _supplierId;
  int _page = 1;

  @override
  void dispose() {
    _search.dispose();
    _debounce.dispose();
    super.dispose();
  }

  PurchaseQuery _query(int page) => (search: _term, filter: _filter, supplierId: _supplierId, page: page);

  /// Any change of search or filter starts again from the first page.
  void _set(VoidCallback change) {
    setState(() {
      change();
      _page = 1;
    });
  }

  void _refresh() {
    ref.invalidate(purchasePageProvider);
    ref.invalidate(purchaseSummaryProvider);
  }

  Future<void> _pickSupplier(List<Supplier> suppliers) async {
    final pick = await showSupplierPicker(context, suppliers: suppliers, allowAll: true);
    if (pick == null || !mounted) return;
    _set(() => _supplierId = pick.supplier?.id);
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(purchaseSummaryProvider);
    final s = summary.value;
    final pages = [for (var p = 1; p <= _page; p++) ref.watch(purchasePageProvider(_query(p)))];
    final first = pages.first;
    final loaded = [for (final p in pages) if (p.hasValue) p.requireValue];
    final rows = [for (final page in loaded) ...page.items];
    final hasMore = loaded.isNotEmpty && loaded.last.meta.hasMore;
    final lastPage = pages.last;
    final loadingMore = _page > 1 && lastPage.isLoading && !lastPage.hasValue;
    final suppliers = ref.watch(allSuppliersProvider).value ?? const <Supplier>[];
    final supplier = findFirst(suppliers, (x) => x.id == _supplierId);
    final filtered = _term.isNotEmpty || _filter != 'all' || _supplierId != null;

    return PageScaffold(
      title: context.tr('Purchases', 'खरिदहरू'),
      scroll: false,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push('/purchases/new'),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text(context.tr('New purchase', 'नयाँ खरिद')),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: PCard(
                    child: StatBlock(
                      label: context.tr("This month's purchases", 'यो महिनाको खरिद'),
                      value: context.rs(s?.monthTotal ?? 0),
                      sub: s == null ? null : '${context.num(s.monthCount)} ${context.plural(s.monthCount, 'bill', 'bills', 'बिल')}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PCard(
                    child: StatBlock(
                      label: context.tr('Still to pay', 'अझै तिर्नुपर्ने'),
                      value: context.rs(s?.owed ?? 0),
                      tone: Tone.warn,
                      sub: s == null ? null : context.tr('on ${context.num(s.openCount)} bills', '${context.num(s.openCount)} बिलमा'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ChipsRow<String>(
              value: _filter,
              onChanged: (v) => _set(() => _filter = v),
              options: {
                'all': context.tr('All', 'सबै'),
                'unpaid': context.tr('Unpaid', 'बाँकी'),
                'month': context.tr('This month', 'यो महिना'),
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: context.tr('Search bill or supplier', 'बिल वा डिलर खोज्नुहोस्'),
              ),
              onChanged: (v) => _debounce.run(() => _set(() => _term = v.trim())),
            ),
            const SizedBox(height: 12),
            ListCard(
              children: [
                ListRow(
                  leading: const IconTile(Icons.storefront_rounded, tone: Tone.info),
                  title: supplier?.name ?? context.tr('All suppliers', 'सबै डिलर'),
                  subtitle: context.tr('Supplier', 'डिलर'),
                  onTap: () => _pickSupplier(suppliers),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (first.hasError && !first.hasValue)
              SizedBox(
                height: 320,
                child: ErrorView(error: first.error!, onRetry: () => ref.invalidate(purchasePageProvider(_query(1)))),
              )
            else if (!first.hasValue)
              const SkeletonList()
            else if (rows.isEmpty)
              SizedBox(
                height: 360,
                child: EmptyState(
                  icon: Icons.shopping_bag_rounded,
                  title: filtered ? context.tr('No purchases found', 'खरिद भेटिएन') : context.tr('No purchases yet', 'अहिलेसम्म खरिद छैन'),
                  text: context.tr('Record a bill when stock comes in from a supplier.', 'डिलरबाट सामान आउँदा बिल लेख्नुहोस्।'),
                  actionLabel: context.tr('New purchase', 'नयाँ खरिद'),
                  onAction: () => context.push('/purchases/new'),
                ),
              )
            else ...[
              ListCard(
                children: [
                  for (final p in rows)
                    ListRow(
                      leading: AvatarCircle(p.supplier?.name ?? '?', tone: p.balance > 0 ? Tone.info : Tone.good),
                      title: p.supplier?.name ?? context.tr('Deleted supplier', 'हटाइएको डिलर'),
                      subtitle: '${p.billNo ?? context.tr('No bill number', 'बिल नम्बर छैन')} · ${billDateText(p.billDate, p.boughtAt)}',
                      amount: context.rs(p.total),
                      amountLabel: p.balance > 0
                          ? context.tr('We owe ${context.rs(p.balance)}', 'हामीले तिर्ने ${context.rs(p.balance)}')
                          : context.tr('Paid', 'तिरेको'),
                      amountTone: p.balance > 0 ? Tone.warn : Tone.good,
                      onTap: () => context.push('/purchases/${p.id}'),
                    ),
                ],
              ),
              if (_page > 1 && lastPage.hasError && !lastPage.hasValue) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ErrorView(error: lastPage.error!, onRetry: () => ref.invalidate(purchasePageProvider(_query(_page)))),
                ),
              ],
              if (hasMore || loadingMore) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: loadingMore ? null : () => setState(() => _page += 1),
                  child: Text(loadingMore ? context.tr('Loading…', 'लोड हुँदैछ…') : context.tr('Load more', 'अरु हेर्ने')),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
