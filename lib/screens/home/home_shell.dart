import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../alerts/alerts_screen.dart';
import '../family/family_screen.dart';
import '../hygiene/hygiene_screen.dart';
import '../scan/barcode_scanner_screen.dart';
import '../../services/silent_catalog_sync_service.dart';
import '../../services/recall_notification_service.dart';
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

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  final _recallNotifications = RecallNotificationService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_syncRecallPreferences);
    _recallNotifications.addListener(_handleRecallNotificationState);
    unawaited(SilentCatalogSyncService.instance.syncIfDue());
    unawaited(
      _recallNotifications.initialize(
        session: widget.session,
        onNotificationOpened: _openAlertsFromNotification,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(SilentCatalogSyncService.instance.syncIfDue());
      unawaited(_recallNotifications.syncPreferences(widget.session));
      unawaited(_recallNotifications.refreshUnreadState());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.session.removeListener(_syncRecallPreferences);
    _recallNotifications.removeListener(_handleRecallNotificationState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = IndexedStack(
      index: _index,
      children: [
        HomeScreen(
          session: widget.session,
          auth: widget.auth,
          onScan: _openScanner,
          onOpenHygiene: () => _selectTab(1),
          onOpenFamily: () => _selectTab(3),
          onOpenAlerts: () => _selectTab(2),
        ),
        HygieneScreen(session: widget.session),
        AlertsScreen(session: widget.session),
        FamilyScreen(session: widget.session, auth: widget.auth),
      ],
    );
    final alertsIcon = Badge(
      isLabelVisible: _recallNotifications.hasUnread,
      label: Text('${_recallNotifications.unreadCount}'),
      backgroundColor: AppColors.danger,
      textColor: Colors.white,
      largeSize: 19,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      offset: const Offset(7, -5),
      child: const Icon(Icons.notifications_none_rounded),
    );
    final selectedAlertsIcon = Badge(
      isLabelVisible: _recallNotifications.hasUnread,
      label: Text('${_recallNotifications.unreadCount}'),
      backgroundColor: AppColors.danger,
      textColor: Colors.white,
      largeSize: 19,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      offset: const Offset(7, -5),
      child: const Icon(
        Icons.notifications_rounded,
        color: AppColors.greenDark,
      ),
    );
    final navigationBar = NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: _selectTab,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded, color: AppColors.greenDark),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.restaurant_outlined),
          selectedIcon:
              Icon(Icons.restaurant_rounded, color: AppColors.greenDark),
          label: 'Hygiene',
        ),
        NavigationDestination(
          icon: alertsIcon,
          selectedIcon: selectedAlertsIcon,
          label: 'Alerts',
        ),
        const NavigationDestination(
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
                    onDestinationSelected: _selectTab,
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
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded,
                            color: AppColors.greenDark),
                        label: Text('Home'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.restaurant_outlined),
                        selectedIcon: Icon(Icons.restaurant_rounded,
                            color: AppColors.greenDark),
                        label: Text('Hygiene'),
                      ),
                      NavigationRailDestination(
                        icon: alertsIcon,
                        selectedIcon: selectedAlertsIcon,
                        label: const Text('Alerts'),
                      ),
                      const NavigationRailDestination(
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

  void _syncRecallPreferences() {
    unawaited(_recallNotifications.syncPreferences(widget.session));
  }

  void _openAlertsFromNotification() {
    _selectTab(2);
  }

  void _selectTab(int value) {
    if (mounted) setState(() => _index = value);
  }

  void _handleRecallNotificationState() {
    if (mounted) setState(() {});
  }
}
