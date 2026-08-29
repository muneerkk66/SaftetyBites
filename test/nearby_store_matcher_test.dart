import 'package:flutter_test/flutter_test.dart';
import 'package:safebite/models/food_establishment.dart';
import 'package:safebite/services/nearby_store_matcher.dart';

void main() {
  test('matches known supermarket brands and keeps nearest branch', () {
    final matches = NearbyStoreMatcher.match([
      _store(name: 'Tesco Express', distance: 1.4),
      _store(name: 'Tesco Superstore', distance: 0.7),
      _store(name: 'Sainsburys Local', distance: 1.1),
      _store(name: 'Independent Market', distance: 0.2),
    ]);

    expect(matches.map((match) => match.name), ['Tesco', 'Sainsbury’s']);
    expect(matches.first.distanceMiles, 0.7);
  });
}

FoodEstablishment _store({required String name, required double distance}) {
  return FoodEstablishment(
    id: name.hashCode,
    name: name,
    businessType: 'Retailers - supermarkets/hypermarkets',
    address: '',
    postcode: '',
    rating: '5',
    ratingDate: null,
    localAuthority: '',
    schemeType: 'FHRS',
    newRatingPending: false,
    distanceMiles: distance,
  );
}
