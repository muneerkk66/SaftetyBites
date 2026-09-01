import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../models/allergen.dart';
import '../../models/recall_alert.dart';
import '../../services/recall_feed_service.dart';
import '../../services/recall_notification_service.dart';
import '../../widgets/section_heading.dart';

const _retailerSlugs = <String, String>{
  'Tesco': 'tesco',
  'Aldi': 'aldi',
  'Asda': 'asda',
  'Sainsbury’s': 'sainsburys',
  'Lidl': 'lidl',
  'Morrisons': 'morrisons',
  'Waitrose': 'waitrose',
  'Iceland': 'iceland',
  'Co-op': 'coop',
  'M&S': 'marks_spencer',
};

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _feedService = RecallFeedService();
  final _notificationService = RecallNotificationService.instance;
  List<RecallAlert> _alerts = const [];
  DateTime? _checkedAt;
  bool _loading = true;
  String? _error;
  RecallNotificationStatus _notificationStatus =
      RecallNotificationStatus.notRequested;

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_handleIncomingAlert);
    _loadAlerts();
    _loadNotificationStatus();
  }

  @override
  void dispose() {
    _notificationService.removeListener(_handleIncomingAlert);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedStoreAlerts = _alerts.where(_matchesSelectedStore).toList();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your store recalls',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 7),
                      Text(
                        'Only official alerts matching your selected supermarkets.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'FSA LIVE',
                    style: TextStyle(
                      color: AppColors.greenDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _NotificationCard(
              status: _notificationStatus,
              onEnable: _enableNotifications,
            ),
            const SizedBox(height: 20),
            _AlertSummary(
              relevantCount: selectedStoreAlerts.length,
              totalCount: selectedStoreAlerts.length,
              loading: _loading,
            ),
            if (_checkedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last checked ${_timeLabel(_checkedAt!)} · Pull down to refresh',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (widget.session.selectedStores.isEmpty) ...[
              const SizedBox(height: 28),
              const _NoSelectedStoresCard(),
            ] else if (_loading && _alerts.isEmpty) ...[
              const SizedBox(height: 46),
              const Center(child: CircularProgressIndicator()),
            ] else if (_error != null && _alerts.isEmpty) ...[
              const SizedBox(height: 22),
              _ErrorCard(message: _error!, onRetry: _loadAlerts),
            ] else if (selectedStoreAlerts.isEmpty) ...[
              const SizedBox(height: 28),
              const _EmptyAlertsCard(),
            ] else ...[
              const SizedBox(height: 28),
              SectionHeading(
                title: 'Selected store alerts',
                subtitle: widget.session.selectedStores.join(', '),
              ),
              const SizedBox(height: 13),
              ...selectedStoreAlerts.map(
                (alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RecallCard(
                    alert: alert,
                    reasons: _relevanceReasons(alert),
                    isUnread: _notificationService.isAlertUnread(alert.id),
                    onRead: () => _notificationService.markAlertRead(alert.id),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            const _HowMatchingWorks(),
            const SizedBox(height: 16),
            Text(
              'Food alert data © Food Standards Agency, used under the Open Government Licence. Always follow the official notice.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAlerts() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await _feedService.latest();
      if (!mounted) return;
      await _notificationService.resolveUnmatchedAlert(
        result.alerts.where(_matchesSelectedStore).map((alert) => alert.id),
      );
      if (!mounted) return;
      setState(() {
        _alerts = result.alerts;
        _checkedAt = result.checkedAt;
      });
    } on RecallFeedException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadNotificationStatus() async {
    final status = await _notificationService.status();
    if (mounted) setState(() => _notificationStatus = status);
  }

  Future<void> _enableNotifications() async {
    final status = await _notificationService.requestAndSync(widget.session);
    if (!mounted) return;
    setState(() => _notificationStatus = status);
    if (status == RecallNotificationStatus.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected-store recall notifications are enabled.'),
        ),
      );
    }
  }

  void _handleIncomingAlert() {
    if (!mounted) return;
    setState(() {});
    if (_alerts.isNotEmpty) {
      unawaited(
        _notificationService.resolveUnmatchedAlert(
          _alerts.where(_matchesSelectedStore).map((alert) => alert.id),
        ),
      );
    }
  }

  List<String> _relevanceReasons(RecallAlert alert) {
    final reasons = <String>[];
    final householdAllergens = Allergens.expandLegacyIds(
      widget.session.family.expand((member) => member.allergenIds),
    );
    final matchingAllergens = Allergens.expandLegacyIds(alert.allergenIds)
        .where(householdAllergens.contains)
        .toList();
    if (matchingAllergens.isNotEmpty) {
      final labels = matchingAllergens
          .map((id) => Allergens.byId(id).label)
          .toSet()
          .join(', ');
      reasons.add('Household allergen: $labels');
    }

    for (final store in widget.session.selectedStores) {
      final slug = _retailerSlugs[store];
      if (slug != null && alert.retailerIds.contains(slug)) {
        reasons.add('Selected supermarket: $store');
      }
    }

    for (final checked in widget.session.recentlyChecked) {
      final checkedName = checked.name.toLowerCase();
      if (checkedName.length < 4) continue;
      if (alert.products.any((product) {
        final recalledName = product.name.toLowerCase();
        return recalledName.contains(checkedName) ||
            checkedName.contains(recalledName);
      })) {
        reasons.add('Similar to a recently scanned product');
        break;
      }
    }
    return reasons.toSet().toList();
  }

  bool _matchesSelectedStore(RecallAlert alert) {
    final selectedIds = widget.session.selectedStores
        .map((store) => _retailerSlugs[store])
        .whereType<String>()
        .toSet();
    return alert.retailerIds.any(selectedIds.contains);
  }

  String _timeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} at $hour:$minute';
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.status, required this.onEnable});

  final RecallNotificationStatus status;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final enabled = status == RecallNotificationStatus.enabled;
    final unavailable = status == RecallNotificationStatus.unavailable;
    final denied = status == RecallNotificationStatus.denied;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: enabled ? AppColors.greenSoft : AppColors.warningSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                enabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: enabled ? AppColors.green : AppColors.warning,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enabled
                        ? 'Recall notifications on'
                        : unavailable
                            ? 'Mobile notifications'
                            : denied
                                ? 'Notifications are off'
                                : 'Get recall notifications',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    enabled
                        ? 'Only your selected supermarkets are monitored.'
                        : unavailable
                            ? 'Push alerts are available in the iOS and Android apps.'
                            : denied
                                ? 'Enable notifications in your device settings to receive alerts.'
                                : 'Allow SafeBiteAI to notify you about recalls from your selected supermarkets.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (!enabled && !unavailable && !denied)
              TextButton(onPressed: onEnable, child: const Text('Enable')),
          ],
        ),
      ),
    );
  }
}

