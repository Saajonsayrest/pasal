import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/items/data/item_pricing.dart';
import 'package:pasal_mobile/features/items/data/item_providers.dart';
import 'package:pasal_mobile/features/items/data/item_sales.dart';
import 'package:pasal_mobile/features/items/presentation/adjust_stock_sheet.dart';
import 'package:pasal_mobile/features/items/presentation/item_widgets.dart';
import 'package:pasal_mobile/features/selling/data/cart.dart';

/// D2. One item: stock left, prices and profit, sales of the last 30 days and the latest stock changes.
class ItemDetailsScreen extends ConsumerWidget {
  const ItemDetailsScreen({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemDetailProvider(id));
    return PageScaffold(
      title: item.value?.name ?? context.tr('Item details', 'सामान विवरण'),
      body: AsyncBody(
        value: item,
        onRetry: () => ref.invalidate(itemDetailProvider(id)),
        data: (i) => _ItemBody(item: i),
      ),
    );
  }
}

class _ItemBody extends ConsumerWidget {
  const _ItemBody({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final owner = session.isOwner;
    final vatRate = session.business?.vatRate ?? 0;
    final categories = ref.watch(itemCategoriesProvider).value ?? const <Category>[];
    final low = item.isLowStock;
    final category = categoryNameOf(categories, item.categoryId);
    final priceExVat = exVatPaisa(item.sellPrice, vatRate, vatApplies: item.vatApplies);
    final profit = profitPaisa(sellPaisa: item.sellPrice, costPaisa: item.costPrice, vatRate: vatRate, vatApplies: item.vatApplies);

    final top = item.quantity > item.lowStockAt * 2 ? item.quantity : item.lowStockAt * 2;
    final stockMax = top < 1 ? 1 : top;
    final stockPct = item.quantity <= 0 ? 0.0 : (item.quantity / stockMax).clamp(0.0, 1.0).toDouble();
    final code = '${context.tr('Code', 'कोड')}: ${item.sku ?? context.tr('None', 'छैन')}${category.isEmpty ? '' : ' · $category'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          tone: low ? Tone.warn : Tone.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ItemThumb(photoUrl: item.photoUrl, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        Text(code, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Text(context.tr('Stock left', 'बाँकी स्टक'), style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w600))),
                  if (low) PBadge(context.tr('Low stock', 'कम स्टक'), tone: Tone.warn),
                ],
              ),
              Text(
                '${context.num(item.quantity)} ${item.unit}',
                style: context.text.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: stockPct,
                  minHeight: 8,
                  color: low ? context.colors.warn : context.colors.good,
                  backgroundColor: context.scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${context.tr('Low level', 'कम स्तर')}: ${context.num(item.lowStockAt)} ${item.unit}',
                style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: item.quantity < 1
                  ? null
                  : () {
                      if (ref.read(cartProvider.notifier).add(CartItem.of(item))) {
                        context.push('/sell/checkout');
                      } else {
                        showProblem(context, context.tr('No more of this item in stock', 'यो सामानको स्टक सकियो'));
                      }
                    },
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: Text(context.tr('Sell this', 'यो बेच्ने')),
            ),
            if (owner) ...[
              FilledButton.tonalIcon(
                onPressed: () => _adjust(context),
                icon: const Icon(Icons.tune_rounded),
                label: Text(context.tr('Adjust stock', 'स्टक मिलाउने')),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/items/${item.id}/edit'),
                icon: const Icon(Icons.edit_rounded),
                label: Text(context.tr('Edit', 'सच्याउने')),
              ),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                style: OutlinedButton.styleFrom(foregroundColor: context.colors.bad),
                icon: const Icon(Icons.delete_rounded),
                label: Text(context.tr('Delete', 'हटाउने')),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Prices', 'मूल्य'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              KeyValueRow(
                label: item.vatApplies
                    ? context.tr('Sell price (VAT included)', 'बिक्री मूल्य (भ्याट सहित)')
                    : context.tr('Sell price (no VAT)', 'बिक्री मूल्य (भ्याट छैन)'),
                value: context.rs(item.sellPrice),
              ),
              if (owner && profit != null) ...[
                KeyValueRow(
                  label: context.tr('Buying price (without VAT)', 'खरिद मूल्य (भ्याट बाहेक)'),
                  value: context.rs(item.costPrice),
                ),
                KeyValueRow(
                  label: context.tr('Profit per piece', 'प्रति पिस नाफा'),
                  value: '${context.rs(profit, paisaDigits: true)} (${digits(marginText(marginTenths(profit, priceExVat)))})',
                  tone: profit >= 0 ? Tone.good : Tone.bad,
                ),
              ],
              KeyValueRow(
                label: context.tr('VAT applies', 'भ्याट लाग्ने'),
                value: item.vatApplies ? context.tr('Yes', 'हो') : context.tr('No', 'होइन'),
              ),
              KeyValueRow(label: context.tr('Unit', 'एकाइ'), value: item.unit),
              if (owner && profit != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    context.tr('Sell price without VAT minus buying price', 'बिक्री मूल्य (भ्याट बाहेक) माइनस खरिद मूल्य'),
                    style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
        if (owner) ...[
          const SizedBox(height: 12),
          _SalesCard(itemId: item.id, unit: item.unit),
          const SizedBox(height: 12),
          _HistorySection(itemId: item.id),
        ],
      ],
    );
  }

  Future<void> _adjust(BuildContext context) {
    return showPasalSheet<void>(
      context,
      title: context.tr('Adjust stock', 'स्टक मिलाउने'),
      builder: (sheet) => AdjustStockSheet(item: item, onSaved: (_) => Navigator.of(sheet).pop()),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final deleted = await showPasalSheet<bool>(
      context,
      title: context.tr('Delete this item?', 'सामान हटाउने?'),
      builder: (_) => _DeleteSheet(item: item),
    );
    if (deleted != true || !context.mounted) return;
    ref.invalidate(itemListProvider);
    ref.invalidate(lowStockCountProvider);
    ref.invalidate(deletedItemsProvider);
    showToast(context, 'Item deleted', 'सामान हटाइयो');
    context.go('/items');
  }
}

