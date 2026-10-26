import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';

/// D11. A "Later" screen. Expiry dates need a server change first, so the controls are off and the rows are examples.
class ExpiryScreen extends StatelessWidget {
  const ExpiryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: context.tr('Expiry dates', 'म्याद सकिने मिति'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PCard(
            tone: Tone.info,
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('Planned after the first release. Example only.', 'यो पहिलो रिलिजपछि आउने स्क्रिन हो। अहिले नमुना मात्र हो।'),
                    style: context.text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AlertBox(
            context.tr(
              'Expiry dates need a change in the server first. The app does not save them yet.',
              'म्याद मिति देखाउन पहिले सर्भरमा परिवर्तन चाहिन्छ। एपले अहिले मिति सुरक्षित गर्दैन।',
            ),
            tone: Tone.info,
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: Text(context.tr('Expired', 'म्याद नाघेको')), selected: false, onSelected: null),
              ChoiceChip(label: Text(context.tr('This week', 'यो हप्ता')), selected: false, onSelected: null),
              ChoiceChip(label: Text(context.tr('This month', 'यो महिना')), selected: true, onSelected: null),
            ],
          ),
          const SizedBox(height: 12),
          ListCard(
            children: [
              ListRow(
                leading: const _EmojiTile('🥛'),
                title: context.tr('Milk 500ml', 'दूध ५०० मिलि'),
                subtitle: context.tr('Batch MK-1182 · Expiry Kartik 5, 2083 · 22 Oct 2026', 'ब्याच MK-1182 · म्याद कात्तिक ५, २०८३ · 22 Oct 2026'),
                chevron: false,
                trailing: _EndCell(amount: context.tr('6 pcs', '६ पिस'), badge: PBadge(context.tr('Expired', 'म्याद नाघ्यो'), tone: Tone.bad)),
              ),
              ListRow(
                leading: const _EmojiTile('🍪'),
                title: context.tr('Biscuits', 'बिस्कुट'),
                subtitle: context.tr('Batch BS-0930 · Expiry Kartik 12, 2083 · 29 Oct 2026', 'ब्याच BS-0930 · म्याद कात्तिक १२, २०८३ · 29 Oct 2026'),
                chevron: false,
                trailing: _EndCell(amount: context.tr('10 pcs', '१० पिस'), badge: PBadge(context.tr('3 days left', '३ दिन बाँकी'), tone: Tone.warn)),
              ),
              ListRow(
                leading: const _EmojiTile('🥚'),
                title: context.tr('Eggs (tray of 30)', 'अण्डा (३० वटा)'),
                subtitle: context.tr('Batch EG-0717 · Expiry Kartik 20, 2083 · 6 Nov 2026', 'ब्याच EG-0717 · म्याद कात्तिक २०, २०८३ · 6 Nov 2026'),
                chevron: false,
                trailing: _EndCell(amount: context.tr('4 pcs', '४ पिस'), note: context.tr('11 days left', '११ दिन बाँकी')),
              ),
              ListRow(
                leading: const _EmojiTile('🍵'),
                title: context.tr('Tea leaves 500g', 'चियापत्ती ५०० ग्रा'),
                subtitle: context.tr('Batch TL-0601 · Expiry Kartik 30, 2083 · 16 Nov 2026', 'ब्याच TL-0601 · म्याद कात्तिक ३०, २०८३ · 16 Nov 2026'),
                chevron: false,
                trailing: _EndCell(amount: context.tr('12 pcs', '१२ पिस'), note: context.tr('21 days left', '२१ दिन बाँकी')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmojiTile extends StatelessWidget {
  const _EmojiTile(this.emoji);

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: context.scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(Radii.md)),
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
  }
}

class _EndCell extends StatelessWidget {
  const _EndCell({required this.amount, this.badge, this.note});

  final String amount;
  final Widget? badge;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(amount, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ?badge,
        if (note case final text?) Text(text, style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant)),
      ],
    );
  }
}