class _AlertSummary extends StatelessWidget {
  const _AlertSummary({
    required this.relevantCount,
    required this.totalCount,
    required this.loading,
  });

  final int relevantCount;
  final int totalCount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final active = relevantCount > 0;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: active ? null : AppGradients.primary,
        color: active ? AppColors.dangerSoft : null,
        borderRadius: BorderRadius.circular(28),
        border: active
            ? Border.all(color: AppColors.danger.withValues(alpha: 0.2))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: active ? AppColors.danger : AppColors.greenDark,
              shape: BoxShape.circle,
            ),
            child: Icon(
              active
                  ? Icons.notification_important_rounded
                  : Icons.verified_user_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading && totalCount == 0
                      ? 'Checking official alerts…'
                      : active
                          ? '$relevantCount relevant alert${relevantCount == 1 ? '' : 's'}'
                          : 'No matching alerts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: active ? AppColors.danger : Colors.white,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  totalCount == 0
                      ? 'SafeBiteAI checks the official UK feed automatically.'
                      : '$totalCount selected-store alert${totalCount == 1 ? '' : 's'} found.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: active
                            ? AppColors.inkSoft
                            : Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecallCard extends StatelessWidget {
  const _RecallCard({
    required this.alert,
    required this.reasons,
    required this.isUnread,
    required this.onRead,
  });

  final RecallAlert alert;
  final List<String> reasons;
  final bool isUnread;
  final Future<void> Function() onRead;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isUnread ? const Color(0xFFF1FBE8) : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isUnread ? AppColors.greenBright : AppColors.line,
          width: isUnread ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: isUnread ? onRead : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: alert.alertType == 'AA'
                          ? AppColors.warningSoft
                          : AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'OFFICIAL ${alert.alertType}',
                      style: TextStyle(
                        color: alert.alertType == 'AA'
                            ? AppColors.warning
                            : AppColors.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  if (isUnread) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (isUnread) ...[
                    const Icon(Icons.circle, color: AppColors.green, size: 10),
                    const SizedBox(width: 7),
                  ],
                  Text(alert.publishedLabel,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                alert.typeLabel.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                alert.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700,
                    ),
              ),
              if (alert.summary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(alert.summary,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: reasons
                      .map(
                        (reason) => Chip(
                          avatar: const Icon(Icons.check_circle_outline_rounded,
                              size: 17),
                          label: Text(reason),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (alert.products.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...alert.products.take(4).map(
                      (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ProductRow(product: product),
                      ),
                    ),
              ],
              if (alert.action.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          alert.action,
                          style: const TextStyle(
                            color: AppColors.ink,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (alert.sourceUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await onRead();
                      await launchUrl(
                        Uri.parse(alert.sourceUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open official FSA notice'),
                  ),
                ),
              ],
              if (isUnread) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: onRead,
                    icon: const Icon(Icons.done_rounded, size: 19),
                    label: const Text('Mark as read'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});

  final RecallProduct product;

  @override
  Widget build(BuildContext context) {
    final detail = [product.packSize, product.batchDetails]
        .where((value) => value.isNotEmpty)
        .join(' · ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 20, color: AppColors.green),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowMatchingWorks extends StatelessWidget {
  const _HowMatchingWorks();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title: 'How matching works'),
        SizedBox(height: 13),
        _ProtectionRow(
          icon: Icons.health_and_safety_outlined,
          title: 'Family allergens stay local',
          detail: 'SafeBiteAI compares official allergen codes on your device.',
        ),
        SizedBox(height: 10),
        _ProtectionRow(
          icon: Icons.storefront_outlined,
          title: 'Selected supermarkets',
          detail:
              'Only retailer notices for stores you selected are displayed.',
        ),
        SizedBox(height: 10),
        _ProtectionRow(
          icon: Icons.shopping_bag_outlined,
          title: 'Recently scanned products',
          detail: 'Product names are compared locally with official notices.',
        ),
      ],
    );
  }
}

class _ProtectionRow extends StatelessWidget {
  const _ProtectionRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppGradients.primarySoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: AppColors.green),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.danger, size: 38),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _EmptyAlertsCard extends StatelessWidget {
  const _EmptyAlertsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.verified_user_outlined,
                color: AppColors.green, size: 42),
            const SizedBox(height: 10),
            Text('No recalls for your selected stores',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(
              'SafeBiteAI will continue checking these supermarkets automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSelectedStoresCard extends StatelessWidget {
  const _NoSelectedStoresCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.add_business_rounded,
                color: AppColors.green, size: 42),
            const SizedBox(height: 10),
            Text('Choose supermarkets to monitor',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(
              'Open the Family tab and select the stores where your household shops.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