/// Sold units in the last 30 days, with five weekly bars.
class _SalesCard extends ConsumerWidget {
  const _SalesCard({required this.itemId, required this.unit});

  final int itemId;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moves = ref.watch(itemMovementsProvider(itemId));
    return AsyncBody(
      value: moves,
      onRetry: () => ref.invalidate(itemMovementsProvider(itemId)),
      data: (page) {
        final window = salesWindow(page.items);
        final top = window.weeks.fold<int>(1, (a, b) => b > a ? b : a);
        final partial = page.meta.total > page.items.length;
        return PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Sold, last 30 days', 'पछिल्लो ३० दिनमा बिक्री'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              KeyValueRow(label: context.tr('Sold', 'बिक्री भयो'), value: '${context.num(window.sold)} $unit'),
              const SizedBox(height: 8),
              SizedBox(
                height: 92,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var n = 0; n < 5; n++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: (window.weeks[n] * 60 / top).clamp(2.0, 60.0).toDouble(),
                                decoration: BoxDecoration(
                                  color: n == 4 ? context.scheme.primary : context.scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n == 4 ? context.tr('This week', 'यो हप्ता') : context.tr('Week ${n + 1}', 'हप्ता ${context.num(n + 1)}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (partial)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.tr('Based on the latest 100 stock changes.', 'पछिल्लो १०० स्टक परिवर्तनमा आधारित।'),
                    style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The five latest stock changes, with a link to the full history.
class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moves = ref.watch(itemMovementsProvider(itemId));
    return AsyncBody(
      value: moves,
      onRetry: () => ref.invalidate(itemMovementsProvider(itemId)),
      data: (page) {
        final latest = page.items.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(context.tr('Stock history', 'स्टक इतिहास'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () => context.push('/items/$itemId/history'),
                  child: Text(context.tr('See all', 'सबै हेर्ने')),
                ),
              ],
            ),
            if (latest.isEmpty)
              Text(context.tr('No stock changes yet.', 'अहिलेसम्म स्टक परिवर्तन छैन।'), style: context.text.bodyMedium)
            else
              ListCard(
                children: [
                  for (final m in latest)
                    ListRow(
                      leading: IconTile(
                        m.change < 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        tone: m.change < 0 ? Tone.warn : Tone.good,
                        size: 40,
                      ),
                      title: '${movementReason(context, m.reason)}${m.by == null ? '' : ' · ${m.by}'}',
                      subtitle: '${formatDate(m.at)}${m.note == null ? '' : ' · ${m.note}'}',
                      amount: '${m.change > 0 ? '+' : ''}${context.num(m.change)}',
                      amountTone: m.change < 0 ? Tone.warn : Tone.good,
                      chevron: false,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Asks before the item moves to Deleted items. Returns true when it was deleted.
class _DeleteSheet extends ConsumerStatefulWidget {
  const _DeleteSheet({required this.item});

  final Item item;

  @override
  ConsumerState<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends ConsumerState<_DeleteSheet> {
  bool _busy = false;
  ApiException? _error;

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await guard(
      () async {
        await ref.read(itemRepositoryProvider).delete(widget.item.id);
        return true;
      },
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    if (ok == true) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final stockError = error?.field('quantity');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr('It moves to Deleted items. Old bills keep its name.', 'यो हटाइएका सामानमा जान्छ। पुराना बिलमा नाम रहन्छ।'),
          style: context.text.bodyLarge,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          AlertBox(stockError ?? error.message),
          if (stockError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                context.tr('Set the stock to 0 first. Use Adjust stock.', 'पहिले स्टक ० बनाउनुहोस्। स्टक मिलाउने प्रयोग गर्नुहोस्।'),
                style: context.text.bodySmall,
              ),
            ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: context.colors.bad, foregroundColor: Colors.white),
          onPressed: _busy ? null : _delete,
          icon: const Icon(Icons.delete_rounded),
          label: Text(_busy ? context.tr('Deleting…', 'हटाउँदैछ…') : context.tr('Delete', 'हटाउने')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel', 'रद्द')),
        ),
      ],
    );
  }
}
