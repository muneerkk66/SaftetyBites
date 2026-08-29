import '../models/food_establishment.dart';

class VenueMapLinks {
  const VenueMapLinks._();

  static Uri googleListing(FoodEstablishment venue) {
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': _searchQuery(venue),
    });
  }

  static Uri googleDirections(FoodEstablishment venue) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': _destination(venue),
      'travelmode': 'driving',
    });
  }

  static Uri appleDirections(FoodEstablishment venue) {
    return Uri.https('maps.apple.com', '/', {
      'daddr': _destination(venue),
      'q': venue.name,
      'dirflg': 'd',
    });
  }

  static String _destination(FoodEstablishment venue) {
    if (venue.hasCoordinates) {
      return '${venue.latitude},${venue.longitude}';
    }
    return _searchQuery(venue);
  }

  static String _searchQuery(FoodEstablishment venue) {
    return [venue.name, venue.address, venue.postcode]
        .where((part) => part.trim().isNotEmpty)
        .join(', ');
  }
}
