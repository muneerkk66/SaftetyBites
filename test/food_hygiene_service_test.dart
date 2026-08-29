import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safebite/models/food_establishment.dart';
import 'package:safebite/services/food_hygiene_service.dart';

void main() {
  test('parses official FSA venue coordinates', () {
    final page = FoodHygienePage.fromJson({
      'establishments': [
        {
          'FHRSID': 1,
          'BusinessName': 'Green Kitchen',
          'BusinessType': 'Restaurant',
          'RatingValue': '5',
          'geocode': {
            'latitude': '51.501',
            'longitude': '-0.142',
          },
        },
      ],
      'meta': {
        'pageNumber': 1,
        'totalPages': 1,
        'totalCount': 1,
      },
    });

    expect(page.establishments.single.latitude, 51.501);
    expect(page.establishments.single.longitude, -0.142);
  });

  test('nearby search sends business name and radius to FSA', () async {
    late Uri requestedUri;
    final service = FoodHygieneService(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'establishments': <Object>[],
            'meta': {
              'pageNumber': 1,
              'totalPages': 1,
              'totalCount': 0,
            },
          }),
          200,
        );
      }),
    );

    await service.nearby(
      latitude: 51.5,
      longitude: -0.1,
      radiusMiles: 10,
      name: 'Green Kitchen',
    );

    expect(requestedUri.queryParameters['name'], 'Green Kitchen');
    expect(requestedUri.queryParameters['maxDistanceLimit'], '10.0');
    expect(requestedUri.queryParameters['sortOptionKey'], 'distance');
  });
}
