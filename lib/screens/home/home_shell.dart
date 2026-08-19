import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../alerts/alerts_screen.dart';
import '../family/family_screen.dart';
import '../scan/barcode_scanner_screen.dart';
import 'home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.session,
    required this.auth,
  });

  final AppSession session;
  final AuthController auth;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final content = IndexedStack(
      index: _index,
      children: [
        HomeScreen(
          session: widget.session,
          onScan: _openScanner,
          onOpenFamily: () => setState(() => _index = 2),
          onOpenAlerts: () => setState(() => _index = 1),
        ),
        AlertsScreen(session: widget.session),
        FamilyScreen(session: widget.session, auth: widget.auth),
      ],
    );
    final navigationBar = NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (value) => setState(() => _index = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded, color: AppColors.greenDark),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none_rounded),
          selectedIcon:
              Icon(Icons.notifications_rounded, color: AppColors.greenDark),
          label: 'Alerts',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline_rounded),
          selectedIcon: Icon(Icons.people_rounded, color: AppColors.greenDark),
          label: 'Family',
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 860) {
          return Scaffold(
            backgroundColor: AppColors.canvas,
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    extended: constraints.maxWidth >= 1120,
                    selectedIndex: _index,
                    onDestinationSelected: (value) =>
                        setState(() => _index = value),
                    backgroundColor: const Color(0xFFF8FFF9),
                    indicatorColor: AppColors.mint,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 24),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.acid,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.greenDark),
                        ),
                        child: const Icon(Icons.health_and_safety_rounded,
                            color: AppColors.greenDark, size: 28),
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded,
                            color: AppColors.greenDark),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.notifications_none_rounded),
                        selectedIcon: Icon(Icons.notifications_rounded,
                            color: AppColors.greenDark),
                        label: Text('Alerts'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.people_outline_rounded),
                        selectedIcon: Icon(Icons.people_rounded,
                            color: AppColors.greenDark),
                        label: Text('Family'),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: AppGradients.page,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppGradients.page),
            child: content,
          ),
          bottomNavigationBar: navigationBar,
        );
      },
    );
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => BarcodeScannerScreen(session: widget.session),
      ),
    );
    if (mounted) setState(() => _index = 0);
  }
}
