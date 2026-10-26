import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/launch.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/reports/data/reports_repository.dart';
import 'package:pasal_mobile/features/reports/presentation/report_widgets.dart';

/// H4. Unpaid credit split into four age groups. Tap a group to see who owes in it, oldest first.
class CreditAgeScreen extends ConsumerStatefulWidget {
  const CreditAgeScreen({super.key});

  @override
  ConsumerState<CreditAgeScreen> createState() => _CreditAgeScreenState();
}

class _CreditAgeScreenState extends ConsumerState<CreditAgeScreen> {
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(creditAgeProvider);

    return PageScaffold(
      title: context.tr('Credit age', 'उधारोको उमेर'),
      onRefresh: () async => ref.invalidate(creditAgeProvider),
      body: AsyncBody(
        value: report,
        onRetry: () => ref.invalidate(creditAgeProvider),
        data: _content,
      ),
    );
  }

  Widget _content(CreditAge data) {
    if (data.customers.isEmpty) {
      return SizedBox(
        height: 360,
        child: EmptyState(
          icon: Icons.hourglass_bottom_rounded,
          title: context.tr('Nobody owes money', 'कसैको उधारो बाँकी छैन'),
          text: context.tr('Credit that is not paid shows here, oldest first.', 'नतिरेको उधारो यहाँ देखिन्छ, सबैभन्दा पुरानो पहिले।'),
        ),
      );
    }

    final parts = [
      for (final def in _groups)
        _Group(
          key: def.key,
          en: def.en,
          ne: def.ne,
          amount: data.buckets.where((b) => b.key == def.key).fold<int>(0, (n, b) => n + b.amount),
          bills: data.buckets.where((b) => b.key == def.key).fold<int>(0, (n, b) => n + b.bills),
          color: _colorOf(context, def.key),
        ),
    ];
    final total = data.total;
    final picked = _picked;
    final shown = data.customers.where((c) => picked == null || c.bucket == picked).toList();
    final pickedGroup = parts.where((p) => p.key == picked).firstOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          tone: Tone.warn,
          child: StatBlock(
            large: true,
            tone: Tone.warn,
            label: context.tr('To collect', 'उठाउन बाँकी'),
            value: context.rs(total),
            sub: context.tr('from ${context.num(data.customers.length)} customers', '${context.num(data.customers.length)} ग्राहकबाट'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr(
            'Money split by how old the unpaid bills are, as of ${formatDate(data.asOf)}. Tap a card to see who owes it.',
            'नतिरेका बिल कति पुराना हुन् त्यसअनुसार बाँडिएको, ${formatDate(data.asOf)} सम्मको। कसले कति दिनुपर्ने हेर्न कार्डमा थिच्नुहोस्।',
          ),
          style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (final p in parts)
                  if (p.amount > 0) Expanded(flex: p.amount, child: ColoredBox(color: p.color)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var row = 0; row < parts.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _GroupCard(group: parts[row], total: total, selected: picked == parts[row].key, onTap: () => _toggle(parts[row].key))),
              const SizedBox(width: 12),
              Expanded(child: _GroupCard(group: parts[row + 1], total: total, selected: picked == parts[row + 1].key, onTap: () => _toggle(parts[row + 1].key))),
            ],
          ),
        ],
        const SizedBox(height: 16),
        CardTitle(
          pickedGroup == null ? context.tr('Oldest first', 'सबैभन्दा पुरानो पहिले') : context.tr(pickedGroup.en, pickedGroup.ne),
          trailing: picked == null
              ? null
              : TextButton.icon(
                  onPressed: () => setState(() => _picked = null),
                  icon: const Icon(Icons.list_rounded),
                  label: Text(context.tr('Show all', 'सबै देखाउने')),
                ),
        ),
        if (shown.isEmpty)
          SizedBox(
            height: 140,
            child: EmptyState(icon: Icons.check_circle_rounded, title: context.tr('No one in this group', 'यो समूहमा कोही छैन')),
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in shown) ...[
                _CustomerCard(customer: c),
                const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }

  void _toggle(String key) => setState(() => _picked = _picked == key ? null : key);

  Color _colorOf(BuildContext context, String key) => switch (key) {
        'd0_30' => context.scheme.primary,
        'd31_60' => context.colors.warn,
        'd61_90' => Color.lerp(context.colors.warn, context.colors.bad, 0.5) ?? context.colors.warn,
        _ => context.colors.bad,
      };
}

class _Group {
  const _Group({required this.key, required this.en, required this.ne, required this.amount, required this.bills, required this.color});

  final String key;
  final String en;
  final String ne;
  final int amount;
  final int bills;
  final Color color;
}

const _groups = [
  (key: 'd0_30', en: '0 to 30 days', ne: '0 देखि 30 दिन'),
  (key: 'd31_60', en: '31 to 60 days', ne: '31 देखि 60 दिन'),
  (key: 'd61_90', en: '61 to 90 days', ne: '61 देखि 90 दिन'),
  (key: 'd90_plus', en: 'Over 90 days', ne: '90 दिनभन्दा बढी'),
];

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.total, required this.selected, required this.onTap});

  final _Group group;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final share = total > 0 ? group.amount / total : 0.0;
    final over = group.key == 'd90_plus';
    final border = selected ? context.scheme.primary : context.scheme.outlineVariant.withValues(alpha: 0.5);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: context.scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: border, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr(group.en, group.ne),
                  style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.rs(group.amount),
                    style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: over ? context.colors.bad : null),
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: share.clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(99),
                  color: group.color,
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    '${context.num(group.bills)} bills · ${context.num((share * 100).round())}% of total',
                    '${context.num(group.bills)} बिल · कुल बाँकीको ${context.num((share * 100).round())}%',
                  ),
                  style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final CreditCustomer customer;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final tone = switch (c.bucket) {
      'd90_plus' => Tone.bad,
      'd0_30' => Tone.primary,
      _ => Tone.warn,
    };
    final name = c.name;
    return PCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AvatarCircle(name ?? '?', tone: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name != null)
                      InkWell(
                        onTap: () => context.push('/customers/${c.customerId}'),
                        child: Text(name, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      )
                    else
                      Text(context.tr('Deleted customer', 'हटाइएको ग्राहक'), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      context.tr('Oldest bill ${context.num(c.oldestDays)} days ago', 'सबैभन्दा पुरानो बिल ${context.num(c.oldestDays)} दिन अघि'),
                      style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(context.rs(c.owes), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: context.colors.warn)),
                  Text(
                    context.tr('To collect', 'उठाउन बाँकी'),
                    style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (c.phone != null)
                TextButton.icon(
                  onPressed: () => callPhone(context, c.phone!),
                  icon: const Icon(Icons.call_rounded),
                  label: Text(context.tr('Call', 'फोन')),
                ),
              TextButton.icon(
                onPressed: () => context.push('/customers/${c.customerId}/remind'),
                icon: const Icon(Icons.notifications_active_rounded),
                label: Text(context.tr('Remind', 'सम्झाउने')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
