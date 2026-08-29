import '../models/food_establishment.dart';

class NearbyStoreMatch {
  const NearbyStoreMatch({required this.name, this.distanceMiles});

  final String name;
  final double? distanceMiles;
}

abstract final class NearbyStoreMatcher {
  static const supportedRadiusMiles = <double>[5, 10, 15, 20];

  static const _brandPatterns = <String, List<String>>{
    'Tesco': ['tesco'],
    'Aldi': ['aldi'],
    'Asda': ['asda'],
    'Sainsbury’s': ['sainsbury'],
    'Lidl': ['lidl'],
    'Morrisons': ['morrisons', 'wm morrison'],
    'Waitrose': ['waitrose'],
    'Iceland': ['iceland'],
    'Co-op': ['co-op', 'coop', 'co operative', 'co-operative'],
    'M&S': ['marks & spencer', 'marks and spencer', 'm&s', 'm & s'],
  };

  static List<String> get supportedBrands =>
      List<String>.unmodifiable(_brandPatterns.keys);

  static List<NearbyStoreMatch> match(
    Iterable<FoodEstablishment> establishments,
  ) {
    final nearestDistance = <String, double?>{};

    for (final establishment in establishments) {
      final businessName = establishment.name.toLowerCase();
      for (final entry in _brandPatterns.entries) {
        if (!entry.value.any(businessName.contains)) continue;

        final existing = nearestDistance[entry.key];
        final candidate = establishment.distanceMiles;
        if (!nearestDistance.containsKey(entry.key) ||
            (candidate != null && (existing == null || candidate < existing))) {
          nearestDistance[entry.key] = candidate;
        }
      }
    }

    final matches = nearestDistance.entries
        .map(
          (entry) => NearbyStoreMatch(
            name: entry.key,
            distanceMiles: entry.value,
          ),
        )
        .toList();
    matches.sort((left, right) {
      final leftDistance = left.distanceMiles ?? double.infinity;
      final rightDistance = right.distanceMiles ?? double.infinity;
      return leftDistance.compareTo(rightDistance);
    });
    return matches;
  }
}
