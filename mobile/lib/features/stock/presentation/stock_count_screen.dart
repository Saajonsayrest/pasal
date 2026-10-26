import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/icon_names.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/stock/data/category_repository.dart';
import 'package:pasal_mobile/features/stock/data/count_draft.dart';
import 'package:pasal_mobile/features/stock/data/stock_repository.dart';
import 'package:pasal_mobile/features/stock/data/stock_rules.dart';
import 'package:pasal_mobile/features/stock/presentation/count_review_sheet.dart';

enum _Status { uncounted, different, all }

/// D6. Type what was counted on the shelf, review the differences, save once. The draft survives a closed app. Owner only.
class StockCountScreen extends ConsumerStatefulWidget {
  const StockCountScreen({super.key});

  @override
  ConsumerState<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends ConsumerState<StockCountScreen> {
  final _search = TextEditingController();
  final _note = TextEditingController();

  /// One box per item the person has typed into. Their text is the draft.
  final Map<int, TextEditingController> _boxes = {};
  String _query = '';
  _Status _status = _Status.all;
  String _category = 'all';
  StockCountResult? _result;

  @override
  void initState() {
    super.initState();
    final draft = loadCountDraft(ref.read(sharedPrefsProvider));
    _note.text = draft.note;
    for (final entry in draft.counts.entries) {
      final id = int.tryParse(entry.key);
      if (id != null) _box(id).text = entry.value;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _note.dispose();
    for (final box in _boxes.values) {
      box.dispose();
    }
    super.dispose();
  }

  TextEditingController _box(int id) => _boxes.putIfAbsent(id, () => TextEditingController());

  Map<int, String> get _typed => {for (final e in _boxes.entries) e.key: e.value.text};

  void _persist() {
    final counts = {
      for (final e in _boxes.entries)
        if (e.value.text.trim().isNotEmpty) '${e.key}': e.value.text.trim(),
    };
    saveCountDraft(ref.read(sharedPrefsProvider), CountDraft(counts: counts, note: _note.text));
  }

  List<Item> _visible(List<Item> all) {
    final q = _query.trim().toLowerCase();
    return all.where((item) {
      if (q.isNotEmpty && !item.name.toLowerCase().contains(q) && !(item.sku ?? '').toLowerCase().contains(q)) return false;
      if (_category == 'none' && item.categoryId != null) return false;
      if (_category != 'all' && _category != 'none' && '${item.categoryId}' != _category) return false;
      final n = parseWhole(_boxes[item.id]?.text);
      return switch (_status) {
        _Status.uncounted => n == null,
        _Status.different => n != null && n != item.quantity,
        _Status.all => true,
      };
    }).toList();
  }

  Future<void> _review(List<CountLine> counted) async {
    final saved = await showPasalSheet<StockCountResult>(
      context,
      title: context.tr('Check before saving', 'सेभ गर्नु अघि हेर्नुहोस्'),
      builder: (ctx) => CountReviewSheet(lines: counted, note: _note.text),
    );
    if (saved == null || !mounted) return;
    for (final box in _boxes.values) {
      box.clear();
    }
    _note.clear();
    _persist();
    ref.invalidate(allItemsProvider);
    setState(() => _result = saved);
    showToast(context, 'Stock count saved', 'स्टक गणना सेभ भयो');
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(allItemsProvider);
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final all = items.value ?? const <Item>[];
    final counted = countedLines(all, _typed);
    final differences = counted.where((l) => l.difference != 0).toList();
    final invalid = hasInvalidCount(_boxes.values.map((b) => b.text));

    return PageScaffold(
      title: context.tr('Stock count', 'स्टक गणना'),
      scroll: false,
      bottom: PrimaryButton(
        label: differences.isEmpty
            ? context.tr('Review count', 'गणना हेर्ने')
            : context.tr('Review ${context.num(differences.length)} differences', '${context.num(differences.length)} फरक हेर्ने'),
        icon: Icons.compare_arrows_rounded,
        onPressed: !items.hasValue || counted.isEmpty || invalid ? null : () => _review(counted),
      ),
      body: AsyncBody(
        value: items,
        onRetry: () => ref.invalidate(allItemsProvider),
        data: (list) => _body(context, list, cats, counted, differences.length, invalid),
      ),
    );
  }

  Widget _body(BuildContext context, List<Item> all, List<Category> cats, List<CountLine> counted, int differenceCount, bool invalid) {
    final visible = _visible(all);
    final catById = {for (final c in cats) c.id: c};
    final result = _result;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (result != null) ...[
          _ResultCard(result: result, onClose: () => setState(() => _result = null)),
          const SizedBox(height: 12),
        ],
        if (invalid) ...[
          AlertBox(context.tr('Counts must be whole numbers, 0 or more.', 'गन्ती पूरा संख्या हुनुपर्छ, ० वा माथि।'), tone: Tone.warn, icon: Icons.info_outline_rounded),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: context.tr('Search item name or code', 'सामानको नाम वा कोड खोज्नुहोस्'),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),
        ChipsRow<String>(
          value: _category,
          onChanged: (v) => setState(() => _category = v),
          options: {
            'all': context.tr('All categories', 'सबै वर्ग'),
            'none': context.tr('No category', 'बिना वर्ग'),
            for (final c in cats) '${c.id}': c.name,
          },
        ),
        const SizedBox(height: 12),
        ChipsRow<_Status>(
          value: _status,
          onChanged: (v) => setState(() => _status = v),
          options: {
            _Status.uncounted: context.tr('Not counted', 'नगनिएको'),
            _Status.different: context.tr('Different', 'फरक'),
            _Status.all: context.tr('All', 'सबै'),
          },
        ),
        const SizedBox(height: 12),
        if (all.isEmpty)
          SizedBox(
            height: 320,
            child: EmptyState(
              icon: Icons.inventory_2_rounded,
              title: context.tr('No items yet', 'अहिलेसम्म सामान छैन'),
              text: context.tr('Add items first, then count them here.', 'पहिले सामान थप्नुहोस्, त्यसपछि यहाँ गन्नुहोस्।'),
            ),
          )
        else if (visible.isEmpty)
          SizedBox(
            height: 220,
            child: EmptyState(icon: Icons.search_off_rounded, title: context.tr('No items match', 'मेल खाने सामान भेटिएन')),
          )
        else
          ListCard(
            children: [for (final item in visible) _countRow(context, item, catById[item.categoryId])],
          ),
        const SizedBox(height: 16),
        PCard(
          child: Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: context.tr('Counted', 'गनियो'),
                  value: '${context.num(counted.length)} / ${context.num(all.length)}',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: context.tr('Differences', 'फरक'),
                  value: context.num(differenceCount),
                  tone: differenceCount > 0 ? Tone.warn : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PField(
          label: context.tr('Note', 'नोट'),
          controller: _note,
          hint: context.tr('Example: Month end', 'उदाहरण: महिनाको अन्त्य'),
          onChanged: (_) => _persist(),
        ),
      ],
    );
  }

  Widget _countRow(BuildContext context, Item item, Category? category) {
    final box = _box(item.id);
    final n = parseWhole(box.text);
    final unit = item.unit == 'pcs' && context.isNe ? 'पिस' : item.unit;
    final PBadge status;
    if (n == null) {
      status = PBadge(context.tr('Not counted', 'नगनिएको'));
    } else if (n == item.quantity) {
      status = PBadge(context.tr('Matches', 'मिल्यो'), tone: Tone.good);
    } else if (n < item.quantity) {
      status = PBadge(context.tr('Short by ${context.num(item.quantity - n)}', '${context.num(item.quantity - n)} कम'), tone: Tone.warn);
    } else {
      status = PBadge(context.tr('Extra ${context.num(n - item.quantity)}', '${context.num(n - item.quantity)} बढी'), tone: Tone.info);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          IconTile(symbolIcon(category?.icon), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.tr('System ${context.num(item.quantity)} ${item.unit}', 'सिस्टम ${context.num(item.quantity)} $unit'),
                      style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                    status,
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: TextField(
              controller: box,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: context.tr('Count', 'गन्ने'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
              onChanged: (_) {
                setState(() {});
                _persist();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onClose});

  final StockCountResult result;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return PCard(
      tone: Tone.good,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.tr('Count saved', 'गणना सेभ भयो'), style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              TextButton(onPressed: onClose, child: Text(context.tr('Close', 'बन्द'))),
            ],
          ),
          Text(
            context.tr('${context.num(result.itemsChanged)} items changed', '${context.num(result.itemsChanged)} सामानमा परिवर्तन भयो'),
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: 8),
          ListCard(
            children: [
              for (final r in result.rows)
                ListRow(
                  title: r.itemName,
                  subtitle: context.tr(
                    'System ${context.num(r.system)} · counted ${context.num(r.counted)}',
                    'सिस्टम ${context.num(r.system)} · गनेको ${context.num(r.counted)}',
                  ),
                  trailing: PBadge(
                    r.difference == 0
                        ? context.tr('Matches', 'मिल्यो')
                        : r.difference < 0
                            ? context.tr('Short by ${context.num(-r.difference)}', '${context.num(-r.difference)} कम')
                            : context.tr('Extra ${context.num(r.difference)}', '${context.num(r.difference)} बढी'),
                    tone: r.difference == 0 ? Tone.good : (r.difference < 0 ? Tone.warn : Tone.info),
                  ),
                  chevron: false,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
