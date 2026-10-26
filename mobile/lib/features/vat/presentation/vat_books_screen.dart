import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/bs_date.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/vat/data/csv.dart';
import 'package:pasal_mobile/features/vat/data/vat_helpers.dart';
import 'package:pasal_mobile/features/vat/data/vat_repository.dart';
import 'package:pasal_mobile/features/vat/presentation/vat_widgets.dart';
import 'package:share_plus/share_plus.dart';

enum BookTab { sales, purchase }

/// I5. The sales book and the purchase book for one Nepali month, with totals and a CSV file to share.
class VatBooksScreen extends ConsumerStatefulWidget {
  const VatBooksScreen({super.key});

  @override
  ConsumerState<VatBooksScreen> createState() => _VatBooksScreenState();
}

class _VatBooksScreenState extends ConsumerState<VatBooksScreen> {
  BookTab _tab = BookTab.sales;
  int _year = todayBs().year;
  int _month = todayBs().month;
  final List<Sale> _salesExtra = [];
  int _salesPage = 1;
  final List<Purchase> _purchaseExtra = [];
  int _purchasePage = 1;
  bool _moreBusy = false;
  ApiException? _moreError;
  bool _csvBusy = false;
  ApiException? _csvError;

  VatRange get _range => bsMonthRange(_year, _month);

  void _moveTo(int year, int month) {
    setState(() {
      _year = year;
      _month = month;
      _salesExtra.clear();
      _salesPage = 1;
      _purchaseExtra.clear();
      _purchasePage = 1;
      _moreError = null;
    });
  }

