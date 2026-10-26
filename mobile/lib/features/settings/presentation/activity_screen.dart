import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/settings/data/activity_repository.dart';
import 'package:pasal_mobile/features/settings/data/staff_repository.dart';

/// Who did what, newest first. Owner only. Filter by person or by kind of event.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  /// The user id as text, or '' for everyone.
  String _person = '';
  String _group = 'all';
  final List<ActivityEntry> _more = [];
  int _page = 1;
  bool _moreBusy = false;
  ApiException? _moreError;

  int? get _userId => int.tryParse(_person);

  void _choosePerson(String id) {
    setState(() {
      _person = id;
      _more.clear();
      _page = 1;
      _moreBusy = false;
      _moreError = null;
    });
  }

  Future<void> _loadMore() async {
    final key = _person;
    final next = _page + 1;
    setState(() {
      _moreBusy = true;
      _moreError = null;
    });
    final res = await guard(
      () => ref.read(activityRepositoryProvider).page((userId: int.tryParse(key), page: next)),
      onError: (e) {
        if (key == _person) _moreError = e;
      },
    );
    if (!mounted || key != _person) return;
    setState(() {
      _moreBusy = false;
      if (res != null) {
        _more.addAll(res.items);
        _page = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider).value ?? const <AppUser>[];
    final firstPage = ref.watch(activityProvider((userId: _userId, page: 1)));

    return PageScaffold(
      title: context.tr('Activity log', 'गतिविधि लग'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChipsRow<String>(
            value: _person,
            onChanged: _choosePerson,
            options: {'': context.tr('Everyone', 'सबै'), for (final u in staff) '${u.id}': u.name},
          ),
          const SizedBox(height: 10),
          ChipsRow<String>(
            value: _group,
            onChanged: (v) => setState(() => _group = v),
            options: {
              'all': context.tr('All', 'सबै'),
              'sales': context.tr('Sales', 'बिक्री'),
              'purchases': context.tr('Purchases', 'खरिद'),
              'money': context.tr('Money', 'पैसा'),
              'stock': context.tr('Stock', 'स्टक'),
              'vat': context.tr('VAT', 'भ्याट'),
            },
          ),
          const SizedBox(height: 12),
          AsyncBody(
            value: firstPage,
            onRetry: () => ref.invalidate(activityProvider((userId: _userId, page: 1))),
            data: (page) => _list(context, page),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, Paged<ActivityEntry> first) {
    final rows = [...first.items, ..._more];
    final kinds = _groupKinds[_group] ?? const <String>[];
    final shown = kinds.isEmpty ? rows : rows.where((e) => kinds.contains(e.kind)).toList();
    final total = first.meta.total;

    if (shown.isEmpty) {
      return SizedBox(
        height: 320,
        child: EmptyState(
          icon: Icons.history_rounded,
          title: context.tr('Nothing here yet', 'अहिले केही छैन'),
          text: context.tr(
            'Sales, stock changes and payments show here as they happen.',
            'बिक्री, स्टक परिवर्तन र भुक्तानी भए यहाँ देखिन्छ।',
          ),
        ),
      );
    }

    final byDay = <String, List<ActivityEntry>>{};
    for (final e in shown) {
      byDay.putIfAbsent(adOfStamp(e.at), () => []).add(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in byDay.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Text(
              _dayLabel(context, day.key),
              style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ),
          ListCard(
            children: [
              for (final e in day.value)
                _ActivityRow(
                  entry: e,
                  sentence: _sentence(context, e),
                  link: _linkOf(e),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text(
          context.tr(
            'Showing ${context.num(rows.length)} of ${context.num(total)} events',
            '${context.num(total)} मध्ये ${context.num(rows.length)} देखाइँदै',
          ),
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        if (_moreError != null) ...[
          const SizedBox(height: 8),
          AlertBox(_moreError!.message),
        ],
        if (rows.length < total) ...[
          const SizedBox(height: 12),
          PrimaryButton(
            label: _moreBusy ? context.tr('Loading…', 'लोड हुँदैछ…') : context.tr('Load more', 'थप लोड गर्ने'),
            busy: _moreBusy,
            onPressed: _loadMore,
          ),
        ],
      ],
    );
  }

  static String _dayLabel(BuildContext context, String day) {
    final date = formatDate(day);
    return day == todayAd() ? '${context.tr('Today', 'आज')} · $date' : date;
  }
}

class _Kind {
  const _Kind(this.icon, this.tone, this.en, this.ne);

  final IconData icon;
  final Tone tone;
  final String en;
  final String ne;
}

const _kinds = <String, _Kind>{
  'sale': _Kind(Icons.receipt_long_rounded, Tone.neutral, 'Sale', 'बिक्री'),
  'return': _Kind(Icons.keyboard_return_rounded, Tone.warn, 'Return', 'फिर्ता'),
  'cancel': _Kind(Icons.cancel_rounded, Tone.bad, 'Cancelled sale', 'रद्द बिक्री'),
  'purchase': _Kind(Icons.local_shipping_rounded, Tone.info, 'Purchase', 'खरिद'),
  'payment_in': _Kind(Icons.arrow_downward_rounded, Tone.good, 'Money in', 'पैसा आयो'),
  'payment_out': _Kind(Icons.arrow_upward_rounded, Tone.info, 'Money out', 'पैसा गयो'),
  'refund': _Kind(Icons.undo_rounded, Tone.warn, 'Refund', 'फिर्ता'),
  'expense': _Kind(Icons.receipt_rounded, Tone.bad, 'Expense', 'खर्च'),
  'stock_adjust': _Kind(Icons.tune_rounded, Tone.neutral, 'Stock change', 'स्टक परिवर्तन'),
  'stock_count': _Kind(Icons.checklist_rounded, Tone.neutral, 'Stock count', 'स्टक गणना'),
  'vat_filing': _Kind(Icons.account_balance_rounded, Tone.neutral, 'VAT filing', 'भ्याट फाइलिङ'),
};

/// Which kinds each filter shows. An empty list means all.
const _groupKinds = <String, List<String>>{
  'all': [],
  'sales': ['sale', 'return', 'cancel'],
  'purchases': ['purchase'],
  'money': ['payment_in', 'payment_out', 'refund', 'expense'],
  'stock': ['stock_adjust', 'stock_count'],
  'vat': ['vat_filing'],
};

String _qty(BuildContext context, int n) => '${n > 0 ? '+' : ''}${context.num(n)}';

String _sentence(BuildContext context, ActivityEntry e) {
  final who = e.by ?? context.tr('Someone', 'कसैले');
  final label = e.label ?? '-';
  final shownLabel = digits(label);
  final amt = context.rs(e.amount);
  return switch (e.kind) {
    'sale' => context.tr('$who made sale $label for $amt', '$who ले बिक्री $shownLabel बनाए, $amt'),
    'return' => context.tr('$who returned goods from sale $label, $amt', '$who ले बिक्री $shownLabel को सामान फिर्ता लिए, $amt'),
    'cancel' => context.tr('$who cancelled sale $label, $amt', '$who ले बिक्री $shownLabel रद्द गरे, $amt'),
    'purchase' => context.tr('$who recorded purchase $label for $amt', '$who ले खरिद $shownLabel थपे, $amt'),
    'payment_in' => context.tr('$who got $amt from $label', '$who ले $label बाट $amt पाए'),
    'payment_out' => context.tr('$who paid $amt to $label', '$who ले $label लाई $amt तिरे'),
    'refund' => context.tr('$who refunded $amt to $label', '$who ले $label लाई $amt फिर्ता गरे'),
    'expense' => context.tr('$who added expense $label, $amt', '$who ले खर्च $label थप्यो, $amt'),
    'stock_adjust' => context.tr(
        '$who adjusted stock of $label by ${_qty(context, e.amount)}',
        '$who ले $label को स्टक ${_qty(context, e.amount)} मिलाए',
      ),
    'stock_count' => context.tr(
        '$who counted stock of $label, change ${_qty(context, e.amount)}',
        '$who ले $label को स्टक गन्यो, फरक ${_qty(context, e.amount)}',
      ),
    'vat_filing' => context.tr('$who filed VAT for $shownLabel, $amt payable', '$who ले $shownLabel को भ्याट फाइल गरे, $amt तिर्नुपर्ने'),
    _ => '$who ${e.kind} $label',
  };
}

/// Sales and purchases open their own screen. Other kinds have no screen to open.
String? _linkOf(ActivityEntry e) => switch (e.kind) {
      'sale' || 'return' || 'cancel' => '/sales/${e.refId}',
      'purchase' => '/purchases/${e.refId}',
      _ => null,
    };

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry, required this.sentence, required this.link});

  final ActivityEntry entry;
  final String sentence;
  final String? link;

  @override
  Widget build(BuildContext context) {
    final kind = _kinds[entry.kind];
    final kindName = kind == null ? entry.kind : context.tr(kind.en, kind.ne);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(kind?.icon ?? Icons.info_outline_rounded, tone: kind?.tone ?? Tone.neutral, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sentence, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '$kindName · ${formatDate(entry.at)}',
                  style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(formatTime(entry.at), style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant)),
          if (link != null) Icon(Icons.chevron_right_rounded, color: context.scheme.onSurfaceVariant),
        ],
      ),
    );
    final openLink = link;
    if (openLink == null) return content;
    return InkWell(onTap: () => context.push(openLink), child: content);
  }
}
