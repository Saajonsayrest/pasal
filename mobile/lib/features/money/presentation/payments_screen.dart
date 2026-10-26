import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/bs_date.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/money/data/money_repository.dart';
import 'package:pasal_mobile/features/money/presentation/money_labels.dart';

/// G4. Every payment in and out, filtered by direction, method and date. Newest first, 30 at a time.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final _today = todayAd();
  String _direction = '';
  String _method = '';
  late String _from;
  late String _to;

  /// How many pages are on screen. Each page is its own provider, so a filter change starts over at page 1.
  int _pages = 1;

  @override
  void initState() {
    super.initState();
    final now = todayBs();
    _from = bsMonthRange(now.year, now.month).from;
    _to = _today;
  }

  PaymentQuery _query(int page) => (
        direction: _direction.isEmpty ? null : _direction,
        method: _method.isEmpty ? null : _method,
        from: _from,
        to: _to,
        page: page,
      );

  void _change(VoidCallback change) => setState(() {
        change();
        _pages = 1;
      });

  String _billOf(BuildContext context, Payment p) {
    if (p.saleId != null) return '${context.tr('Sale', 'बिक्री')} #${context.num(p.saleId!)}';
    if (p.purchaseId != null) return '${context.tr('Purchase', 'खरिद')} #${context.num(p.purchaseId!)}';
    return '';
  }

  String _directionName(BuildContext context, String direction) => switch (direction) {
        'in' => context.tr('Received', 'पाएको'),
        'out' => context.tr('Paid out', 'तिरेको'),
        _ => context.tr('Refund', 'फिर्ता'),
      };

  IconData _directionIcon(String direction) => switch (direction) {
        'in' => Icons.arrow_downward_rounded,
        'out' => Icons.arrow_upward_rounded,
        _ => Icons.undo_rounded,
      };

  Tone _directionTone(String direction) => switch (direction) {
        'in' => Tone.good,
        'out' => Tone.info,
        _ => Tone.warn,
      };

  int _sum(List<Payment> rows, String direction) =>
      rows.where((p) => p.direction == direction).fold<int>(0, (sum, p) => sum + p.amount);

  Widget _row(BuildContext context, Payment p) {
    final link = p.saleId != null
        ? '/sales/${p.saleId}'
        : p.purchaseId != null
            ? '/purchases/${p.purchaseId}'
            : null;
    final bill = _billOf(context, p);
    return ListRow(
      leading: IconTile(_directionIcon(p.direction), tone: _directionTone(p.direction)),
      title: p.party ?? context.tr('No name', 'नाम छैन'),
      subtitle: [
        _directionName(context, p.direction),
        if (bill.isNotEmpty) bill,
        '${formatDate(p.paidAt)}, ${formatTime(p.paidAt)}',
      ].join(' · '),
      amount: context.rs(p.amount),
      amountLabel: methodName(context, p.method),
      onTap: link == null ? null : () => context.push(link),
      chevron: link != null,
    );
  }

  Widget _content(BuildContext context, List<Payment> rows, int total, AsyncValue<Paged<Payment>> last) {
    final lastError = last.error;
    final hasMore = rows.length < total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PCard(
                child: StatBlock(label: context.tr('Received', 'पाएको'), value: context.rs(_sum(rows, 'in')), tone: Tone.good),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PCard(
                child: StatBlock(label: context.tr('Paid out', 'तिरेको'), value: context.rs(_sum(rows, 'out'))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PCard(
                child: StatBlock(label: context.tr('Refunds', 'फिर्ता'), value: context.rs(_sum(rows, 'refund')), tone: Tone.warn),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('Totals of the rows loaded so far', 'अहिलेसम्म लोड भएका रोको जोड'),
          style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          SizedBox(
            height: 300,
            child: EmptyState(
              icon: Icons.payments_rounded,
              title: context.tr('No payments found', 'भुक्तानी भेटिएन'),
              text: context.tr('Try another date range or a different filter.', 'अर्को मिति दायरा वा फिल्टर प्रयास गर्नुहोस्।'),
            ),
          )
        else ...[
          ListCard(children: [for (final p in rows) _row(context, p)]),
          const SizedBox(height: 10),
          Text(
            context.tr(
              'Showing ${context.num(rows.length)} of ${context.num(total)} payments',
              '${context.num(total)} मध्ये ${context.num(rows.length)} देखाइँदै',
            ),
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
          if (lastError != null) ...[
            const SizedBox(height: 10),
            AlertBox(lastError is ApiException ? lastError.message : context.tr('Something went wrong.', 'केही गडबड भयो।')),
          ],
          if (hasMore) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: last.isLoading
                    ? null
                    : lastError != null
                        ? () => ref.invalidate(paymentsProvider(_query(_pages)))
                        : () => setState(() {
                              _pages++;
                            }),
                child: Text(
                  last.isLoading
                      ? context.tr('Loading…', 'लोड हुँदैछ…')
                      : lastError != null
                          ? context.tr('Try again', 'फेरि प्रयास गर्नुहोस्')
                          : context.tr('Load more', 'थप लोड गर्ने'),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [for (var p = 1; p <= _pages; p++) ref.watch(paymentsProvider(_query(p)))];
    final first = pages.first;
    final last = pages.last;
    final rows = [for (final p in pages) ...?p.value?.items];
    final total = first.value?.meta.total ?? 0;

    Widget body;
    if (first.hasError && !first.hasValue) {
      body = SizedBox(height: 420, child: ErrorView(error: first.error!, onRetry: () => ref.invalidate(paymentsProvider)));
    } else if (!first.hasValue) {
      body = const SkeletonList(rows: 6);
    } else {
      body = _content(context, rows, total, last);
    }

    return PageScaffold(
      title: context.tr('All payments', 'सबै भुक्तानी'),
      onRefresh: () async => ref.invalidate(paymentsProvider),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChipsRow<String>(
            value: _direction,
            onChanged: (v) => _change(() => _direction = v),
            options: {
              '': context.tr('All', 'सबै'),
              'in': context.tr('In', 'पाएको'),
              'out': context.tr('Out', 'तिरेको'),
              'refund': context.tr('Refund', 'फिर्ता'),
            },
          ),
          const SizedBox(height: 8),
          ChipsRow<String>(
            value: _method,
            onChanged: (v) => _change(() => _method = v),
            options: {
              '': context.tr('All methods', 'सबै तरिका'),
              for (final m in paymentMethods) m.key: context.tr(m.en, m.ne),
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BsDateField(
                  label: context.tr('From', 'देखि'),
                  value: _from,
                  max: _to,
                  onChanged: (v) => _change(() => _from = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BsDateField(
                  label: context.tr('To', 'सम्म'),
                  value: _to,
                  min: _from,
                  max: _today,
                  onChanged: (v) => _change(() => _to = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}
