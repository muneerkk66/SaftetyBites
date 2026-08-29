import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/food_establishment.dart';

enum HygieneSearchField { name, address }

class FoodHygieneService {
  FoodHygieneService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'api.ratings.food.gov.uk';
  static const _pageSize = 20;
  static const _supermarketSearchTerms = <String>[
    'Tesco',
    'Aldi',
    'Asda',
    'Sainsbury',
    'Lidl',
    'Morrisons',
    'Waitrose',
    'Iceland',
    'Co-op',
    'Marks Spencer',
  ];

  final http.Client _client;

  Future<FoodHygienePage> search({
    required String query,
    required HygieneSearchField field,
    int page = 1,
  }) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      throw const FoodHygieneException('Enter a restaurant, town or postcode.');
    }

    return _request({
      field == HygieneSearchField.name ? 'name' : 'address': trimmedQuery,
      'sortOptionKey': 'desc_rating',
      'pageNumber': '$page',
      'pageSize': '$_pageSize',
    });
  }

  Future<FoodHygienePage> nearby({
    required double latitude,
    required double longitude,
    double radiusMiles = 5,
    int page = 1,
    int pageSize = _pageSize,
    String? name,
    int? businessTypeId,
  }) {
    return _request({
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
      'maxDistanceLimit': radiusMiles.toStringAsFixed(1),
      if (businessTypeId != null) 'businessTypeId': '$businessTypeId',
      'sortOptionKey': 'distance',
      'pageNumber': '$page',
      'pageSize': '$pageSize',
    });
  }

  Future<FoodHygienePage> nearbySupermarkets({
    required double latitude,
    required double longitude,
    double radiusMiles = 5,
  }) {
    return nearby(
      latitude: latitude,
      longitude: longitude,
      radiusMiles: radiusMiles,
      businessTypeId: 7840,
      pageSize: 100,
    );
  }

  Future<List<FoodEstablishment>> nearbySupermarketCandidates({
    required double latitude,
    required double longitude,
    double radiusMiles = 5,
  }) async {
    final pages = await Future.wait(
      _supermarketSearchTerms.map(
        (name) => nearby(
          latitude: latitude,
          longitude: longitude,
          radiusMiles: radiusMiles,
          name: name,
          businessTypeId: 7840,
          pageSize: 5,
        ),
      ),
    );
    return pages.expand((page) => page.establishments).toList();
  }

  Future<FoodHygienePage> _request(Map<String, String> query) async {
    final uri = Uri.https(_baseUrl, '/Establishments', query);

    try {
      final response = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'x-api-version': '2',
        },
      ).timeout(const Duration(seconds: 18));

      if (response.statusCode != 200) {
        throw FoodHygieneException(
          'The hygiene service returned ${response.statusCode}. Please try again.',
        );
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) {
        throw const FoodHygieneException(
          'The hygiene service returned an unexpected response.',
        );
      }

      return FoodHygienePage.fromJson(body);
    } on FoodHygieneException {
      rethrow;
    } catch (_) {
      throw const FoodHygieneException(
        'Could not load hygiene ratings. Check your connection and try again.',
      );
    }
  }

  void close() => _client.close();
}

class FoodHygieneException implements Exception {
  const FoodHygieneException(this.message);

  final String message;

  @override
  String toString() => message;
}
