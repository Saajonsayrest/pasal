import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';

/// The frame around the five main screens: Home, Items, Sell (big middle button), Customers, More.
/// Phone: bottom menu. Wide screens (tablet): side rail.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final items = <({IconData icon, IconData selected, String en, String ne})>[
      (icon: Icons.home_outlined, selected: Icons.home_rounded, en: 'Home', ne: 'गृह'),
      (icon: Icons.inventory_2_outlined, selected: Icons.inventory_2_rounded, en: 'Items', ne: 'सामान'),
      (icon: Icons.add_shopping_cart_outlined, selected: Icons.add_shopping_cart_rounded, en: 'Sell', ne: 'बेच्ने'),
      (icon: Icons.group_outlined, selected: Icons.group_rounded, en: 'Customers', ne: 'ग्राहक'),
      (icon: Icons.menu_rounded, selected: Icons.menu_open_rounded, en: 'More', ne: 'थप'),
    ];

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final i in items)
                  NavigationRailDestination(icon: Icon(i.icon), selectedIcon: Icon(i.selected), label: Text(context.tr(i.en, i.ne))),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final i in items)
            NavigationDestination(icon: Icon(i.icon), selectedIcon: Icon(i.selected), label: context.tr(i.en, i.ne)),
        ],
      ),
    );
  }
}
