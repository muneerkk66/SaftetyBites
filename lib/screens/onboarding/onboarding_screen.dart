import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../models/family_member.dart';
import '../../widgets/allergen_selector.dart';
import '../../widgets/brand_mark.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _stores = [
    'Tesco',
    'Aldi',
    'Asda',
    'Sainsbury’s',
    'Lidl',
    'Morrisons',
    'Waitrose',
    'Iceland',
    'Co-op',
    'M&S',
  ];

  final _postcodeController = TextEditingController();
  final _nameController = TextEditingController(text: 'You');
  int _step = 0;
  bool _locating = false;
  bool _saving = false;
  final Set<String> _storesSelected = {'Tesco', 'Aldi', 'Asda', 'Sainsbury’s'};
  Set<String> _allergensSelected = {};

  @override
  void dispose() {
    _postcodeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(
          child: Column(
            children: [
              _OnboardingHeader(step: _step),
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
                    key: ValueKey(_step),
                    child: switch (_step) {
                      0 => _WelcomeStep(onContinue: _next),
                      1 => _buildLocationStep(),
                      _ => _buildProfileStep(),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where do you shop?',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'We use your area to personalise retailer alerts and show nearby return locations.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _postcodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Home postcode',
                  hintText: 'e.g. M1 1AE',
                  prefixIcon:
                      Icon(Icons.location_on_outlined, color: AppColors.green),
                ),
              ),
              const SizedBox(height: 11),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded,
                        color: AppColors.green),
                label: Text(_locating
                    ? 'Finding your area…'
                    : 'Use my current location'),
              ),
              const SizedBox(height: 28),
              Text('Your supermarkets',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              Text(
                'Select every store your household may use.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: _stores.map((store) {
                  final selected = _storesSelected.contains(store);
                  return FilterChip(
                    selected: selected,
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.storefront_outlined,
                      size: 18,
                      color: selected ? Colors.white : AppColors.green,
                    ),
                    label: Text(store),
                    selectedColor: AppColors.green,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                        color: selected ? AppColors.green : AppColors.line),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    onSelected: (_) {
                      setState(() {
                        selected
                            ? _storesSelected.remove(store)
                            : _storesSelected.add(store);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              FilledButton(
                  onPressed: _canContinueLocation ? _next : null,
                  child: const Text('Continue')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create your profile',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Choose anything you need to avoid. You can add your partner, children and relatives next.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Profile name',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: AppColors.green),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('Allergies and intolerances',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    'Optional',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.green,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              AllergenSelector(
                selectedIds: _allergensSelected,
                onChanged: (value) =>
                    setState(() => _allergensSelected = value),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.warning),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'SafeBite supports label checking, but ingredients and recipes can change. Always verify the current package before eating.',
                        style: TextStyle(color: AppColors.ink, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving || _nameController.text.trim().isEmpty
                    ? null
                    : _finish,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Set up SafeBite'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canContinueLocation =>
      _postcodeController.text.trim().isNotEmpty && _storesSelected.isNotEmpty;

  void _next() => setState(() => _step += 1);

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is not available.');
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final places =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      final postcode = places.isEmpty ? '' : places.first.postalCode ?? '';
      if (postcode.isEmpty) {
        throw Exception('We could not detect your postcode.');
      }
      _postcodeController.text = postcode.toUpperCase();
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter your postcode manually to continue.')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await widget.session.completeOnboarding(
      postcode: _postcodeController.text,
      stores: _storesSelected,
      primaryMember: FamilyMember(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        relationship: 'You',
        allergenIds: _allergensSelected,
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
      child: Row(
        children: [
          const BrandMark(compact: true),
          const Spacer(),
          if (step > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: AppGradients.primarySoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                '$step of 2',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.greenDark,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              minHeight: constraints.maxHeight - 48,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
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
                        color: AppColors.greenDark.withOpacity(0.26),
                        blurRadius: 36,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 440),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.greenDark.withOpacity(0.98),
                          AppColors.greenDark.withOpacity(0.78),
                          AppColors.greenDark.withOpacity(0.08),
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
                              'SAFEBITE FOR FAMILIES',
                              style: TextStyle(
                                color: AppColors.acid,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Love the food.\nLose the worry.',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 44,
                                    height: 0.94,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Scan labels for your whole household and keep relevant UK recalls close.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text('How SafeBite works',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'A quick check designed for the whole household.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                const _HowItWorksCard(
                  number: '1',
                  icon: Icons.people_alt_rounded,
                  title: 'Add your household',
                  detail:
                      'Create profiles for you, your partner and children, then select what each person avoids.',
                  gradient: LinearGradient(
                    colors: [Color(0xFFE8F6E4), Color(0xFFDDF2E8)],
                  ),
                ),
                const SizedBox(height: 10),
                const _HowItWorksCard(
                  number: '2',
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Scan before you buy',
                  detail:
                      'Scan a barcode and the current ingredients label to check one product for everyone.',
                  gradient: LinearGradient(
                    colors: [Color(0xFFF0F7DD), Color(0xFFE3F3E3)],
                  ),
                ),
                const SizedBox(height: 10),
                const _HowItWorksCard(
                  number: '3',
                  icon: Icons.notifications_active_rounded,
                  title: 'Stay recall-aware',
                  detail:
                      'Use your area and preferred supermarkets to prioritise relevant UK food alerts.',
                  gradient: LinearGradient(
                    colors: [Color(0xFFE5F2EA), Color(0xFFD4ECE2)],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onContinue,
                  child: const Text('Set up my household'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'No exact address or medical records required',
                    style: Theme.of(context).textTheme.bodyMedium,
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

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.detail,
    required this.gradient,
  });

  final String number;
  final IconData icon;
  final String title;
  final String detail;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.greenDark,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'STEP $number',
                        style: const TextStyle(
                          color: AppColors.greenDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
