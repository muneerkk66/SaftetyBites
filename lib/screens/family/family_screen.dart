import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../models/allergen.dart';
import '../../models/family_member.dart';
import '../../models/offline_catalog.dart';
import '../../services/food_hygiene_service.dart';
import '../../services/nearby_store_matcher.dart';
import '../../services/product_repository.dart';
import '../auth/account_access_screen.dart';
import '../legal/privacy_policy_screen.dart';
import '../../widgets/allergen_selector.dart';
import '../../widgets/member_avatar.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({
    super.key,
    required this.session,
    required this.auth,
  });

  final AppSession session;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your family',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        Text(
                          'One scan checks everyone selected.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.inkSoft,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => _showMemberEditor(context),
                      icon: const Icon(Icons.person_add_alt_1_rounded,
                          color: AppColors.acid),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...session.family.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FamilyMemberCard(
                    member: member,
                    onTap: () => _showMemberEditor(context, member: member),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _showMemberEditor(context),
                icon: const Icon(Icons.add_rounded, color: AppColors.green),
                label: const Text('Add family member'),
              ),
              const SizedBox(height: 24),
              _StorePreferencesCard(
                session: session,
                onEdit: () => _showStoreEditor(context),
              ),
              const SizedBox(height: 24),
              _AccountCard(auth: auth),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.privacy_tip_outlined,
                        color: AppColors.green),
                  ),
                  title: const Text('Privacy and your data'),
                  subtitle: const Text(
                    'See what stays on your device and which services receive data.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  gradient: AppGradients.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: AppColors.greenDark),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Use nicknames for children if preferred. SafeBiteAI does not need dates of birth or medical records.',
                        style:
                            TextStyle(color: AppColors.greenDark, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showMemberEditor(BuildContext context, {FamilyMember? member}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.canvas,
      builder: (_) => _MemberEditor(session: session, member: member),
    );
  }

  Future<void> _showStoreEditor(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.canvas,
      builder: (_) => _StorePreferencesEditor(session: session),
    );
  }
}

class _StorePreferencesCard extends StatelessWidget {
  const _StorePreferencesCard({required this.session, required this.onEdit});

