import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = switch (location) {
      final path when path.startsWith('/map') => 1,
      final path when path.startsWith('/planner') => 2,
      final path when path.startsWith('/saved') || path.startsWith('/ideas') =>
        3,
      final path when path.startsWith('/settings') => 4,
      _ => 0,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final destinations = [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: l10n.discover,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: l10n.map,
          ),
          NavigationDestination(
            icon: const Icon(Icons.edit_calendar_outlined),
            selectedIcon: const Icon(Icons.edit_calendar),
            label: l10n.planner,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_border),
            selectedIcon: const Icon(Icons.bookmark),
            label: l10n.saved,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune),
            selectedIcon: const Icon(Icons.tune),
            label: l10n.more,
          ),
        ];

        void goTab(int index) {
          switch (index) {
            case 0:
              context.goNamed('discover');
            case 1:
              context.goNamed('map');
            case 2:
              context.goNamed('planner');
            case 3:
              context.goNamed('saved');
            case 4:
              context.goNamed('settings');
          }
        }

        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: goTab,
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations
                      .map(
                        (destination) => NavigationRailDestination(
                          icon: destination.icon,
                          selectedIcon: destination.selectedIcon,
                          label: Text(destination.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          );
        }

        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: goTab,
            destinations: destinations,
          ),
        );
      },
    );
  }
}