  Future<void> _loadMore(VatRange range) async {
    final repo = ref.read(vatRepositoryProvider);
    final isSales = _tab == BookTab.sales;
    final next = (isSales ? _salesPage : _purchasePage) + 1;
    setState(() {
      _moreBusy = true;
      _moreError = null;
    });
    if (isSales) {
      final res = await guard(() => repo.salesPage(range, page: next), onError: (e) => _moreError = e);
      if (!mounted) return;
      setState(() {
        _moreBusy = false;
        if (res != null && range == _range) {
          _salesExtra.addAll(res.items);
          _salesPage = next;
        }
      });
    } else {
      final res = await guard(() => repo.purchasesPage(range, page: next), onError: (e) => _moreError = e);
      if (!mounted) return;
      setState(() {
        _moreBusy = false;
        if (res != null && range == _range) {
          _purchaseExtra.addAll(res.items);
          _purchasePage = next;
        }
      });
    }
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _shareCsv() async {
    final range = _range;
    final period = periodLabel(_year, _month);
    final isSales = _tab == BookTab.sales;
    final repo = ref.read(vatRepositoryProvider);
    setState(() {
      _csvBusy = true;
      _csvError = null;
    });
    final text = await guard<String>(
      () async => isSales
          ? csvText(salesBookHeader, salesBookRows(await repo.allSales(range)))
          : csvText(purchaseBookHeader, purchaseBookRows(await repo.allPurchases(range))),
      onError: (e) => _csvError = e,
    );
    if (!mounted) return;
    final origin = _shareOrigin();
    setState(() => _csvBusy = false);
    if (text == null) return;
    final name = bookFileName(sales: isSales, period: period);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(csvBytes(text), mimeType: 'text/csv', name: name)],
        fileNameOverrides: [name],
        subject: name,
        sharePositionOrigin: origin,
      ),
    );
  }

  Widget _moreButton(BuildContext context, VatRange range) => FilledButton.tonal(
        onPressed: _moreBusy ? null : () => _loadMore(range),
        child: Text(_moreBusy ? context.tr('Loading…', 'लोड हुँदैछ…') : context.tr('Load more', 'अरू हेर्ने')),
      );

  List<Widget> _salesSection(BuildContext context, VatRange range) {
    final page = ref.watch(vatSalesBookProvider(range));
    final data = page.value;
    if (page.hasError && !page.hasValue) {
      return [ErrorView(error: page.error!, onRetry: () => ref.invalidate(vatSalesBookProvider(range)))];
    }
    if (data == null) return const [SkeletonList(rows: 6)];
    final rows = [...data.items, ..._salesExtra];
    if (rows.isEmpty) {
      return [EmptyState(icon: Icons.receipt_long_rounded, title: context.tr('No sales bills this month', 'यो महिनामा बिक्री बिल छैन'))];
    }
    final totals = salesTotals(rows);
    final walkIn = context.tr('Walk-in customer', 'पसलमा आएका ग्राहक');
    final cancelled = context.tr('Cancelled', 'रद्द भएको');
    final vat = context.tr('VAT', 'भ्याट');
    return [
      VatNote(
        context.tr(
          'Showing ${rows.length} of ${data.meta.total} sales bills',
          '${context.num(data.meta.total)} मध्ये ${context.num(rows.length)} बिक्री बिल देखाइएको',
        ),
      ),
      const SizedBox(height: 8),
      ListCard(
        children: [
          for (final s in rows)
            ListRow(
              title: '${digits(s.billNo ?? '-')} · ${s.customer?.name ?? walkIn}${s.cancelledAt == null ? '' : ' · $cancelled'}',
              subtitle: formatDate(s.soldAt),
              amount: plainText(s.total),
              amountLabel: '$vat ${plainText(s.vatAmount)}',
              chevron: false,
            ),
        ],
      ),
      const SizedBox(height: 12),
      PCard(
        child: VatKv(
          lines: [
            VatKvLine(context.tr('Taxable', 'करयोग्य'), plainText(totals.taxable)),
            VatKvLine(vat, plainText(totals.vat)),
            VatKvLine(context.tr('Exempt', 'करमुक्त'), plainText(totals.exempt)),
            VatKvLine(context.tr('Total shown', 'देखाइएका बिलको जम्मा'), plainText(totals.total), total: true),
          ],
        ),
      ),
      const SizedBox(height: 12),
      VatNote(
        context.tr(
          'Cancelled sales stay in this book. Returns and cancels count on the day they happened in the VAT numbers, so the totals here can differ.',
          'रद्द भएका बिक्री यस खातामा रहन्छन्। फिर्ता र रद्दको भ्याट अंकमा त्यो दिन गनिन्छ, त्यसैले यहाँको जम्मा फरक हुन सक्छ।',
        ),
      ),
      if (_salesPage < data.meta.lastPage) ...[
        const SizedBox(height: 12),
        Center(child: _moreButton(context, range)),
      ],
    ];
  }

  List<Widget> _purchaseSection(BuildContext context, VatRange range) {
    final page = ref.watch(vatPurchaseBookProvider(range));
    final data = page.value;
    if (page.hasError && !page.hasValue) {
      return [ErrorView(error: page.error!, onRetry: () => ref.invalidate(vatPurchaseBookProvider(range)))];
    }
    if (data == null) return const [SkeletonList(rows: 6)];
    final rows = [...data.items, ..._purchaseExtra];
    if (rows.isEmpty) {
      return [EmptyState(icon: Icons.receipt_long_rounded, title: context.tr('No purchase bills this month', 'यो महिनामा खरिद बिल छैन'))];
    }
    final totals = purchaseTotals(rows);
    final vat = context.tr('VAT', 'भ्याट');
    return [
      VatNote(
        context.tr(
          'Showing ${rows.length} of ${data.meta.total} purchase bills',
          '${context.num(data.meta.total)} मध्ये ${context.num(rows.length)} खरिद बिल देखाइएको',
        ),
      ),
      const SizedBox(height: 8),
      ListCard(
        children: [
          for (final p in rows)
            ListRow(
              title: '${digits(p.billNo ?? '-')} · ${p.supplier?.name ?? '-'}',
              subtitle: formatDate(p.billDate ?? p.boughtAt),
              amount: plainText(p.total),
              amountLabel: '$vat ${plainText(p.vatAmount)}',
              chevron: false,
            ),
        ],
      ),
      const SizedBox(height: 12),
      PCard(
        child: VatKv(
          lines: [
            VatKvLine(context.tr('Taxable', 'करयोग्य'), plainText(totals.taxable)),
            VatKvLine(vat, plainText(totals.vat)),
            VatKvLine(context.tr('Total shown', 'देखाइएका बिलको जम्मा'), plainText(totals.total), total: true),
          ],
        ),
      ),
      if (_purchasePage < data.meta.lastPage) ...[
        const SizedBox(height: 12),
        Center(child: _moreButton(context, range)),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final isSales = _tab == BookTab.sales;
    final moreProblem = errorText(_moreError);
    final csvProblem = errorText(_csvError);

    return PageScaffold(
      title: context.tr('Sales and purchase books', 'बिक्री र खरिद खाता'),
      bottom: PrimaryButton(
        label: _csvBusy ? context.tr('Preparing…', 'तयार हुँदैछ…') : context.tr('Share CSV', 'CSV शेयर गर्ने'),
        icon: Icons.ios_share_rounded,
        busy: _csvBusy,
        onPressed: _csvBusy ? null : _shareCsv,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonthNav(year: _year, month: _month, onChanged: _moveTo),
          const SizedBox(height: 8),
          Seg<BookTab>(
            value: _tab,
            onChanged: (v) => setState(() => _tab = v),
            options: {
              BookTab.sales: context.tr('Sales book', 'बिक्री खाता'),
              BookTab.purchase: context.tr('Purchase book', 'खरिद खाता'),
            },
          ),
          const SizedBox(height: 12),
          ...(isSales ? _salesSection(context, range) : _purchaseSection(context, range)),
          if (moreProblem != null) ...[
            const SizedBox(height: 12),
            AlertBox(moreProblem),
          ],
          if (csvProblem != null) ...[
            const SizedBox(height: 12),
            AlertBox(csvProblem),
          ],
        ],
      ),
    );
  }
}
