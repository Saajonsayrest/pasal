import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';

class _Link {
  const _Link(this.path, this.icon, this.en, this.ne, {this.owner = false, this.later = false});

  final String path;
  final IconData icon;
  final String en;
  final String ne;

  /// Staff do not see it.
  final bool owner;

  /// Not built in the app yet. The link still opens, with a "Later" badge.
  final bool later;
}

class _Group {
  const _Group(this.en, this.ne, this.links);

  final String en;
  final String ne;
  final List<_Link> links;
}

const _groups = <_Group>[
  _Group('Selling', 'बिक्री', [
    _Link('/sales', Icons.receipt_rounded, 'Sales list', 'बिक्री सूची'),
    _Link('/notifications', Icons.notifications_rounded, 'Notifications', 'सूचनाहरू'),
  ]),
  _Group('Stock', 'स्टक', [
    _Link('/stock-count', Icons.fact_check_rounded, 'Stock count', 'स्टक गणना', owner: true),
    _Link('/low-stock', Icons.production_quantity_limits_rounded, 'Low stock and reorder', 'कम स्टक र पुनः अर्डर', owner: true),
    _Link('/categories', Icons.category_rounded, 'Categories', 'वर्गहरू', owner: true),
  ]),
  _Group('Buying', 'खरिद', [
    _Link('/purchases', Icons.shopping_bag_rounded, 'Purchases', 'खरिदहरू', owner: true),
    _Link('/suppliers', Icons.local_shipping_rounded, 'Suppliers', 'डिलरहरू', owner: true),
  ]),
  _Group('Money', 'पैसा', [
    _Link('/expenses', Icons.payments_rounded, 'Expenses', 'खर्चहरू', owner: true),
    _Link('/cash-book', Icons.account_balance_wallet_rounded, 'Cash book', 'नगद किताब', owner: true),
    _Link('/payments', Icons.swap_vert_rounded, 'All payments', 'सबै भुक्तानी', owner: true),
  ]),
  _Group('Reports and VAT', 'रिपोर्ट र भ्याट', [
    _Link('/reports', Icons.insights_rounded, 'Reports', 'रिपोर्टहरू', owner: true),
    _Link('/vat', Icons.receipt_long_rounded, 'VAT', 'भ्याट', owner: true),
  ]),
  _Group('Settings', 'सेटिङ', [
    _Link('/settings/shop', Icons.storefront_rounded, 'Shop details', 'पसलको विवरण', owner: true),
    _Link('/settings/staff', Icons.badge_rounded, 'Staff', 'कर्मचारी', owner: true),
    _Link('/settings/look', Icons.palette_rounded, 'App look and language', 'एपको रूप र भाषा'),
    _Link('/settings/printer', Icons.print_rounded, 'Printer', 'प्रिन्टर', later: true),
    _Link('/settings/activity', Icons.history_rounded, 'Activity log', 'गतिविधि लग', owner: true),
  ]),
];

/// Tab 5. Every other screen, in groups. Owner-only links are hidden for staff.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final name = user?.name ?? '';

    final groups = <_Group>[];
    for (final group in _groups) {
      final links = group.links.where((l) => session.isOwner || !l.owner).toList();
      if (links.isNotEmpty) groups.add(_Group(group.en, group.ne, links));
    }

    return PageScaffold(
      title: context.tr('Everything else', 'अरू सबै'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PCard(
            onTap: () => context.push('/profile'),
            child: Row(
              children: [
                AvatarCircle(name, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        '${session.business?.name ?? 'PASAL'} · ${session.isOwner ? context.tr('Owner', 'मालिक') : context.tr('Staff', 'कर्मचारी')}',
                        style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.scheme.onSurfaceVariant),
              ],
            ),
          ),
          for (final group in groups) ...[
            SectionTitle(context.tr(group.en, group.ne)),
            ListCard(
              children: [
                for (final link in group.links)
                  ListRow(
                    leading: IconTile(link.icon, tone: Tone.neutral, size: 40),
                    title: context.tr(link.en, link.ne),
                    trailing: link.later ? PBadge(context.tr('Later', 'पछि')) : null,
                    onTap: () => context.push(link.path),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: context.colors.bad, foregroundColor: Colors.white),
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.tr('Sign out', 'साइन आउट')),
          ),
        ],
      ),
    );
  }
}
