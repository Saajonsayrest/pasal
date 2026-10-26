import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/bs_date.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/selling/data/selling_repository.dart';
import 'package:pasal_mobile/features/selling/presentation/selling_widgets.dart';

enum _Period { all, today, month, range }

/// Bills, newest first (/sales). Filters: all, today, this month, a date range, unpaid, and search.
class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _search = TextEditingController();
  final _debounce = Debouncer();
  String _term = '';
  _Period _period = _Period.today;
  bool _unpaid = false;
  String _from = todayAd();
  String _to = todayAd();

  /// Pages after the first one, and the last page loaded.
  List<Sale> _more = const [];
  int _page = 1;
  bool _loadingMore = false;
  ApiException? _moreError;

  @override
  void dispose() {
    _search.dispose();
    _debounce.dispose();
    super.dispose();
  }

  void _resetMore() {
    _more = const [];
    _page = 1;
    _moreError = null;
  }

  SalesQuery _query() {
    final (String? from, String? to) = switch (_period) {
      _Period.all => (null, null),
      _Period.today => (todayAd(), todayAd()),
      _Period.month => _thisMonth(),
      _Period.range => (_from, _to),
    };
    return (search: _term, unpaid: _unpaid, from: from, to: to);
  }

  (String?, String?) _thisMonth() {
    final now = todayBs();
    final range = bsMonthRange(now.year, now.month);
    return (range.from, range.to);
  }

  Future<void> _loadMore(SalesQuery query) async {
    final repo = ref.read(sellingRepositoryProvider);
    final next = _page + 1;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final res = await repo.sales(query, page: next);
      if (!mounted) return;
      setState(() {
        _more = [..._more, ...res.items];
        _page = next;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _moreError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query();
    final list = ref.watch(salesListProvider(query));

    return PageScaffold(
      title: context.tr('Sales', 'बिक्री सूची'),
      scroll: false,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: context.tr('Search bill or customer', 'बिल वा ग्राहक खोज्नुहोस्'),
              ),
              onChanged: (v) => _debounce.run(() => setState(() {
                    _term = v.trim();
                    _resetMore();
                  })),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ChipsRow<_Period>(
              value: _period,
              onChanged: (v) => setState(() {
                _period = v;
                _resetMore();
              }),
              options: {
                _Period.all: context.tr('All', 'सबै'),
                _Period.today: context.tr('Today', 'आज'),
                _Period.month: context.tr('This month', 'यो महिना'),
                _Period.range: context.tr('Date range', 'मिति दायरा'),
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: Text(context.tr('Unpaid', 'बाँकी')),
                selected: _unpaid,
                onSelected: (v) => setState(() {
                  _unpaid = v;
                  _resetMore();
                }),
              ),
            ),
          ),
          if (_period == _Period.range)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: BsDateField(
                      label: context.tr('From', 'देखि'),
                      value: _from,
                      max: _to,
                      onChanged: (v) => setState(() {
                        _from = v;
                        _resetMore();
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BsDateField(
                      label: context.tr('To', 'सम्म'),
                      value: _to,
                      min: _from,
                      onChanged: (v) => setState(() {
                        _to = v;
                        _resetMore();
                      }),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(salesListProvider(query)),
              child: AsyncBody<Paged<Sale>>(
                value: list,
                onRetry: () => ref.invalidate(salesListProvider(query)),
                loading: const SingleChildScrollView(child: SkeletonList(rows: 6)),
                data: (page) => _SalesList(
                  page: page,
                  more: _more,
                  loadingMore: _loadingMore,
                  moreError: _moreError,
                  onLoadMore: () => _loadMore(query),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesList extends StatelessWidget {
  const _SalesList({
    required this.page,
    required this.more,
    required this.loadingMore,
    required this.moreError,
    required this.onLoadMore,
  });

  final Paged<Sale> page;
  final List<Sale> more;
  final bool loadingMore;
  final ApiException? moreError;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final rows = [...page.items, ...more];
    final count = page.meta.total;
    final hasMore = rows.length < count;
    final net = rows.fold<int>(0, (sum, s) => sum + s.total - s.returnedTotal);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        HeroCard(
          child: StatBlock(
            large: true,
            label: hasMore ? context.tr('Total so far', 'अहिलेसम्मको जम्मा') : context.tr('Total sales', 'जम्मा बिक्री'),
            value: context.rs(net),
            sub: '${context.num(count)} ${context.tr('bills', 'बिल')}',
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          SizedBox(
            height: 320,
            child: EmptyState(
              icon: Icons.receipt_long_rounded,
              title: context.tr('No bills found', 'बिल भेटिएन'),
              text: context.tr('Change the filter or make a sale.', 'फिल्टर बदल्नुहोस् वा बिक्री गर्नुहोस्।'),
              actionLabel: context.tr('New sale', 'नयाँ बिक्री'),
              onAction: () => context.go('/sell'),
            ),
          )
        else
          ListCard(
            children: [
              for (final sale in rows)
                _SaleRow(sale: sale, onTap: () => context.push('/sales/${sale.id}')),
            ],
          ),
        if (hasMore) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: loadingMore ? null : onLoadMore,
            child: Text(loadingMore ? context.tr('Loading…', 'लोड हुँदैछ…') : context.tr('Load more', 'अरू हेर्ने')),
          ),
        ],
        if (moreError != null) ...[
          const SizedBox(height: 12),
          AlertBox(moreError!.message),
        ],
      ],
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale, required this.onTap});

  final Sale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final customer = sale.customer;
    final status = saleStatus(context, sale);
    return ListRow(
      leading: customer == null ? const IconTile(Icons.person_rounded, size: 44) : AvatarCircle(customer.name),
      title: customer?.name ?? context.tr('Walk-in customer', 'पसलमा आएका ग्राहक'),
      subtitle: '${sale.billNo ?? '#${sale.id}'} · ${formatTime(sale.soldAt)} · ${formatDate(sale.soldAt)}',
      amount: context.rs(sale.total),
      amountLabel: status.text,
      amountTone: status.tone,
      onTap: onTap,
      chevron: false,
    );
  }
}
