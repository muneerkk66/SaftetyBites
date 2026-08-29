import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../models/family_member.dart';
import '../../services/food_hygiene_service.dart';
import '../../services/nearby_store_matcher.dart';
import '../../widgets/allergen_selector.dart';
import '../../widgets/brand_mark.dart';
import '../legal/privacy_policy_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.session,
    required this.auth,
  });

  final AppSession session;
  final AuthController auth;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _hygieneService = FoodHygieneService();
  late final TextEditingController _nameController;
  int _step = 0;
  bool _locating = false;
  bool _loadingStores = false;
  bool _saving = false;
  double _storeRadiusMiles = 5;
  String _detectedPostcode = '';
  double? _latitude;
  double? _longitude;
  String? _locationError;
  List<NearbyStoreMatch> _nearbyStores = const [];
  final Set<String> _storesSelected = {};
  Set<String> _allergensSelected = {};
  bool _healthDataConsent = false;

  @override
  void initState() {
    super.initState();
    final accountName = widget.auth.greetingName;
    _nameController = TextEditingController(
      text: accountName.isEmpty ? 'You' : accountName,
    );
    _detectedPostcode = widget.session.postcode;
    _latitude = widget.session.latitude;
    _longitude = widget.session.longitude;
    _storeRadiusMiles = widget.session.storeRadiusMiles;
  }

  @override
  void dispose() {
    _hygieneService.close();
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
                      0 => _buildLocationStep(),
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
              _buildLocationStatus(),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openPrivacyPolicy,
                  icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                  label: const Text('How location data is used'),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                  _nearbyStores.isEmpty
                      ? 'Choose your supermarkets'
                      : 'Supermarkets near you',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              Text(
                _nearbyStores.isEmpty
                    ? 'Nothing is selected automatically. Choose every store your household may use.'
                    : 'Nearby brands are shown first. Select only the stores your household uses.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_latitude != null && _longitude != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Store not listed? Increase the search distance. Each retailer brand is shown once, even when several branches are nearby.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: NearbyStoreMatcher.supportedRadiusMiles
                      .map(
                        (radius) => ChoiceChip(
                          selected: _storeRadiusMiles == radius,
                          label: Text('${radius.toInt()} miles'),
                          onSelected: _loadingStores
                              ? null
                              : (_) => _changeStoreRadius(radius),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              if (_loadingStores)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: _orderedStores.map((store) {
                  final selected = _storesSelected.contains(store);
                  final distance = _distanceForStore(store);
                  return FilterChip(
                    selected: selected,
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.storefront_outlined,
                      size: 18,
                      color: selected ? Colors.white : AppColors.green,
                    ),
                    label: Text(
                      distance == null
                          ? store
                          : '$store · ${distance.toStringAsFixed(1)} mi',
                    ),
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
                child: Text(
                  _storesSelected.isEmpty
                      ? 'Choose at least one store'
                      : 'Continue',
                ),
              ),
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
                onChanged: (value) => setState(() {
                  _allergensSelected = value;
                  if (value.isEmpty) _healthDataConsent = false;
                }),
              ),
              if (_allergensSelected.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: CheckboxListTile(
                    value: _healthDataConsent,
                    onChanged: (value) => setState(
                      () => _healthDataConsent = value ?? false,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'I explicitly consent to SafeBiteAI processing the allergy information I enter for household checks.',
                    ),
                    subtitle: const Text(
                      'These choices stay on this device. Consent can be withdrawn by deleting the profile or resetting SafeBiteAI.',
                    ),
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openPrivacyPolicy,
                  icon: const Icon(Icons.privacy_tip_outlined, size: 19),
                  label: const Text('Read privacy policy'),
                ),
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
                        'SafeBiteAI supports label checking, but ingredients and recipes can change. Always verify the current package before eating.',
                        style: TextStyle(color: AppColors.ink, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ||
                        _nameController.text.trim().isEmpty ||
                        (_allergensSelected.isNotEmpty && !_healthDataConsent)
                    ? null
                    : _finish,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Set up SafeBiteAI'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> get _orderedStores {
    final nearbyNames = _nearbyStores.map((store) => store.name).toList();
    if (nearbyNames.isEmpty) return NearbyStoreMatcher.supportedBrands;
    return [
      ...nearbyNames,
      ..._storesSelected.where((store) => !nearbyNames.contains(store)),
    ];
  }

  double? _distanceForStore(String store) {
    for (final match in _nearbyStores) {
      if (match.name == store) return match.distanceMiles;
    }
    return null;
  }

  bool get _canContinueLocation =>
      !_locating && !_loadingStores && _storesSelected.isNotEmpty;

  void _next() {
    setState(() => _step += 1);
  }

  Widget _buildLocationStatus() {
    if (_locating) {
      return const _LocationStatusCard(
        icon: Icons.radar_rounded,
        title: 'Finding your location',
        detail: 'Detecting your area and nearby supermarkets…',
        loading: true,
      );
    }

    if (_latitude != null && _longitude != null) {
      return _LocationStatusCard(
        icon: Icons.location_on_rounded,
        title: _detectedPostcode.isEmpty ? 'Location ready' : _detectedPostcode,
        detail: _nearbyStores.isEmpty
            ? 'GPS is ready. Choose the supermarket brands you use.'
            : '${_nearbyStores.length} nearby supermarket brand${_nearbyStores.length == 1 ? '' : 's'} found within ${_storeRadiusMiles.toInt()} miles.',
        actionLabel: 'Refresh',
        onAction: _useCurrentLocation,
      );
    }

    return _LocationStatusCard(
      icon: Icons.location_searching_rounded,
      title: 'Use your current location',
      detail: _locationError ??
          'SafeBiteAI uses GPS to find nearby stores and food hygiene ratings. Your exact address is not required.',
      actionLabel: 'Allow location',
      onAction: _useCurrentLocation,
      isError: _locationError != null,
    );
  }

  Future<void> _useCurrentLocation() async {
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
          'Location permission was not allowed. You can retry or continue after choosing your stores.',
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

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _detectedPostcode = postcode.toUpperCase();
      });
      await _refreshNearbyStores();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locationError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _changeStoreRadius(double radius) async {
    setState(() => _storeRadiusMiles = radius);
    await _refreshNearbyStores();
  }

  Future<void> _refreshNearbyStores() async {
    final latitude = _latitude;
    final longitude = _longitude;
    if (latitude == null || longitude == null) return;

    setState(() => _loadingStores = true);
    try {
      final candidates = await _hygieneService.nearbySupermarketCandidates(
        latitude: latitude,
        longitude: longitude,
        radiusMiles: _storeRadiusMiles,
      );
      if (!mounted) return;
      setState(() => _nearbyStores = NearbyStoreMatcher.match(candidates));
    } catch (_) {
      if (mounted) setState(() => _nearbyStores = const []);
    } finally {
      if (mounted) setState(() => _loadingStores = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await widget.session.completeOnboarding(
      postcode: _detectedPostcode,
      latitude: _latitude,
      longitude: _longitude,
      storeRadiusMiles: _storeRadiusMiles,
      stores: _storesSelected,
      primaryMember: FamilyMember(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        relationship: 'You',
        allergenIds: _allergensSelected,
      ),
      healthDataConsent: _allergensSelected.isNotEmpty && _healthDataConsent,
    );
  }

  Future<void> _openPrivacyPolicy() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({
    required this.icon,
    required this.title,
    required this.detail,
    this.loading = false,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isError ? AppColors.warningSoft : AppColors.greenSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isError
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.green.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isError ? Colors.white : AppColors.acidSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    icon,
                    color: isError ? AppColors.warning : AppColors.green,
                  ),
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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: AppGradients.primarySoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              '${step + 1} of 2',
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

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.onContinue});

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
                        color: AppColors.greenDark.withValues(alpha: 0.26),
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
                          AppColors.greenDark.withValues(alpha: 0.98),
                          AppColors.greenDark.withValues(alpha: 0.78),
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
                                    color: Colors.white.withValues(alpha: 0.8),
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
                Text('How SafeBiteAI works',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'A quick check designed for the whole household.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                const HowItWorksCard(
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
                const HowItWorksCard(
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
                const HowItWorksCard(
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

class HowItWorksCard extends StatelessWidget {
  const HowItWorksCard({
    super.key,
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
                        color: Colors.white.withValues(alpha: 0.72),
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
