import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/vat/data/vat_helpers.dart';
import 'package:pasal_mobile/features/vat/data/vat_repository.dart';
import 'package:pasal_mobile/features/vat/presentation/vat_widgets.dart';

enum FilingFilter { all, notFiled, filed }

/// I2. Every saved VAT filing, newest first, with the total still to pay.
class VatFilingsScreen extends ConsumerStatefulWidget {
  const VatFilingsScreen({super.key});

  @override
  ConsumerState<VatFilingsScreen> createState() => _VatFilingsScreenState();
}

class _VatFilingsScreenState extends ConsumerState<VatFilingsScreen> {
  static const _perPage = 20;

  FilingFilter _filter = FilingFilter.all;
  final List<VatFiling> _extra = [];
  int _extraPage = 1;
  bool _moreBusy = false;
  ApiException? _moreError;

  Future<void> _loadMore() async {
    final next = _extraPage + 1;
    setState(() {
      _moreBusy = true;
      _moreError = null;
    });
    final res = await guard(
      () => ref.read(vatRepositoryProvider).filings(page: next, perPage: _perPage),
      onError: (e) => _moreError = e,
    );
    if (!mounted) return;
    setState(() {
      _moreBusy = false;
      if (res != null) {
        _extra.addAll(res.items);
        _extraPage = next;
      }
    });
  }

  void _retry() {
    setState(() {
      _extra.clear();
      _extraPage = 1;
    });
    ref.invalidate(vatFilingsProvider(_perPage));
  }

  bool _shows(VatFiling f) => switch (_filter) {
        FilingFilter.all => true,
        FilingFilter.filed => isFiled(f),
        FilingFilter.notFiled => !isFiled(f),
      };

  Widget _row(BuildContext context, VatFiling f) {
    final style = statusStyle(context, filingStatus(f));
    return ListRow(
      leading: IconTile(style.icon, tone: style.tone, size: 40),
      title: periodTitle(f.period),
      subtitle: f.source == 'manual' ? context.tr('Typed in by hand', 'हातले भरेको') : context.tr('Made from our bills', 'हाम्रा बिलबाट बनेको'),
      amount: context.rs(f.payable, paisaDigits: true),
      amountLabel: style.label,
      amountTone: style.tone,
      onTap: () => context.push('/vat/filings/${f.id}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(vatFilingsProvider(_perPage));
    final page = list.value;
    final rows = [...?page?.items, ..._extra];
    final hasMore = page != null && _extraPage < page.meta.lastPage;
    final thisLabel = periodLabel(todayBs().year, todayBs().month);
    final oldest = oldestUnpaid(rows);
    final shown = rows.where(_shows).toList();
    final moreText = errorText(_moreError);

    final Widget body;
    if (list.hasError && !list.hasValue) {
      body = ErrorView(error: list.error!, onRetry: _retry);
    } else if (!list.hasValue) {
      body = const SkeletonList(rows: 5);
    } else if (rows.isEmpty) {
      body = SizedBox(
        height: 420,
        child: EmptyState(
          icon: Icons.receipt_long_rounded,
          title: context.tr('No VAT filings yet', 'अहिलेसम्म भ्याट फाइलिङ छैन'),
          text: context.tr('Save a month from the VAT screen. It will show here.', 'भ्याट पृष्ठबाट महिना सेभ गर्नुहोस्। यहाँ देखिनेछ।'),
          actionLabel: context.tr('Go to VAT this month', 'यो महिनाको भ्याट'),
          onAction: () => context.push('/vat'),
        ),
      );
    } else {
      final thisSaved = filingForPeriod(rows, thisLabel) != null;
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          HeroCard(
            tone: Tone.warn,
            child: StatBlock(
              large: true,
              tone: Tone.warn,
              label: context.tr('Still to pay', 'अझै तिर्नुपर्ने'),
              value: context.rs(stillToPay(rows), paisaDigits: true),
              sub: oldest == null
                  ? context.tr('Nothing left to pay', 'तिर्नु बाँकी छैन')
                  : '${periodTitle(oldest.period)} · ${dueSentence(context, dueInDays(oldest.periodTo))}',
            ),
          ),
          if (hasMore) ...[
            const SizedBox(height: 6),
            VatNote(context.tr('Counts the filings loaded so far', 'हालसम्म देखिएका फाइलिङ मात्र गनिएको')),
          ],
          const SizedBox(height: 12),
          ChipsRow<FilingFilter>(
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
            options: {
              FilingFilter.all: context.tr('All', 'सबै'),
              FilingFilter.notFiled: context.tr('Not filed', 'फाइल नभएको'),
              FilingFilter.filed: context.tr('Filed', 'फाइल भएको'),
            },
          ),
          const SizedBox(height: 12),
          if (!thisSaved) ...[
            VatNote(context.tr('${periodTitle(thisLabel)} is not saved yet.', '${periodTitle(thisLabel)} अहिलेसम्म सेभ भएको छैन।')),
            const SizedBox(height: 8),
          ],
          if (shown.isEmpty) ...[
            VatNote(context.tr('No filings in this group yet.', 'यो समूहमा अहिलेसम्म फाइलिङ छैन।')),
            const SizedBox(height: 8),
          ],
          ListCard(children: [for (final f in shown) _row(context, f)]),
          if (moreText != null) ...[
            const SizedBox(height: 12),
            AlertBox(moreText),
          ],
          if (hasMore) ...[
            const SizedBox(height: 12),
            Center(
              child: FilledButton.tonal(
                onPressed: _moreBusy ? null : _loadMore,
                child: Text(_moreBusy ? context.tr('Loading…', 'लोड हुँदैछ…') : context.tr('Load more', 'अरू हेर्ने')),
              ),
            ),
          ],
        ],
      );
    }

    return PageScaffold(
      title: context.tr('VAT filings', 'भ्याट फाइलिङ'),
      scroll: false,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push('/vat/old-return'),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('Add old return', 'पुरानो रिटर्न थप्ने')),
      ),
      body: body,
    );
  }
}
