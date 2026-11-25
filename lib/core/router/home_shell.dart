import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../l10n/l10n.dart';
import '../theme/aule_colors.dart';

/// The three tabs: Avance · Familia · Privacidad. Each keeps its own stack.
///
/// Android back pops within a tab, then goes to the Progress tab, then
/// leaves the app: go_router asks the tab's navigator first, and the
/// [PopScope] here turns a back press on another tab's first screen into a
/// switch to Progress.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unread = context.select<AuthController, int>(
      (auth) => auth.me?.unreadNotices ?? 0,
    );
    final index = navigationShell.currentIndex;
    return PopScope<Object?>(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        backgroundColor: AuleColors.paper,
        body: navigationShell,
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AuleColors.line)),
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (next) => navigationShell.goBranch(
              next,
              // Tapping the open tab again goes back to its first screen.
              initialLocation: next == navigationShell.currentIndex,
            ),
            destinations: <Widget>[
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.insights_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.insights),
                ),
                label: l10n.tabProgress,
                tooltip: unread > 0 ? l10n.progressUnread(unread) : null,
              ),
              NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: l10n.tabFamily,
              ),
              NavigationDestination(
                icon: const Icon(Icons.shield_outlined),
                selectedIcon: const Icon(Icons.shield),
                label: l10n.tabPrivacy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
