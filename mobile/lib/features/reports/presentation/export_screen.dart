import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/reports/data/csv_share.dart';
import 'package:pasal_mobile/features/reports/data/export_tables.dart';
import 'package:pasal_mobile/features/reports/data/range.dart';
import 'package:pasal_mobile/features/reports/data/reports_repository.dart';
import 'package:pasal_mobile/features/reports/presentation/range_picker.dart';

/// H6. Lists as CSV files, shared from the phone. Excel and PDF are not built.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  DateRange _range = rangeFor(RangePreset.month);
  final Set<ExportSet> _picked = {ExportSet.sales};
  bool _busy = false;
  String? _error;
  String? _done;
  ExportSet? _current;
  int _page = 0;
  int _last = 0;

  void _toggle(ExportSet set) {
    setState(() {
      if (!_picked.add(set)) _picked.remove(set);
    });
  }

  Future<void> _export() async {
    final failed = context.tr('Could not share the files.', 'फाइल पठाउन सकिएन।');
    final done = context.tr('Done. Choose where to save or send the files.', 'सकियो। फाइल कहाँ राख्ने वा पठाउने छान्नुहोस्।');
    final repo = ref.read(reportsRepositoryProvider);
    final share = ref.read(csvSharerProvider);

    setState(() {
      _busy = true;
      _error = null;
      _done = null;
      _current = null;
      _page = 0;
      _last = 0;
    });

    final files = await guard(
      () => repo.exportCsv(
        range: _range,
        sets: Set.of(_picked),
        onPage: (set, page, last) {
          if (!mounted) return;
          setState(() {
            _current = set;
            _page = page;
            _last = last;
          });
        },
      ),
      onError: (e) => _error = e.message,
    );
    if (!mounted) return;
    if (files == null) {
      setState(() => _busy = false);
      return;
    }

    try {
      await share(files);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = done;
      });
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failed;
      });
    }
  }

  String _setName(ExportSet set) => switch (set) {
        ExportSet.sales => context.tr('Sales', 'बिक्री'),
        ExportSet.purchases => context.tr('Purchases', 'खरिद'),
        ExportSet.payments => context.tr('Payments', 'भुक्तानी'),
        ExportSet.expenses => context.tr('Expenses', 'खर्च'),
        ExportSet.items => context.tr('Items', 'सामान'),
        ExportSet.customers => context.tr('Customers', 'ग्राहक'),
      };

  IconData _setIcon(ExportSet set) => switch (set) {
        ExportSet.sales => Icons.receipt_long_rounded,
        ExportSet.purchases => Icons.shopping_bag_rounded,
        ExportSet.payments => Icons.payments_rounded,
        ExportSet.expenses => Icons.paid_rounded,
        ExportSet.items => Icons.inventory_2_rounded,
        ExportSet.customers => Icons.group_rounded,
      };

  String _progressText(ExportSet set, int page, int last) {
    final name = _setName(set);
    return context.tr(
      '$name: page ${context.num(page)} of ${context.num(last)}',
      '$name: पृष्ठ ${context.num(page)} / ${context.num(last)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final canExport = !_busy && _picked.isNotEmpty;
    final current = _current;

    return PageScaffold(
      title: context.tr('Export', 'निर्यात'),
      bottom: PrimaryButton(
        label: _busy ? context.tr('Preparing…', 'तयार हुँदैछ…') : context.tr('Share CSV', 'CSV पठाउने'),
        icon: Icons.ios_share_rounded,
        busy: _busy,
        onPressed: canExport ? _export : null,
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(context.tr('Date range', 'मिति दायरा')),
          const SizedBox(height: 8),
          RangePicker(value: _range, onChanged: (r) => setState(() => _range = r)),
          const SizedBox(height: 20),
          SectionTitle(context.tr('Choose lists', 'सूची छान्नुहोस्')),
          const SizedBox(height: 8),
          ListCard(
            children: [
              for (final set in ExportSet.values)
                ListRow(
                  leading: IconTile(_setIcon(set)),
                  title: _setName(set),
                  subtitle: set.dated ? null : context.tr('Whole list, not by date', 'सबै सूची, मितिअनुसार होइन'),
                  chevron: false,
                  onTap: _busy ? null : () => _toggle(set),
                  trailing: Switch(
                    value: _picked.contains(set),
                    onChanged: _busy ? null : (_) => _toggle(set),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            AlertBox(_error!),
            const SizedBox(height: 12),
          ],
          if (_busy) ...[
            Text(
              current == null ? context.tr('Getting the data…', 'डाटा लिँदैछ…') : _progressText(current, _page, _last),
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _last > 0 ? _page / _last : null,
              minHeight: 6,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 12),
          ] else if (_done != null) ...[
            Text(_done!, style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
          ],
          AlertBox(
            context.tr(
              'Excel and PDF are not built yet. Each list you pick is one CSV file. Open it in Excel or Google Sheets. Items and customers always give the whole list.',
              'एक्सेल र PDF अहिले बनेको छैन। छानिएको हरेक सूची एउटा CSV फाइल हो। यसलाई एक्सेल वा गुगल सिटमा खोल्नुहोस्। सामान र ग्राहक सधैँ पूरा सूची हुन्।',
            ),
            tone: Tone.info,
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }
}