  final AppSession session;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final stores = session.selectedStores.toList()..sort();
    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your supermarkets',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 3),
                        Text(
                          '${session.locationLabel} · ${session.storeRadiusMiles.toInt()} mile radius',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, color: AppColors.inkSoft),
                ],
              ),
              const SizedBox(height: 14),
              if (stores.isEmpty)
                const Text(
                  'No supermarkets selected. Tap to add stores.',
                  style: TextStyle(color: AppColors.inkSoft),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: stores
                      .map(
                        (store) => Chip(
                          avatar: const Icon(Icons.store_rounded, size: 17),
                          label: Text(store),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorePreferencesEditor extends StatefulWidget {
  const _StorePreferencesEditor({required this.session});

  final AppSession session;

  @override
  State<_StorePreferencesEditor> createState() =>
      _StorePreferencesEditorState();
}

class _StorePreferencesEditorState extends State<_StorePreferencesEditor> {
  final _service = FoodHygieneService();
  late Set<String> _selectedStores;
  late double _radiusMiles;
  List<NearbyStoreMatch> _nearbyStores = const [];
  bool _loading = false;
  bool _showAllBrands = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedStores = Set<String>.from(widget.session.selectedStores);
    _radiusMiles = widget.session.storeRadiusMiles;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStores());
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  List<String> get _storeOptions {
    if (_showAllBrands || _nearbyStores.isEmpty) {
      return NearbyStoreMatcher.supportedBrands;
    }
    final nearbyNames = _nearbyStores.map((store) => store.name).toList();
    return [
      ...nearbyNames,
      ..._selectedStores.where((store) => !nearbyNames.contains(store)),
    ];
  }

  double? _distanceFor(String storeName) {
    for (final store in _nearbyStores) {
      if (store.name == storeName) return store.distanceMiles;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Edit supermarkets',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Choose stores near ${widget.session.locationLabel}. Unselect a store to remove it from your alerts.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            Text('Search distance',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: NearbyStoreMatcher.supportedRadiusMiles
                  .map(
                    (radius) => ChoiceChip(
                      selected: _radiusMiles == radius,
                      label: Text('${radius.toInt()} miles'),
                      onSelected:
                          _loading ? null : (_) => _changeRadius(radius),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Store not listed? Increase the distance to discover more branches.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkSoft,
                  ),
            ),
            const SizedBox(height: 18),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 10),
            ],
            if (!_loading && _error == null) ...[
              Text(
                '${_nearbyStores.length} supported supermarket brand${_nearbyStores.length == 1 ? '' : 's'} found within ${_radiusMiles.toInt()} miles. Each brand is shown once, even when several branches are nearby.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.greenDark,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: _storeOptions.map((store) {
                final selected = _selectedStores.contains(store);
                final distance = _distanceFor(store);
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
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => _toggleStore(store),
                );
              }).toList(),
            ),
            if (!_showAllBrands && _nearbyStores.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _showAllBrands = true),
                icon: const Icon(Icons.add_business_rounded),
                label: const Text('Show all supported brands'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeRadius(double radius) async {
    setState(() {
      _radiusMiles = radius;
      _showAllBrands = false;
    });
    await _persistPreferences();
    await _loadStores();
  }

  Future<void> _toggleStore(String store) async {
    setState(() {
      _selectedStores.contains(store)
          ? _selectedStores.remove(store)
          : _selectedStores.add(store);
    });
    await _persistPreferences();
  }

  Future<void> _loadStores() async {
    final latitude = widget.session.latitude;
    final longitude = widget.session.longitude;
    if (latitude == null || longitude == null) {
      setState(() {
        _error = 'Update your area in the Hygiene tab to find nearby stores.';
        _showAllBrands = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final candidates = await _service.nearbySupermarketCandidates(
        latitude: latitude,
        longitude: longitude,
        radiusMiles: _radiusMiles,
      );
      if (!mounted) return;
      setState(() => _nearbyStores = NearbyStoreMatcher.match(candidates));
    } on FoodHygieneException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persistPreferences() {
    return widget.session.updateStorePreferences(
      stores: _selectedStores,
      radiusMiles: _radiusMiles,
    );
  }
}

class _OfflineCatalogCard extends StatefulWidget {
  const _OfflineCatalogCard();

  @override
  State<_OfflineCatalogCard> createState() => _OfflineCatalogCardState();
}

class _OfflineCatalogCardState extends State<_OfflineCatalogCard> {
  OfflineCatalogStats? _stats;
  bool _loading = true;
  bool _syncing = false;
  int _imported = 0;
  int _expected = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final count = stats?.productCount ?? 0;
    final progress = _expected == 0 ? null : _imported / _expected;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.primarySoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.aqua),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.greenDark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.offline_bolt_rounded,
                    color: AppColors.acid),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Offline product catalogue',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 3),
                    Text(
                      _loading
                          ? 'Checking local storage…'
                          : '$count products available without internet',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stats?.updatedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Updated ${_dateLabel(stats!.updatedAt!)} · Version ${stats.version ?? 'local'}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.inkSoft),
            ),
          ],
          if (_syncing) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 7),
            Text(
              _expected == 0
                  ? 'Preparing download…'
                  : 'Saving $_imported of $_expected products…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading || _syncing || stats == null
                  ? null
                  : stats.supportsFullCatalog
                      ? _sync
                      : null,
              icon: const Icon(Icons.sync_rounded, color: AppColors.green),
              label: Text(count == 0
                  ? 'Download offline catalogue'
                  : 'Check for catalogue update'),
            ),
          ),
          if (stats != null && !stats.supportsFullCatalog) ...[
            const SizedBox(height: 8),
            Text(
              'The web app keeps a smaller recent-product cache. Full downloads are available on iOS and Android.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadStats() async {
    final stats = await ProductRepository.instance.catalogStats();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _imported = 0;
      _expected = 0;
    });
    try {
      final imported = await ProductRepository.instance.syncOfflineCatalog(
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _imported = current;
            _expected = total;
          });
        },
      );
      await _loadStats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(imported == 0
            ? 'Your offline catalogue is already up to date.'
            : '$imported products are ready for offline checks.'),
      ));
    } on OfflineCatalogException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final signedIn = auth.isSignedIn;
        return Card(
          color: AppColors.greenDark,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.acid,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    signedIn
                        ? Icons.cloud_done_rounded
                        : Icons.person_outline_rounded,
                    color: AppColors.greenDark,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signedIn ? 'Account connected' : 'Guest mode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        signedIn
                            ? auth.user?.email ?? 'Signed in securely'
                            : 'Sign in to prepare for profile syncing.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.66),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: signedIn
                      ? auth.signOut
                      : () => _openAccountAccess(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.acid,
                  ),
                  child: Text(signedIn ? 'Sign out' : 'Sign in'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAccountAccess(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (routeContext) => AccountAccessScreen(
          auth: auth,
          allowGuest: false,
          onComplete: () async {
            if (routeContext.mounted) Navigator.pop(routeContext);
          },
        ),
      ),
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  const _FamilyMemberCard({required this.member, required this.onTap});

  final FamilyMember member;
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
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFF4FFF7)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                MemberAvatar(member: member, size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(member.name,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(width: 8),
                          Text(member.relationship,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: 7),
                      if (member.allergenIds.isEmpty)
                        const Text('No preferences selected',
                            style: TextStyle(color: AppColors.inkSoft))
                      else
                        Text(
                          member.allergenIds
                              .map((id) => Allergens.byId(id).label)
                              .join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined,
                    color: AppColors.inkSoft, size: 21),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberEditor extends StatefulWidget {
  const _MemberEditor({required this.session, this.member});

  final AppSession session;
  final FamilyMember? member;

  @override
  State<_MemberEditor> createState() => _MemberEditorState();
}

class _MemberEditorState extends State<_MemberEditor> {
  static const _relationships = ['You', 'Partner', 'Child', 'Parent', 'Other'];
  late final TextEditingController _nameController;
  late String _relationship;
  late Set<String> _allergens;
  bool _saving = false;
  bool _permissionConfirmed = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member?.name ?? '');
    _relationship = widget.member?.relationship ?? 'Partner';
    _allergens = Set<String>.from(widget.member?.allergenIds ?? {});
    _permissionConfirmed = widget.member != null || _allergens.isEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        16,
        22,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.member == null ? 'Add family member' : 'Edit profile',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name or nickname'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _relationship,
              decoration: const InputDecoration(labelText: 'Relationship'),
              items: _relationships
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _relationship = value ?? 'Other'),
            ),
            const SizedBox(height: 22),
            Text('Allergies and intolerances',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            AllergenSelector(
              selectedIds: _allergens,
              onChanged: (value) => setState(() {
                _allergens = value;
                if (value.isEmpty) {
                  _permissionConfirmed = true;
                } else if (widget.member == null) {
                  _permissionConfirmed = false;
                }
              }),
              compact: true,
            ),
            if (_allergens.isNotEmpty &&
                (!widget.session.healthDataConsent ||
                    widget.member == null)) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: CheckboxListTile(
                  value: _permissionConfirmed,
                  onChanged: (value) => setState(
                    () => _permissionConfirmed = value ?? false,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'I have permission to add this person’s allergy information and explicitly consent to its use for household checks.',
                  ),
                  subtitle: const Text(
                    'The profile is stored on this device and can be deleted at any time.',
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
                  child: const Text('Read privacy policy'),
                ),
              ),
            ],
            const SizedBox(height: 26),
            FilledButton(
              onPressed: _nameController.text.trim().isEmpty ||
                      _saving ||
                      (_allergens.isNotEmpty && !_permissionConfirmed)
                  ? null
                  : _save,
              child: Text(
                  widget.member == null ? 'Add to family' : 'Save changes'),
            ),
            if (widget.member != null && widget.session.family.length > 1) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _saving ? null : _remove,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Center(child: Text('Remove profile')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    if (_allergens.isNotEmpty && !widget.session.healthDataConsent) {
      await widget.session.recordHealthDataConsent();
    }
    final existing = widget.member;
    final member = FamilyMember(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      relationship: _relationship,
      allergenIds: _allergens,
      avatarIndex: existing?.avatarIndex ?? widget.session.family.length,
    );
    if (existing == null) {
      await widget.session.addFamilyMember(member);
    } else {
      await widget.session.updateFamilyMember(member);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    await widget.session.removeFamilyMember(widget.member!.id);
    if (mounted) Navigator.pop(context);
  }
}
