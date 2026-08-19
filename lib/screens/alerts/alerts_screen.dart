import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../models/recall_alert.dart';
import '../../widgets/section_heading.dart';

const _recallDebugAvailable = bool.fromEnvironment(
  'ENABLE_RECALL_DEBUG',
  defaultValue: kDebugMode,
);

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final recall = _debugRecall;
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
            children: [
              Text('Food alerts',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 7),
              Text(
                'Relevant official recall notices will appear here.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.inkSoft),
              ),
              if (_recallDebugAvailable) ...[
                const SizedBox(height: 20),
                _DebugRecallPanel(session: session),
              ],
              const SizedBox(height: 22),
              _AlertSummary(active: session.debugRecallEnabled),
              if (session.debugRecallEnabled) ...[
                const SizedBox(height: 28),
                const SectionHeading(
                  title: 'Matching recalls',
                  subtitle: 'Debug data for testing the complete alert layout',
                ),
                const SizedBox(height: 13),
                _RecallCard(alert: recall),
              ],
              const SizedBox(height: 28),
              const SectionHeading(title: 'How matching works'),
              const SizedBox(height: 13),
              const _ProtectionRow(
                icon: Icons.shopping_bag_outlined,
                title: 'Your saved products',
                detail: 'Products you scan receive the strongest recall match.',
              ),
              const SizedBox(height: 10),
              const _ProtectionRow(
                icon: Icons.health_and_safety_outlined,
                title: 'Family allergens',
                detail:
                    'Allergy alerts are compared with every household profile.',
              ),
              const SizedBox(height: 10),
              const _ProtectionRow(
                icon: Icons.storefront_outlined,
                title: 'Selected supermarkets',
                detail:
                    'Retailer notices can be prioritised for the stores you use.',
              ),
              const SizedBox(height: 26),
              Card(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppGradients.sunset,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cloud_sync_outlined,
                              color: AppColors.green),
                          SizedBox(width: 10),
                          Text('Official data connection',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'The production backend will monitor FSA Allergy Alerts, Product Recall Information Notices and Food Alerts for Action.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  RecallAlert get _debugRecall {
    final retailer =
        session.selectedStores.isEmpty ? 'Tesco' : session.selectedStores.first;
    return RecallAlert(
      id: 'debug-recall-001',
      title: 'TEST: Chocolate ice cream recall',
      summary:
          'This sample product may contain milk that is not declared clearly on the label.',
      retailer: retailer,
      publishedLabel: 'Test alert · Today',
      action:
          'Do not consume. Check the barcode and return the product to $retailer.',
      isRelevant: true,
    );
  }
}

class _DebugRecallPanel extends StatelessWidget {
  const _DebugRecallPanel({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final enabled = session.debugRecallEnabled;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.greenDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.greenDark.withOpacity(0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.developer_mode_rounded, color: AppColors.lime),
              SizedBox(width: 10),
              Text(
                'Recall simulator',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Spacer(),
              _DebugBadge(),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            enabled
                ? 'A test recall is active. Review the matching and action states below.'
                : 'Trigger a clearly labelled sample recall to test the customer experience.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          if (enabled)
            OutlinedButton.icon(
              onPressed: () => session.setDebugRecallEnabled(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.34)),
              ),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Clear test recall'),
            )
          else
            FilledButton.icon(
              onPressed: () {
                session.setDebugRecallEnabled(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test recall received')),
                );
              },
              icon: const Icon(Icons.notification_add_rounded),
              label: const Text('Trigger test recall'),
            ),
        ],
      ),
    );
  }
}

class _DebugBadge extends StatelessWidget {
  const _DebugBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'DEBUG ONLY',
        style: TextStyle(
          color: AppColors.lime,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _AlertSummary extends StatelessWidget {
  const _AlertSummary({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: active ? null : AppGradients.primary,
        color: active ? AppColors.dangerSoft : null,
        borderRadius: BorderRadius.circular(28),
        border: active
            ? Border.all(color: AppColors.danger.withOpacity(0.2))
            : null,
        boxShadow: [
          BoxShadow(
            color:
                (active ? AppColors.danger : AppColors.green).withOpacity(0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
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
                  active ? '1 test alert matched' : 'No matching alerts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: active ? AppColors.danger : Colors.white,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  active
                      ? 'The simulator found a retailer and allergen match.'
                      : 'Your household has no active matched recalls.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: active
                            ? AppColors.inkSoft
                            : Colors.white.withOpacity(0.8),
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
  const _RecallCard({required this.alert});

  final RecallAlert alert;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'TEST DATA',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                const Spacer(),
                Text(alert.publishedLabel,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 14),
            Text(alert.retailer.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                )),
            const SizedBox(height: 6),
            Text(alert.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(alert.summary, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
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
        ),
      ),
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF2FFF6)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
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
