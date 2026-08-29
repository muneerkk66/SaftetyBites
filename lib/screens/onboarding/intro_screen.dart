import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../services/recall_notification_service.dart';
import '../../widgets/brand_mark.dart';
import '../legal/privacy_policy_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _notifications = RecallNotificationService.instance;
  int _page = 0;
  bool _locating = false;
  bool _notificationBusy = false;
  bool _locationReady = false;
  String? _locationError;
  RecallNotificationStatus _notificationStatus =
      RecallNotificationStatus.notRequested;

  @override
  void initState() {
    super.initState();
    _locationReady = widget.session.hasLocation;
    unawaited(
      _notifications.initialize(
        session: widget.session,
        onNotificationOpened: () {},
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPermissionState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(
          child: Column(
            children: [
              _IntroHeader(
                page: _page,
                onBack: _page == 0 ? null : () => setState(() => _page = 0),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_page),
                    child: _page == 0 ? _buildOverview() : _buildPermissions(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverview() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 680,
              minHeight: constraints.maxHeight - 44,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(minHeight: 390),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    image: const DecorationImage(
                      image: AssetImage(
                        'assets/images/safebite-grocery-hero-v1.png',
                      ),
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.greenDark.withValues(alpha: 0.24),
                        blurRadius: 34,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.greenDark.withValues(alpha: 0.98),
                          AppColors.greenDark.withValues(alpha: 0.76),
                          AppColors.greenDark.withValues(alpha: 0.08),
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FOOD SAFETY FOR YOUR FAMILY',
                              style: TextStyle(
                                color: AppColors.acid,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.25,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Know before\nyou bite.',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 46,
                                    height: 0.94,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Scan food, check household allergens and receive recalls from the supermarkets you choose.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.84),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(
                      child: _FeatureTile(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Scan',
                        detail: 'Check products for everyone.',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _FeatureTile(
                        icon: Icons.notifications_active_rounded,
                        title: 'Protect',
                        detail: 'Get relevant UK recalls.',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _FeatureTile(
                        icon: Icons.restaurant_rounded,
                        title: 'Explore',
                        detail: 'View nearby hygiene ratings.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => setState(() => _page = 1),
                  child: const Text('See how SafeBiteAI protects you'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: AppColors.acid,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Set up your protection',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Allow these two features now so nearby hygiene checks and selected-store recalls work from day one.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 24),
              _PermissionCard(
                icon: Icons.location_on_rounded,
                title: 'Your location',
                detail: _locationDetail,
                status: _locationReady
                    ? _PermissionState.ready
                    : _locationError == null
                        ? _PermissionState.pending
                        : _PermissionState.problem,
                actionLabel:
                    _locationReady ? 'Location ready' : 'Allow location',
                busy: _locating,
                onPressed:
                    _locating || _locationReady ? null : _requestLocation,
              ),
              const SizedBox(height: 12),
              _PermissionCard(
                icon: Icons.notifications_active_rounded,
                title: 'Recall notifications',
                detail: _notificationDetail,
                status: _notificationStatus == RecallNotificationStatus.enabled
                    ? _PermissionState.ready
                    : _notificationStatus == RecallNotificationStatus.denied
                        ? _PermissionState.problem
                        : _PermissionState.pending,
                actionLabel:
                    _notificationStatus == RecallNotificationStatus.enabled
                        ? 'Notifications ready'
                        : 'Enable notifications',
                busy: _notificationBusy,
                onPressed: _notificationBusy ||
                        _notificationStatus ==
                            RecallNotificationStatus.enabled ||
                        _notificationStatus ==
                            RecallNotificationStatus.unavailable
                    ? null
                    : _requestNotifications,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, color: AppColors.green),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'SafeBiteAI uses your approximate area for nearby results. Recall notifications are limited to supermarkets you select.',
                        style: TextStyle(color: AppColors.ink, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _locating || _notificationBusy
                    ? null
                    : widget.session.completeIntro,
                child: const Text('Continue'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _openPrivacyPolicy,
                  icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                  label: const Text('How we use your data'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _locationDetail {
    if (_locationReady) {
      return widget.session.postcode.isEmpty
          ? 'Your approximate location is ready.'
          : '${widget.session.postcode} is ready for nearby results.';
    }
    return _locationError ??
        'Find nearby food hygiene ratings and supermarket branches.';
  }

  String get _notificationDetail {
    return switch (_notificationStatus) {
      RecallNotificationStatus.enabled =>
        'You can receive recalls for supermarkets you choose.',
      RecallNotificationStatus.denied =>
        'Notifications are off. You can enable them later in Settings.',
      RecallNotificationStatus.unavailable =>
        'Push notifications are available in the iOS and Android apps.',
      RecallNotificationStatus.notRequested =>
        'Be alerted when an official recall matches a selected store.',
    };
  }

  Future<void> _refreshPermissionState() async {
    try {
      final locationPermission = await Geolocator.checkPermission();
      final notifications = await _notifications.status();
      if (!mounted) return;
      setState(() {
        _locationReady = widget.session.hasLocation &&
            locationPermission != LocationPermission.denied &&
            locationPermission != LocationPermission.deniedForever;
        _notificationStatus = notifications;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _requestLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        throw Exception('Turn on Location Services and try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location was not allowed. You can enable it later in Settings.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      var postcode = '';
      try {
        final places = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        postcode = places.isEmpty ? '' : places.first.postalCode ?? '';
      } catch (_) {
        postcode = '';
      }
      await widget.session.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        postcode: postcode,
      );
      if (!mounted) return;
      setState(() => _locationReady = true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locationError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _requestNotifications() async {
    setState(() => _notificationBusy = true);
    try {
      final status = await _notifications.requestAndSync(widget.session);
      if (!mounted) return;
      setState(() => _notificationStatus = status);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationStatus = RecallNotificationStatus.notRequested;
      });
    } finally {
      if (mounted) setState(() => _notificationBusy = false);
    }
  }

  Future<void> _openPrivacyPolicy() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()),
    );
  }
}

class _IntroHeader extends StatelessWidget {
  const _IntroHeader({
    required this.page,
    required this.onBack,
  });

  final int page;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 22, 4),
      child: Row(
        children: [
          if (onBack == null)
            const SizedBox(width: 4)
          else
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          const BrandMark(compact: true),
          const Spacer(),
          Row(
            children: List.generate(
              2,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: page == index ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: page == index ? AppColors.green : AppColors.mint,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: AppGradients.primarySoft,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.green, size: 24),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}

enum _PermissionState { pending, ready, problem }

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
    required this.actionLabel,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String detail;
  final _PermissionState status;
  final String actionLabel;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isReady = status == _PermissionState.ready;
    final isProblem = status == _PermissionState.problem;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: isReady
              ? AppColors.green.withValues(alpha: 0.45)
              : isProblem
                  ? AppColors.warning.withValues(alpha: 0.45)
                  : AppColors.line,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.greenDark.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isReady ? AppColors.acidSoft : AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.green, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (isReady)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.green,
                            size: 22,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isReady ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    size: 19,
                  ),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
