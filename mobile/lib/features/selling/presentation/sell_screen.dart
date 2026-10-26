import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/selling/data/cart.dart';
import 'package:pasal_mobile/features/selling/data/selling_repository.dart';

/// Tab 3. New sale: search, categories, the item grid, the cart bar.
class SellScreen extends ConsumerStatefulWidget {
  const SellScreen({super.key});

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  final _search = TextEditingController();
  final _debounce = Debouncer();
  String _term = '';
  int? _category;

  @override
  void dispose() {
    _search.dispose();
    _debounce.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await context.push<String>('/sell/scan');
    if (code == null || !mounted) return;
    await _addByCode(code);
  }

  Future<void> _addByCode(String raw) async {
    final code = raw.trim();
    if (code.isEmpty) return;
    final repo = ref.read(sellingRepositoryProvider);
    final known = ref.read(sellItemsProvider((search: _term, categoryId: _category))).value?.items ?? const <Item>[];
    Item? found;
    try {
      found = await repo.findBySku(code, known: known);
    } on ApiException catch (e) {
      if (!mounted) return;
      showProblem(context, e.message);
      return;
    }
    if (!mounted) return;
    if (found == null) {
      showProblem(context, context.tr('No item has the code $code', '$code कोडको सामान भेटिएन'));
      return;
    }
    final item = found;
    final added = ref.read(cartProvider.notifier).add(CartItem.of(item));
    if (!added) {
      showProblem(context, context.tr('No more of this item in stock', 'यो सामानको स्टक सकियो'));
      return;
    }
    _search.clear();
    setState(() => _term = '');
    showToast(context, 'Added ${item.name}', '${item.name} थपियो');
  }

  void _hold() {
    final entry = ref.read(cartProvider.notifier).hold();
    if (entry != null) context.push('/sell/held');
  }

  @override
  Widget build(BuildContext context) {
    final query = (search: _term, categoryId: _category);
    final items = ref.watch(sellItemsProvider(query));
    final categories = ref.watch(sellCategoriesProvider).value ?? const <Category>[];
    final cart = ref.watch(cartProvider);

    return PageScaffold(
      title: context.tr('New sale', 'नयाँ बिक्री'),
      scroll: false,
      actions: [
        IconButton(
          tooltip: context.tr('Held carts', 'रोकिएका कार्ट'),
          onPressed: () => context.push('/sell/held'),
          icon: Badge(
            isLabelVisible: cart.held.isNotEmpty,
            label: Text(context.num(cart.held.length)),
            child: const Icon(Icons.pause_circle_outline_rounded),
          ),
        ),
        IconButton(
          tooltip: context.tr('Sales list', 'बिक्री सूची'),
          onPressed: () => context.push('/sales'),
          icon: const Icon(Icons.history_rounded),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: context.tr('Search item name or code', 'सामानको नाम वा कोड खोज्नुहोस्'),
                suffixIcon: IconButton(
                  tooltip: context.tr('Scan barcode', 'बारकोड स्क्यान'),
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                ),
              ),
              onChanged: (v) => _debounce.run(() => setState(() => _term = v.trim())),
              onSubmitted: _addByCode,
            ),
          ),
          if (categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChipsRow<int?>(
                value: _category,
                onChanged: (v) => setState(() => _category = v),
                options: <int?, String>{
                  null: context.tr('All', 'सबै'),
                  for (final c in categories) c.id: c.name,
                },
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(sellItemsProvider(query)),
              child: AsyncBody<Paged<Item>>(
                value: items,
                onRetry: () => ref.invalidate(sellItemsProvider(query)),
                loading: const SingleChildScrollView(child: SkeletonList()),
                data: (page) => page.items.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: 360,
                            child: EmptyState(
                              icon: Icons.search_off_rounded,
                              title: context.tr('No items found', 'सामान भेटिएन'),
                              text: context.tr('Try another word or category.', 'अर्को शब्द वा वर्ग छान्नुहोस्।'),
                            ),
                          ),
                        ],
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 170,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: page.items.length,
                        itemBuilder: (context, i) {
                          final item = page.items[i];
                          return _ItemTile(
                            item: item,
                            inCart: _qtyInCart(cart, item.id),
                            onTap: () {
                              if (!ref.read(cartProvider.notifier).add(CartItem.of(item))) {
                                showProblem(context, context.tr('No more of this item in stock', 'यो सामानको स्टक सकियो'));
                              }
                            },
                          );
                        },
                      ),
              ),
            ),
          ),
          if (cart.count > 0)
            _CartBar(
              count: cart.count,
              total: cart.total,
              onHold: _hold,
              onCheckout: () => context.push('/sell/checkout'),
            ),
        ],
      ),
    );
  }
}

int _qtyInCart(CartState cart, int itemId) {
  for (final line in cart.lines) {
    if (line.item.id == itemId) return line.qty;
  }
  return 0;
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.inCart, required this.onTap});

  final Item item;
  final int inCart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final out = item.quantity <= 0;
    final stock = out
        ? context.tr('No stock', 'स्टक छैन')
        : item.isLowStock
            ? '${context.num(item.quantity)} ${context.tr('left only', 'मात्र बाँकी')}'
            : '${context.num(item.quantity)} ${context.tr('left', 'बाँकी')}';

    return Opacity(
      opacity: out ? 0.45 : 1,
      child: PCard(
        padding: const EdgeInsets.all(10),
        tone: inCart > 0 ? Tone.primary : null,
        onTap: out ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Photo(url: item.photoUrl),
                const Spacer(),
                if (inCart > 0) PBadge(context.num(inCart), tone: Tone.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(stock, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.rs(item.sellPrice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (item.isLowStock && !out) PBadge(context.tr('Low', 'कम'), tone: Tone.warn),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    if (url == null) return const IconTile(Icons.inventory_2_rounded, size: size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const IconTile(Icons.inventory_2_rounded, size: size),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.count, required this.total, required this.onHold, required this.onCheckout});

  final int count;
  final int total;
  final VoidCallback onHold;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: context.scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.num(count)} ${context.tr('items', 'सामान')}',
                      style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                    Text(
                      context.rs(total),
                      style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: context.tr('Hold cart', 'कार्ट रोक्ने'),
                onPressed: onHold,
                icon: const Icon(Icons.pause_rounded),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onCheckout,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(context.tr('Checkout', 'भुक्तानी')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
