import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/items/data/item_providers.dart';
import 'package:pasal_mobile/features/items/data/item_repository.dart';
import 'package:pasal_mobile/features/items/presentation/item_widgets.dart';

const _viewPrefKey = 'pasal_items_view';
const _allChip = 'all';
const _lowChip = 'low';

/// Tab 2. The items list: search, scan, category and low stock chips, list or grid view.
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  final _search = TextEditingController();
  final _debounce = Debouncer();
  String _term = '';

  /// `all`, `low`, or `cat:<id>`.
  String _chip = _allChip;
  bool _grid = false;

  /// Pages after the first one. Cleared when the search or a chip changes.
  final List<Item> _more = [];
  int _page = 1;
  bool _loadingMore = false;
  ApiException? _moreError;

  @override
  void initState() {
    super.initState();
    _grid = ref.read(sharedPrefsProvider).getString(_viewPrefKey) == 'grid';
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce.dispose();
    super.dispose();
  }

  ItemQuery get _query => (
        search: _term,
        categoryId: _chip.startsWith('cat:') ? int.tryParse(_chip.substring(4)) : null,
        lowStock: _chip == _lowChip,
      );

  void _resetPaging() {
    _more.clear();
    _page = 1;
    _moreError = null;
  }

  void _changeQuery(VoidCallback change) {
    setState(() {
      change();
      _resetPaging();
    });
  }

  void _setView(bool grid) {
    setState(() => _grid = grid);
    ref.read(sharedPrefsProvider).setString(_viewPrefKey, grid ? 'grid' : 'list');
  }

  Future<void> _loadMore(ItemQuery query) async {
    final next = _page + 1;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    final res = await guard(
      () => ref.read(itemRepositoryProvider).list(query, page: next),
      onError: (e) => _moreError = e,
    );
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (res != null && query == _query) {
        _more.addAll(res.items);
        _page = next;
      }
    });
  }

  Future<void> _refresh(ItemQuery query) async {
    setState(_resetPaging);
    ref.invalidate(itemListProvider(query));
    ref.invalidate(lowStockCountProvider);
    try {
      await ref.read(itemListProvider(query).future);
    } catch (_) {
      // The error view on the screen shows the problem and offers a retry.
    }
  }

  Future<void> _scan() async {
    final code = await context.push<String>('/items/scan');
    if (!mounted || code == null || code.isEmpty) return;
    await _openByCode(code);
  }

  Future<void> _openByCode(String code) async {
    try {
      final page = await ref.read(itemRepositoryProvider).list((search: code, categoryId: null, lowStock: false), perPage: 50);
      if (!mounted) return;
      final hit = _itemWithSku(page.items, code);
      if (hit == null) {
        showProblem(context, context.tr('No item has the code $code', '$code कोड भएको सामान छैन'));
        return;
      }
      context.push('/items/${hit.id}');
    } on ApiException catch (e) {
      if (mounted) showProblem(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final owner = ref.watch(sessionProvider).isOwner;
    final list = ref.watch(itemListProvider(query));
    final low = ref.watch(lowStockCountProvider);
    final categories = ref.watch(itemCategoriesProvider).value ?? const <Category>[];
    final stockValue = owner ? ref.watch(stockValueProvider).value : null;

    final first = list.value;
    final rows = [...?first?.items, ..._more];
    final total = first?.meta.total ?? 0;
    final hasMore = rows.length < total;
    final filtered = _term.isNotEmpty || _chip != _allChip;

    final header = <Widget>[
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: context.tr('Search item name or code', 'सामानको नाम वा कोड खोज्नुहोस्'),
              ),
              onChanged: (v) => _debounce.run(() => _changeQuery(() => _term = v.trim())),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: context.tr('Scan code', 'कोड स्क्यान'),
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ChipsRow<String>(
        value: _chip,
        onChanged: (v) => _changeQuery(() => _chip = v),
        options: {
          _allChip: context.tr('All', 'सबै'),
          _lowChip: low.hasValue
              ? '${context.tr('Low stock', 'कम स्टक')} (${context.num(low.requireValue)})'
              : context.tr('Low stock', 'कम स्टक'),
          for (final c in categories) 'cat:${c.id}': c.name,
        },
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: PCard(
              child: StatBlock(
                label: context.tr(filtered ? 'Found' : 'Items', filtered ? 'भेटियो' : 'सामान'),
                value: context.num(total),
                sub: '${context.num(low.value ?? 0)} ${context.tr('low on stock', 'कम स्टकमा')}',
              ),
            ),
          ),
          if (owner) ...[
            const SizedBox(width: 12),
            Expanded(
              child: PCard(
                child: StatBlock(
                  label: context.tr('Stock value', 'स्टकको मूल्य'),
                  value: stockValue == null ? '…' : context.rs(stockValue),
                  sub: context.tr('At buying price', 'खरिद मूल्यमा'),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: Seg<bool>(
          value: _grid,
          onChanged: _setView,
          options: {false: context.tr('List', 'सूची'), true: context.tr('Grid', 'ग्रिड')},
          icons: const {false: Icons.view_list_rounded, true: Icons.grid_view_rounded},
        ),
      ),
      const SizedBox(height: 12),
    ];

    final body = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: header)),
      ),
    ];

    if (list.hasError && !list.hasValue) {
      body.add(SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(error: list.error!, onRetry: () => ref.invalidate(itemListProvider(query))),
      ));
    } else if (!list.hasValue) {
      body.add(const SliverToBoxAdapter(child: SkeletonList()));
    } else if (rows.isEmpty) {
      body.add(SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.inventory_2_rounded,
          title: filtered ? context.tr('No items found', 'सामान भेटिएन') : context.tr('No items yet', 'अझै सामान छैन'),
          text: filtered
              ? context.tr('Try another word or chip.', 'अर्को शब्द वा चिप प्रयोग गर्नुहोस्।')
              : owner
                  ? context.tr('Add your first item to start selling.', 'बेच्न पहिलो सामान थप्नुहोस्।')
                  : context.tr('The owner has not added items yet.', 'मालिकले अझै सामान थपेका छैनन्।'),
          actionLabel: owner && !filtered ? context.tr('Add item', 'सामान थप्ने') : null,
          onAction: () => context.push('/items/new'),
        ),
      ));
    } else {
      body.add(_grid ? _gridSliver(rows) : _listSliver(rows, categories));
      body.add(_footer(query, owner: owner, hasMore: hasMore));
    }

    return PageScaffold(
      title: context.tr('Items', 'सामानहरू'),
      scroll: false,
      floatingActionButton: owner
          ? FloatingActionButton.extended(
        heroTag: null,
              onPressed: () => context.push('/items/new'),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('Add item', 'सामान थप्ने')),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => _refresh(query),
        child: CustomScrollView(slivers: body),
      ),
    );
  }

  Widget _gridSliver(List<Item> rows) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: rows.length,
        itemBuilder: (context, i) => ItemGridTile(item: rows[i], onTap: () => context.push('/items/${rows[i].id}')),
      ),
    );
  }

  Widget _listSliver(List<Item> rows, List<Category> categories) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(
        child: ListCard(
          children: [
            for (final it in rows)
              ListRow(
                leading: ItemThumb(photoUrl: it.photoUrl),
                title: it.name,
                subtitle: _subtitle(it, categories),
                amount: context.rs(it.sellPrice),
                amountTone: it.isLowStock ? Tone.warn : null,
                amountLabel: it.isLowStock ? context.tr('Low', 'कम') : null,
                onTap: () => context.push('/items/${it.id}'),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Item it, List<Category> categories) {
    final category = categoryNameOf(categories, it.categoryId);
    final stock = '${context.num(it.quantity)} ${it.unit}';
    return category.isEmpty ? stock : '$stock · $category';
  }

  Widget _footer(ItemQuery query, {required bool owner, required bool hasMore}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasMore)
              OutlinedButton(
                onPressed: _loadingMore ? null : () => _loadMore(query),
                child: Text(_loadingMore ? context.tr('Loading…', 'लोड हुँदैछ…') : context.tr('Load more', 'थप लोड गर्ने')),
              ),
            if (_moreError != null) ...[
              const SizedBox(height: 8),
              AlertBox(_moreError!.message),
            ],
            if (owner) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push('/items/deleted'),
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: Text(context.tr('Deleted items', 'हटाइएका सामान')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/categories'),
                    icon: const Icon(Icons.category_rounded),
                    label: Text(context.tr('Categories', 'वर्गहरू')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Item? _itemWithSku(List<Item> items, String code) {
  final wanted = code.trim().toLowerCase();
  for (final item in items) {
    if ((item.sku ?? '').toLowerCase() == wanted) return item;
  }
  return null;
}
