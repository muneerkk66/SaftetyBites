import 'package:flutter_test/flutter_test.dart';
import 'package:safebite/models/food_establishment.dart';

void main() {
  test('parses an official hygiene establishment response', () {
    final establishment = FoodEstablishment.fromJson({
      'FHRSID': 123,
      'BusinessName': 'Green Kitchen',
      'BusinessType': 'Restaurant/Cafe/Canteen',
      'AddressLine1': '1 High Street',
      'AddressLine2': '',
      'AddressLine3': 'London',
      'PostCode': 'SW1A 1AA',
      'RatingValue': '5',
      'RatingDate': '2026-08-10T00:00:00',
      'LocalAuthorityName': 'Westminster',
      'SchemeType': 'FHRS',
      'NewRatingPending': false,
      'Distance': 1.25,
    });

    expect(establishment.id, 123);
    expect(establishment.name, 'Green Kitchen');
    expect(establishment.address, '1 High Street, London');
    expect(establishment.numericRating, 5);
    expect(establishment.ratingSummary, 'Very good');
    expect(establishment.ratingDateLabel, '10 Aug 2026');
    expect(establishment.distanceMiles, 1.25);
  });

  test('describes Scottish pass ratings', () {
    final establishment = FoodEstablishment.fromJson({
      'FHRSID': 456,
      'BusinessName': 'North Cafe',
      'RatingValue': 'Pass',
      'SchemeType': 'FHIS',
    });

    expect(establishment.hasNumericRating, isFalse);
    expect(establishment.ratingSummary, 'Meets hygiene standards');
    expect(establishment.ratingDateLabel, isNull);
  });
}
