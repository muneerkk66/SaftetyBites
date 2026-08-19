import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../models/food_establishment.dart';
import '../../services/food_hygiene_service.dart';
import '../../widgets/brand_mark.dart';

class HygieneScreen extends StatefulWidget {
  const HygieneScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<HygieneScreen> createState() => _HygieneScreenState();
}

class _HygieneScreenState extends State<HygieneScreen> {
  final _service = FoodHygieneService();
  late final TextEditingController _searchController;

  HygieneSearchField _searchField = HygieneSearchField.address;
  List<FoodEstablishment> _establishments = const [];
  FoodHygienePage? _page;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _usingLocation = false;
  String? _error;
  String _resultLabel = '';
  double? _latitude;
  double? _longitude;
  String _lastQuery = '';
  HygieneSearchField _lastSearchField = HygieneSearchField.address;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.session.postcode);
    if (widget.session.postcode.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(page: 1));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _service.close();
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
            color: AppColors.greenDark.withOpacity(0.18),
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
                        color: Colors.white.withOpacity(0.78),
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
            FilledButton.icon(
              onPressed: _isLoading ? null : _useCurrentLocation,
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Find food places near me'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 17),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR SEARCH',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),
            SegmentedButton<HygieneSearchField>(
              segments: const [
                ButtonSegment(
                  value: HygieneSearchField.address,
                  icon: Icon(Icons.location_on_outlined),
                  label: Text('Area'),
                ),
                ButtonSegment(
                  value: HygieneSearchField.name,
                  icon: Icon(Icons.storefront_outlined),
                  label: Text('Restaurant'),
                ),
              ],
              selected: {_searchField},
              onSelectionChanged: (selection) {
                setState(() => _searchField = selection.first);
              },
            ),
            const SizedBox(height: 13),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(page: 1),
              decoration: InputDecoration(
                hintText: _searchField == HygieneSearchField.address
                    ? 'Town, street or postcode'
                    : 'Restaurant or food business name',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _isLoading ? null : () => _search(page: 1),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
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
        icon: Icons.travel_explore_rounded,
        title: 'Discover trusted food places',
        message: 'Use your location or search to see official hygiene ratings.',
      );
    }

    if (_establishments.isEmpty) {
      return const _MessageCard(
        icon: Icons.search_off_rounded,
        title: 'No places found',
        message:
            'Try another spelling, a nearby town or a wider postcode area.',
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
            child: _EstablishmentCard(establishment: establishment),
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
      ],
    );
  }

  Future<void> _search({
    required int page,
    bool append = false,
    HygieneSearchField? field,
  }) async {
    final query = _searchController.text.trim();
    final searchField = field ?? _searchField;
    if (query.isEmpty) {
      setState(() => _error = 'Enter a restaurant, town or postcode.');
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
      final result = await _service.search(
        query: query,
        field: searchField,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _usingLocation = false;
        _lastQuery = query;
        _lastSearchField = searchField;
        _page = result;
        _establishments = append
            ? [..._establishments, ...result.establishments]
            : result.establishments;
        _resultLabel = searchField == HygieneSearchField.address
            ? query.toUpperCase()
            : '“$query”';
      });
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

  Future<void> _useCurrentLocation({int page = 1, bool append = false}) async {
    if (append) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      if (!append) {
        final servicesEnabled = await Geolocator.isLocationServiceEnabled();
        if (!servicesEnabled) {
          throw const FoodHygieneException(
            'Location services are turned off. Enable them or search by area.',
          );
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw const FoodHygieneException(
            'Location permission is needed for nearby results. You can still search by area.',
          );
        }

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _latitude = position.latitude;
        _longitude = position.longitude;
      }

      final result = await _service.nearby(
        latitude: _latitude!,
        longitude: _longitude!,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _usingLocation = true;
        _page = result;
        _establishments = append
            ? [..._establishments, ...result.establishments]
            : result.establishments;
        _resultLabel = 'within 5 miles';
      });
    } on FoodHygieneException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not access your location. Check permission or search by area.';
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

  Future<void> _loadMore() async {
    final nextPage = (_page?.pageNumber ?? 0) + 1;
    if (_usingLocation) {
      await _useCurrentLocation(page: nextPage, append: true);
    } else {
      _searchController.text = _lastQuery;
      await _search(
        page: nextPage,
        append: true,
        field: _lastSearchField,
      );
    }
  }
}

class _EstablishmentCard extends StatelessWidget {
  const _EstablishmentCard({required this.establishment});

  final FoodEstablishment establishment;

  @override
  Widget build(BuildContext context) {
    final color = _ratingColor(establishment);
    final distance = establishment.distanceMiles;
    final address = [establishment.address, establishment.postcode]
        .where((part) => part.isNotEmpty)
        .join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 68,
              height: 76,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.4)),
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
      ),
    );
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
