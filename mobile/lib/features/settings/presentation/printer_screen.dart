import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/settings/data/shop_repository.dart';

/// Printer. Not built yet: the controls are shown disabled, with a sample bill to show the layout.
class PrinterScreen extends ConsumerWidget {
  const PrinterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(sessionProvider).business;
    final footer = readBillFooter(ref.watch(sharedPrefsProvider));

    return PageScaffold(
      title: context.tr('Printer', 'प्रिन्टर'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AlertBox(
            context.tr('Planned after the first release. This is a preview only.', 'यो पहिलो रिलिजपछि आउनेछ। अहिले यो नमुना मात्र हो।'),
            tone: Tone.info,
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(height: 16),
          _heading(context, context.tr('Bluetooth printers', 'ब्लुटुथ प्रिन्टर')),
          const SizedBox(height: 8),
          ListCard(
            children: [
              ListRow(
                leading: const IconTile(Icons.print_rounded),
                title: context.tr('No printer paired yet', 'अहिलेसम्म कुनै प्रिन्टर जोडिएको छैन'),
                subtitle: context.tr('Pairing comes in a later update.', 'जोड्ने काम पछिल्लो अपडेटमा आउनेछ।'),
                trailing: TextButton(onPressed: null, child: Text(context.tr('Pair', 'जोड्ने'))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heading(context, context.tr('Paper size', 'कागजको साइज')),
                const SizedBox(height: 12),
                Opacity(
                  opacity: 0.5,
                  child: IgnorePointer(
                    child: Seg<String>(value: '58', onChanged: (_) {}, options: const {'58': '58mm', '80': '80mm'}),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(label: context.tr('Test print', 'टेस्ट प्रिन्ट'), icon: Icons.print_rounded, onPressed: null),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _heading(context, context.tr('Receipt preview', 'बिलको नमुना')),
          const SizedBox(height: 8),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: PCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      business?.name ?? 'PASAL',
                      textAlign: TextAlign.center,
                      style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (business?.address != null)
                      Text(business!.address!, textAlign: TextAlign.center, style: _muted(context)),
                    if (business?.pan != null) Text('PAN ${business!.pan}', textAlign: TextAlign.center, style: _muted(context)),
                    const Divider(height: 24),
                    _line(context, context.tr('Bill', 'बिल'), 'S-0413'),
                    _line(context, context.tr('Basmati rice 5kg × 2', 'बासमती चामल ५ केजी × २'), context.rs(210000)),
                    _line(context, context.tr('Sugar 1kg', 'चिनी १ केजी'), context.rs(11500)),
                    _line(context, context.tr('VAT included', 'भ्याट सहित'), context.rs(25482, paisaDigits: true)),
                    const Divider(height: 24),
                    _line(context, context.tr('Total', 'जम्मा'), context.rs(221500), bold: true),
                    const SizedBox(height: 12),
                    Text(footer, textAlign: TextAlign.center, style: _muted(context)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _heading(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
      );

  static TextStyle? _muted(BuildContext context) => context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant);

  static Widget _line(BuildContext context, String label, String value, {bool bold = false}) {
    final style = context.text.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.w800 : FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
