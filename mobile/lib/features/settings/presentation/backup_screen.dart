import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/settings/data/backup_repository.dart';
import 'package:pasal_mobile/features/settings/data/csv.dart';
import 'package:share_plus/share_plus.dart';

class _ExportRow {
  const _ExportRow({
    required this.kind,
    required this.icon,
    required this.en,
    required this.ne,
    required this.sub,
    required this.subNe,
    required this.label,
    required this.labelNe,
  });

  final ExportKind kind;
  final IconData icon;
  final String en;
  final String ne;
  final String sub;
  final String subNe;

  /// The list name used in the progress line ("Loading items, page 2 of 5").
  final String label;
  final String labelNe;
}

const _exports = <_ExportRow>[
  _ExportRow(
    kind: ExportKind.items,
    icon: Icons.table_view_rounded,
    en: 'Items (CSV)',
    ne: 'सामानहरू (CSV)',
    sub: 'All items, prices and stock',
    subNe: 'सबै सामान, भाउ र स्टक',
    label: 'items',
    labelNe: 'सामान',
  ),
  _ExportRow(
    kind: ExportKind.customers,
    icon: Icons.group_rounded,
    en: 'Customers (CSV)',
    ne: 'ग्राहकहरू (CSV)',
    sub: 'Names, phones and balances',
    subNe: 'नाम, फोन र बाँकी उधारो',
    label: 'customers',
    labelNe: 'ग्राहक',
  ),
  _ExportRow(
    kind: ExportKind.suppliers,
    icon: Icons.local_shipping_rounded,
    en: 'Suppliers (CSV)',
    ne: 'डिलरहरू (CSV)',
    sub: 'Names, phones and what we owe',
    subNe: 'नाम, फोन र बाँकी',
    label: 'suppliers',
    labelNe: 'डिलर',
  ),
  _ExportRow(
    kind: ExportKind.sales,
    icon: Icons.receipt_long_rounded,
    en: 'Sales (CSV)',
    ne: 'बिक्री (CSV)',
    sub: 'All bills with dates',
    subNe: 'मिति सहित सबै बिल',
    label: 'sales',
    labelNe: 'बिक्री',
  ),
  _ExportRow(
    kind: ExportKind.expenses,
    icon: Icons.receipt_rounded,
    en: 'Expenses (CSV)',
    ne: 'खर्च (CSV)',
    sub: 'All expenses with dates',
    subNe: 'मिति सहित सबै खर्च',
    label: 'expenses',
    labelNe: 'खर्च',
  ),
];

/// Exports the shop lists as CSV files and opens the phone's share sheet. Owner only.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  _ExportRow? _current;
  int _page = 0;
  int _lastPage = 0;
  bool _busy = false;
  bool _done = false;
  ApiException? _error;

  Future<void> _export(_ExportRow row) async {
    // iPad shows the share sheet as a popover, which needs an anchor on screen.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _busy = true;
      _current = row;
      _page = 0;
      _lastPage = 0;
      _done = false;
      _error = null;
    });
    final repo = ref.read(backupRepositoryProvider);
    final ok = await guard(
      () async {
        final text = await repo.build(
          row.kind,
          onProgress: (_, page, lastPage) {
            if (!mounted) return;
            setState(() {
              _page = page;
              _lastPage = lastPage;
            });
          },
        );
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(csvBytes(text), mimeType: 'text/csv', name: 'pasal-${row.kind.name}-${todayAd()}.csv')],
            sharePositionOrigin: origin,
          ),
        );
        return true;
      },
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = ok ?? false;
    });
  }

  String _progressText(BuildContext context) {
    final row = _current;
    if (row == null || _page == 0) return context.tr('Starting…', 'सुरु हुँदैछ…');
    return context.tr(
      'Loading ${row.label}, page ${context.num(_page)} of ${context.num(_lastPage)}',
      '${row.labelNe} लोड हुँदैछ, पेज ${context.num(_page)} / ${context.num(_lastPage)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: context.tr('Backup and export', 'ब्याकअप र निर्यात'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AlertBox(
            context.tr(
              'These are CSV files made on this phone from your live shop data. Open them in Excel or Google Sheets.',
              'ये यो फोनमा तपाईंको पसलको ताजा डेटाबाट बनेका CSV फाइल हुन्। Excel वा Google Sheets मा खोल्नुहोस्।',
            ),
            tone: Tone.info,
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'A full database backup is made on the server, not in this app. Daily backups are not built yet.',
              'पूरा डेटाबेस ब्याकअप सर्भरमा बनाइन्छ, यो एपमा होइन। दैनिक ब्याकअप अझै बनेको छैन।',
            ),
            style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            PCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_progressText(context), style: context.text.bodyMedium),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: _lastPage > 0 ? _page / _lastPage : null),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            AlertBox(_error!.message),
          ],
          if (_done) ...[
            const SizedBox(height: 12),
            PCard(
              tone: Tone.good,
              child: Text(context.tr('The file is ready to save or send.', 'फाइल तयार छ। सेभ वा पठाउन छान्नुहोस्।')),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(context.tr('Export', 'निर्यात गर्ने'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          ListCard(
            children: [
              for (final row in _exports)
                ListRow(
                  leading: IconTile(row.icon),
                  title: context.tr(row.en, row.ne),
                  subtitle: context.tr(row.sub, row.subNe),
                  trailing: Icon(Icons.file_download_rounded, color: context.scheme.onSurfaceVariant),
                  chevron: false,
                  onTap: _busy ? null : () => _export(row),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
