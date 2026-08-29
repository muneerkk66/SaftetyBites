import 'package:cloud_functions/cloud_functions.dart';

import '../models/food_establishment.dart';

class VenuePhoto {
  const VenuePhoto({required this.url, required this.attribution});

  final String url;
  final String attribution;
}

class VenuePhotoService {
  VenuePhotoService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west2');

  final FirebaseFunctions _functions;

  Future<Map<int, VenuePhoto>> fetchFor(
    List<FoodEstablishment> establishments,
  ) async {
    if (establishments.isEmpty) return const {};

    try {
      final callable = _functions.httpsCallable(
        'getVenuePhotos',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 35)),
      );
      final response = await callable.call<Map<String, dynamic>>({
        'venues': establishments
            .take(20)
            .map(
              (venue) => {
                'id': venue.id,
                'name': venue.name,
                'address': venue.address,
                'postcode': venue.postcode,
                'latitude': venue.latitude,
                'longitude': venue.longitude,
              },
            )
            .toList(),
      });
      final rawPhotos = response.data['photos'];
      if (rawPhotos is! List) return const {};

      return {
        for (final rawPhoto in rawPhotos)
          if (rawPhoto is Map)
            int.tryParse(rawPhoto['id']?.toString() ?? '') ?? -1: VenuePhoto(
              url: rawPhoto['url']?.toString() ?? '',
              attribution: rawPhoto['attribution']?.toString() ?? '',
            ),
      }..removeWhere((id, photo) => id <= 0 || photo.url.isEmpty);
    } catch (_) {
      return const {};
    }
  }
}
