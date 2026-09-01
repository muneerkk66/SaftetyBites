import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../models/allergen.dart';
import '../../models/family_member.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/section_heading.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.auth,
    required this.onScan,
    required this.onOpenAssistant,
    required this.onOpenFamily,
    required this.onOpenAlerts,
  });

  final AppSession session;
  final AuthController auth;
  final VoidCallback onScan;
  final VoidCallback onOpenAssistant;
  final VoidCallback onOpenFamily;
  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([session, auth]),
        builder: (context, _) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 110),
                sliver: SliverList.list(
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 22),
                    _ScanHero(onScan: onScan),
                    const SizedBox(height: 18),
                    _AiAssistantCard(onTap: onOpenAssistant),
                    const SizedBox(height: 28),
                    SectionHeading(
                      title: 'Protected household',
                      subtitle:
                          '${session.family.length} profile${session.family.length == 1 ? '' : 's'} checked together',
                      trailing: TextButton(
                          onPressed: onOpenFamily, child: const Text('Manage')),
                    ),
                    const SizedBox(height: 13),
                    _buildHouseholdCard(context),
                    const SizedBox(height: 28),
                    SectionHeading(
                      title: 'Recall protection',
                      trailing: TextButton(
                          onPressed: onOpenAlerts,
                          child: const Text('View alerts')),
                    ),
                    const SizedBox(height: 13),
                    _RecallStatusCard(
                      storeCount: session.selectedStores.length,
                      location: session.locationLabel,
                      onTap: onOpenAlerts,
                    ),
                    if (session.recentlyChecked.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const SectionHeading(title: 'Recently checked'),
                      const SizedBox(height: 13),
                      ...session.recentlyChecked.take(3).map(
                            (product) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RecentProductCard(
                                name: product.name,
                                brand: product.brand,
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final accountName = auth.greetingName;
    final firstName = accountName.isNotEmpty
        ? accountName
        : session.family.isEmpty
            ? 'there'
            : session.family.first.name;
    return Row(
      children: [
        const BrandMark(compact: true),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Hello, $firstName',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                session.locationLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.greenDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        if (session.family.isNotEmpty)
          _ProfileAvatar(
            member: session.family.first,
            photoUrl: auth.user?.photoURL,
            onTap: onOpenFamily,
          ),
      ],
    );
  }

  Widget _buildHouseholdCard(BuildContext context) {
    final allergenCount = session.family.fold<int>(
      0,
      (total, member) => total + member.allergenIds.length,
    );

    return Card(
      child: InkWell(
        onTap: onOpenFamily,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppGradients.primarySoft,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: (42 + (session.family.length.clamp(1, 4) - 1) * 28)
                          .toDouble(),
                      height: 46,
                      child: Stack(
                        children: session.family
                            .take(4)
                            .toList()
                            .asMap()
                            .entries
                            .map((entry) {
                          return Positioned(
                            left: entry.key * 28,
                            child: MemberAvatar(
                              member: entry.value,
                              size: 44,
                              showBorder: true,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.greenSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$allergenCount preferences',
                        style: const TextStyle(
                          color: AppColors.greenDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: session.family
                          .every((member) => member.allergenIds.isEmpty)
                      ? Text(
                          'No allergens selected yet. Add preferences for personalised checks.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: session.family
                              .expand((member) => member.allergenIds)
                              .toSet()
                              .take(5)
                              .map((id) => _MiniAllergenChip(
                                  label: Allergens.byId(id).label))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.member,
    required this.photoUrl,
    required this.onTap,
  });

  final FamilyMember member;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = photoUrl?.trim() ?? '';
    return Semantics(
      button: true,
      label: 'Open family profiles',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: imageUrl.isEmpty
            ? MemberAvatar(member: member, size: 42)
            : CircleAvatar(
                radius: 21,
                backgroundColor: AppColors.greenSoft,
                foregroundImage: NetworkImage(imageUrl),
                child: const Icon(Icons.person_rounded),
              ),
      ),
    );
  }
}

class _AiAssistantCard extends StatelessWidget {
  const _AiAssistantCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF0FFD9), Color(0xFFDFF3E1)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.acid,
                  size: 29,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ask SafeBiteAI',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Photograph a product or label and ask what can be verified.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  color: AppColors.greenDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: MediaQuery.sizeOf(context).width > 700 ? 2.35 : 1.18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.greenDark.withValues(alpha: 0.24),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
          image: const DecorationImage(
            image: AssetImage('assets/images/safebite-grocery-hero-v1.png'),
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onScan,
            borderRadius: BorderRadius.circular(30),
            child: Ink(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.greenDark.withValues(alpha: 0.98),
                    AppColors.greenDark.withValues(alpha: 0.78),
                    AppColors.greenDark.withValues(alpha: 0.12),
                  ],
                  stops: const [0, 0.52, 1],
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 370),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SAFE FOR YOUR CREW?',
                        style: TextStyle(
                          color: AppColors.acid,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Scan it.\nKnow it.',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: 42,
                                  height: 0.93,
                                ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.acid,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.qr_code_scanner_rounded,
                              color: AppColors.greenDark,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'SCAN PRODUCT',
                              style: TextStyle(
                                color: AppColors.greenDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecallStatusCard extends StatelessWidget {
  const _RecallStatusCard({
    required this.storeCount,
    required this.location,
    required this.onTap,
  });

  final int storeCount;
  final String location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFF0FFF5)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(Icons.notifications_active_outlined,
                      color: AppColors.green),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monitoring is ready',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(
                        storeCount == 0
                            ? 'No retailers selected near $location'
                            : '$storeCount retailers selected near $location',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniAllergenChip extends StatelessWidget {
  const _MiniAllergenChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _RecentProductCard extends StatelessWidget {
  const _RecentProductCard({required this.name, required this.brand});

  final String name;
  final String brand;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppGradients.sunset,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                  color: AppColors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(brand, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.check_circle_rounded, color: AppColors.green),
          ],
        ),
      ),
    );
  }
}
