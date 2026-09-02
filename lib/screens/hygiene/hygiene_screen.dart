import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../models/food_establishment.dart';
import '../../services/food_hygiene_service.dart';
import '../../services/postcode_lookup_service.dart';
import '../../services/venue_map_links.dart';
import '../../services/venue_photo_service.dart';
import '../../widgets/brand_mark.dart';

class HygieneScreen extends StatefulWidget {
  const HygieneScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<HygieneScreen> createState() => _HygieneScreenState();
}

class _HygieneScreenState extends State<HygieneScreen> {
  final _service = FoodHygieneService();
  final _postcodeService = PostcodeLookupService();
  final _photoService = VenuePhotoService();
  late final TextEditingController _searchController;

  List<FoodEstablishment> _establishments = const [];
  FoodHygienePage? _page;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String _resultLabel = '';
  double? _latitude;
  double? _longitude;
  String _lastQuery = '';
  final Map<int, VenuePhoto> _venuePhotos = {};
  final Set<int> _resolvedVenuePhotoIds = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _latitude = widget.session.latitude;
    _longitude = widget.session.longitude;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.session.hasLocation) {
        _loadNearby(page: 1);
      } else {
        _useCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _service.close();
    _postcodeService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 110),
            sliver: SliverList.list(
              children: [
                const BrandMark(compact: true),
                const SizedBox(height: 20),
                _buildHero(context),
                const SizedBox(height: 18),
                _buildSearchPanel(context),
                const SizedBox(height: 24),
                _buildResults(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.greenDark.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EAT OUT WITH CONFIDENCE',
                  style: TextStyle(
                    color: AppColors.acid,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Check before\nyou order.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 35,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Official UK food hygiene ratings for restaurants, cafés, takeaways and food shops.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: AppColors.acid,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: AppColors.greenDark,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.session.hasLocation
                            ? widget.session.locationLabel
                            : 'Location required',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Showing food businesses within 5 miles',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _showAreaEditor,
                  child: const Text('Update'),
                ),
              ],
            ),
            const SizedBox(height: 17),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loadNearby(page: 1),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search food business name',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Search nearby',
                  onPressed: _isLoading ? null : () => _loadNearby(page: 1),
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            if (_searchController.text.trim().isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _searchController.clear();
                          setState(() {});
                          _loadNearby(page: 1);
                        },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Show all nearby'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _MessageCard(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load ratings',
        message: _error!,
      );
    }

    if (_page == null) {
      return const _MessageCard(
        icon: Icons.location_searching_rounded,
        title: 'Finding food places nearby',
        message: 'Allow location access to see official hygiene ratings.',
      );
    }

    if (_establishments.isEmpty) {
      return const _MessageCard(
        icon: Icons.search_off_rounded,
        title: 'No places found',
        message:
            'Clear the restaurant name to show every place within 5 miles.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hygiene ratings',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 3),
                  Text(
                    '${_page!.totalCount} result${_page!.totalCount == 1 ? '' : 's'} · $_resultLabel',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'FSA DATA',
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
        const SizedBox(height: 14),
        ..._establishments.map(
          (establishment) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EstablishmentCard(
              key: ValueKey(establishment.id),
              establishment: establishment,
              photo: _venuePhotos[establishment.id],
              photoResolved: _resolvedVenuePhotoIds.contains(establishment.id),
            ),
          ),
        ),
        if (_page!.hasMore)
          OutlinedButton.icon(
            onPressed: _isLoadingMore ? null : _loadMore,
            icon: _isLoadingMore
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(_isLoadingMore ? 'Loading...' : 'Load more places'),
          ),
        const SizedBox(height: 14),
        Text(
          'Ratings reflect standards found by the local authority on the inspection date. Always check current allergen information directly with the business.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          'Food hygiene data © Food Standards Agency, used under the Open Government Licence.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.inkSoft,
                fontSize: 11,
              ),
        ),
      ],
    );
  }

  Future<void> _loadNearby({
    required int page,
    bool append = false,
  }) async {
    final query = _searchController.text.trim();
    if (_latitude == null || _longitude == null) {
      await _useCurrentLocation();
      return;
    }

    if (append) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await _service.nearby(
        latitude: _latitude!,
        longitude: _longitude!,
        name: query,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _lastQuery = query;
        _page = result;
        _establishments = append
            ? [..._establishments, ...result.establishments]
            : result.establishments;
        _resultLabel =
            query.isEmpty ? 'within 5 miles' : '“$query” within 5 miles';
      });
      unawaited(_loadVenuePhotos(result.establishments));
    } on FoodHygieneException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        throw const FoodHygieneException(
          'Location services are turned off. Enable them and try again.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const FoodHygieneException(
          'Location permission is needed to show hygiene ratings near you.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _latitude = position.latitude;
      _longitude = position.longitude;
      await widget.session.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      await _loadNearby(page: 1);
    } on FoodHygieneException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not access your location. Check permission and retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _showAreaEditor() async {
    final location = await showModalBottomSheet<PostcodeLocation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.canvas,
      builder: (_) => _PostcodeAreaEditor(
        service: _postcodeService,
        initialPostcode: widget.session.postcode,
      ),
    );
    if (!mounted || location == null) return;

    _latitude = location.latitude;
    _longitude = location.longitude;
    await widget.session.updateLocation(
      latitude: location.latitude,
      longitude: location.longitude,
      postcode: location.postcode,
    );
    if (!mounted) return;
    await _loadNearby(page: 1);
  }

  Future<void> _loadMore() async {
    final nextPage = (_page?.pageNumber ?? 0) + 1;
    _searchController.text = _lastQuery;
    await _loadNearby(page: nextPage, append: true);
  }

  Future<void> _loadVenuePhotos(
    List<FoodEstablishment> establishments,
  ) async {
    final missing = establishments
        .where((establishment) => !_venuePhotos.containsKey(establishment.id))
        .toList();
    if (missing.isEmpty) return;

    final photos = await _photoService.fetchFor(missing);
    if (!mounted) return;
    setState(() {
      _venuePhotos.addAll(photos);
      _resolvedVenuePhotoIds.addAll(
        missing.map((establishment) => establishment.id),
      );
    });
  }
}

