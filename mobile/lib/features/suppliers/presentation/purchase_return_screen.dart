import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/suppliers/presentation/supplier_widgets.dart';

/// F6. Purchase return. Planned for later: every control is disabled and the screen only shows the layout.
class PurchaseReturnScreen extends StatelessWidget {
  const PurchaseReturnScreen({super.key});

  static const _reasons = <({String en, String ne})>[
    (en: 'Damaged', ne: 'क्षति भएको'),
    (en: 'Expired', ne: 'म्याद सकिएको'),
    (en: 'Wrong item', ne: 'गलत सामान'),
  ];

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: context.tr('Purchase return', 'खरिद फिर्ता'),
      bottom: PrimaryButton(
        label: context.tr('Save return', 'फिर्ता सेभ गर्ने'),
        icon: Icons.check_rounded,
        onPressed: null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PCard(
            tone: Tone.info,
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, color: context.colors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr(
                      'Planned after the first release. Shown for review only.',
                      'यो पहिलो रिलिजपछि बन्ने योजना हो। अहिले समीक्षाका लागि मात्र।',
                    ),
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AlertBox(
            context.tr(
              'Purchase returns need a change on the server first. Until then, fix the stock by hand from the item page.',
              'खरिद फिर्ताका लागि पहिले सर्भरमा परिवर्तन चाहिन्छ। तबसम्म सामानको पेजबाट स्टक हातले मिलाउनुहोस्।',
            ),
            tone: Tone.warn,
            icon: Icons.construction_rounded,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/items'),
              icon: const Icon(Icons.inventory_2_rounded),
              label: Text(context.tr('Go to items', 'सामानमा जाने')),
            ),
          ),
          const SizedBox(height: 12),
          ListCard(
            children: [
              ListRow(
                leading: const IconTile(Icons.receipt_long_rounded, tone: Tone.info),
                title: context.tr('Choose purchase', 'खरिद छान्नुहोस्'),
                subtitle: context.tr('The bill with the goods to send back', 'फिर्ता पठाउने सामान भएको बिल'),
                chevron: false,
              ),
            ],
          ),
          SectionHeading(context.tr('Items to send back', 'फिर्ता पठाउने सामान')),
          PCard(
            child: Text(
              context.tr('Items from the chosen bill appear here.', 'छानेको बिलका सामान यहाँ देखिन्छन्।'),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ),
          SectionHeading(context.tr('Reason', 'कारण')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _reasons.length; i++)
                ChoiceChip(
                  label: Text(context.tr(_reasons[i].en, _reasons[i].ne)),
                  selected: i == 0,
                  showCheckmark: false,
                  onSelected: null,
                ),
            ],
          ),
          const SizedBox(height: 14),
          PCard(
            child: Column(
              children: [
                KeyValueRow(label: context.tr('Goods value (before VAT)', 'सामानको मूल्य (भ्याट बाहेक)'), value: context.rs(0)),
                KeyValueRow(label: context.tr('VAT', 'भ्याट'), value: context.rs(0)),
                KeyValueRow(label: context.tr('We owe less', 'हामीले कम तिर्ने'), value: context.rs(0), valueColor: context.colors.good, strong: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PCard(
            tone: Tone.warn,
            child: Row(
              children: [
                Icon(Icons.inventory_2_rounded, color: context.colors.warn),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('Stock goes down', 'स्टक घट्छ'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        context.tr('Stock of the returned items goes down when you save.', 'सेभ गरेपछि फिर्ता गरिएका सामानको स्टक घट्छ।'),
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
