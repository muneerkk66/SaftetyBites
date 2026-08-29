import 'package:flutter_test/flutter_test.dart';
import 'package:safebite/models/food_establishment.dart';
import 'package:safebite/services/venue_map_links.dart';

void main() {
  const venue = FoodEstablishment(
    id: 1,
    name: 'Green Kitchen',
    businessType: 'Restaurant',
    address: '1 High Street',
    postcode: 'SW1A 1AA',
    rating: '5',
    ratingDate: null,
    localAuthority: 'Example Council',
    schemeType: 'FHRS',
    newRatingPending: false,
    latitude: 51.501,
    longitude: -0.142,
  );

  test('Google listing searches for the named venue and address', () {
    final uri = VenueMapLinks.googleListing(venue);

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['api'], '1');
    expect(
      uri.queryParameters['query'],
      'Green Kitchen, 1 High Street, SW1A 1AA',
    );
  });

  test('directions prefer exact FSA coordinates', () {
    expect(
      VenueMapLinks.googleDirections(venue).queryParameters['destination'],
      '51.501,-0.142',
    );
    expect(
      VenueMapLinks.appleDirections(venue).queryParameters['daddr'],
      '51.501,-0.142',
    );
  });
}