class _PostcodeAreaEditor extends StatefulWidget {
  const _PostcodeAreaEditor({
    required this.service,
    required this.initialPostcode,
  });

  final PostcodeLookupService service;
  final String initialPostcode;

  @override
  State<_PostcodeAreaEditor> createState() => _PostcodeAreaEditorState();
}

class _PostcodeAreaEditorState extends State<_PostcodeAreaEditor> {
  late final TextEditingController _controller;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPostcode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        16,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
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
            Text('Update your area',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 7),
            Text(
              'Enter another UK postcode to check food hygiene ratings in that area.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'UK postcode',
                hintText: 'e.g. SW1A 1AA',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update postcode'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final location = await widget.service.lookup(_controller.text);
      if (mounted) Navigator.pop(context, location);
    } on PostcodeLookupException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _EstablishmentCard extends StatelessWidget {
  const _EstablishmentCard({
    super.key,
    required this.establishment,
    required this.photo,
    required this.photoResolved,
  });

  final FoodEstablishment establishment;
  final VenuePhoto? photo;
  final bool photoResolved;

  @override
  Widget build(BuildContext context) {
    final color = _ratingColor(establishment);
    final distance = establishment.distanceMiles;
    final address = [establishment.address, establishment.postcode]
        .where((part) => part.isNotEmpty)
        .join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VenuePhoto(
              photo: photo,
              photoResolved: photoResolved,
              businessType: establishment.businessType,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 68,
                  height: 76,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (establishment.hasNumericRating) ...[
                        Text(
                          establishment.rating,
                          style: TextStyle(
                            color: color,
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'OUT OF 5',
                          style: TextStyle(
                            color: color,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.verified_rounded, color: color, size: 28),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            establishment.rating.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        establishment.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        establishment.businessType,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.green,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            establishment.ratingSummary,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (distance != null)
                            _SmallChip(
                              icon: Icons.near_me_outlined,
                              label: '${distance.toStringAsFixed(1)} mi',
                            ),
                          if (establishment.ratingDateLabel case final date?)
                            _SmallChip(
                              icon: Icons.event_available_outlined,
                              label: 'Inspected $date',
                            ),
                          if (establishment.newRatingPending)
                            const _SmallChip(
                              icon: Icons.update_rounded,
                              label: 'New rating pending',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () => _showDirections(context),
              icon: const Icon(Icons.directions_outlined),
              label: const Text('Get directions'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDirections(BuildContext context) async {
    final destination = await showModalBottomSheet<Uri>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Directions to ${establishment.name}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Apple Maps'),
                subtitle: const Text('Open driving directions'),
                onTap: () => Navigator.pop(
                  sheetContext,
                  VenueMapLinks.appleDirections(establishment),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Google Maps'),
                subtitle: const Text('Open driving directions'),
                onTap: () => Navigator.pop(
                  sheetContext,
                  VenueMapLinks.googleDirections(establishment),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (destination != null && context.mounted) {
      await _openUrl(context, destination);
    }
  }

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps on this device.')),
      );
    }
  }

  Color _ratingColor(FoodEstablishment establishment) {
    final numeric = establishment.numericRating;
    if (numeric != null) {
      if (numeric >= 4) return AppColors.green;
      if (numeric == 3) return AppColors.warning;
      return AppColors.danger;
    }

    final rating = establishment.rating.toLowerCase();
    if (rating.contains('pass')) return AppColors.green;
    if (rating.contains('improvement')) return AppColors.danger;
    return AppColors.inkSoft;
  }
}

class _VenuePhoto extends StatelessWidget {
  const _VenuePhoto({
    required this.photo,
    required this.photoResolved,
    required this.businessType,
  });

  final VenuePhoto? photo;
  final bool photoResolved;
  final String businessType;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 8.5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!photoResolved)
              const _VenuePhotoLoading()
            else if (photo == null)
              const _VenuePhotoFallback()
            else
              Image.network(
                photo!.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _VenuePhotoFallback(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const _VenuePhotoFallback(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x990B2517)],
                  stops: [0.45, 1],
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  businessType,
                  style: const TextStyle(
                    color: AppColors.greenDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (photo != null && photo!.attribution.isNotEmpty)
              Positioned(
                right: 10,
                bottom: 8,
                child: Text(
                  'Photo: ${photo!.attribution}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VenuePhotoLoading extends StatelessWidget {
  const _VenuePhotoLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.greenSoft,
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _VenuePhotoFallback extends StatelessWidget {
  const _VenuePhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/safebite-venue-placeholder-v1.png',
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.inkSoft),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.greenSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.green, size: 30),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
