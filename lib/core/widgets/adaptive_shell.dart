import 'package:flutter/material.dart';
import 'package:recall/app/router.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

/// Bottom bar on phones, rail on wide screens.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  int get _index => location.startsWith('/stats')
      ? 1
      : location.startsWith('/settings')
      ? 2
      : 0;

  void _go(BuildContext context, int i) => switch (i) {
    1 => const StatsRoute().go(context),
    2 => const SettingsRoute().go(context),
    _ => const DecksRoute().go(context),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = [
      (Icons.style_outlined, Icons.style, l.navDecks),
      (Icons.insights_outlined, Icons.insights, l.navStats),
      (Icons.tune_outlined, Icons.tune, l.navSettings),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 600;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => _go(context, i),
              destinations: [
                for (final (icon, selected, label) in items)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => _go(context, i),
        destinations: [
          for (final (icon, selected, label) in items)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}
