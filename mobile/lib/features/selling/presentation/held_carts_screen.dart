import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/selling/data/cart.dart';

/// Carts put on hold (/sell/held). Resume one to sell it, or discard it.
class HeldCartsScreen extends ConsumerWidget {
  const HeldCartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return PageScaffold(
      title: context.tr('Held carts', 'रोकिएका कार्ट'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cart.lines.isNotEmpty && cart.held.isNotEmpty) ...[
            AlertBox(
              context.tr('Your current cart will be held first when you resume a cart.', 'कार्ट फेरि सुरु गर्दा हालको कार्ट पहिले रोकिनेछ।'),
              tone: Tone.info,
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 12),
          ],
          if (cart.held.isEmpty)
            SizedBox(
              height: 420,
              child: EmptyState(
                icon: Icons.pause_circle_outline_rounded,
                title: context.tr('No held carts', 'कुनै कार्ट रोकिएको छैन'),
                text: context.tr('Hold a cart when a customer needs to wait. It shows here.', 'ग्राहकले पर्खनुपर्दा कार्ट रोक्न सकिन्छ। त्यो यहाँ देखिन्छ।'),
                actionLabel: context.tr('New sale', 'नयाँ बिक्री'),
                onAction: () => context.go('/sell'),
              ),
            )
          else
            for (final held in cart.held) ...[
              _HeldCard(held: held),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _HeldCard extends ConsumerWidget {
  const _HeldCard({required this.held});

  final HeldCart held;

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      title: context.tr('Discard this cart?', 'यो कार्ट हटाउने?'),
      message: context.tr(
        '${held.label.isEmpty ? '' : '${held.label}. '}The held cart and its items are removed. This cannot be undone.',
        '${held.label.isEmpty ? '' : '${held.label}। '}रोकिएको कार्ट र यसका सामान हट्छन्। यो फिर्ता हुँदैन।',
      ),
      confirmLabel: context.tr('Discard', 'हटाउने'),
      danger: true,
    );
    if (!ok || !context.mounted) return;
    ref.read(cartProvider.notifier).discard(held.id);
    showToast(context, 'Held cart deleted', 'रोकिएको कार्ट हटाइयो');
  }

  void _resume(BuildContext context, WidgetRef ref) {
    if (ref.read(cartProvider.notifier).restore(held.id)) context.go('/sell');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = totalOf(subtotalOf(held.lines), held.discount);
    final count = countOf(held.lines);
    final names = held.lines.map((l) => l.item.name).join(', ');

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.tr('Held at', 'रोकिएको')} ${formatTime(held.at)}',
                      style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                    Text(
                      held.label.isEmpty ? context.tr('No name', 'नाम छैन') : held.label,
                      style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              PBadge('${context.num(count)} ${context.tr('items', 'सामान')}', tone: Tone.primary),
            ],
          ),
          const SizedBox(height: 6),
          Text(names, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Total', 'जम्मा'), style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
                    Text(context.rs(total), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _discard(context, ref),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(context.tr('Discard', 'हटाउने')),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _resume(context, ref),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(context.tr('Resume', 'फेरि सुरु')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
