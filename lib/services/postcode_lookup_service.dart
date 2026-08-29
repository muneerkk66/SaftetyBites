import 'dart:convert';

import 'package:http/http.dart' as http;

class PostcodeLocation {
  const PostcodeLocation({
    required this.postcode,
    required this.latitude,
    required this.longitude,
  });

  final String postcode;
  final double latitude;
  final double longitude;
}

class PostcodeLookupService {
  PostcodeLookupService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<PostcodeLocation> lookup(String postcode) async {
    final compactPostcode =
        postcode.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (compactPostcode.isEmpty) {
      throw const PostcodeLookupException('Enter a UK postcode.');
    }

    final uri = Uri.https(
      'api.postcodes.io',
      '/postcodes/${Uri.encodeComponent(compactPostcode)}',
    );

    try {
      final response = await _client.get(uri, headers: const {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) {
        throw const PostcodeLookupException(
          'We could not find that UK postcode.',
        );
      }
      if (response.statusCode != 200) {
        throw const PostcodeLookupException(
          'Postcode lookup is unavailable. Please try again.',
        );
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final result = body is Map<String, dynamic>
          ? body['result'] as Map<String, dynamic>?
          : null;
      final latitude = _asDouble(result?['latitude']);
      final longitude = _asDouble(result?['longitude']);
      final formattedPostcode = result?['postcode']?.toString().trim() ?? '';
      if (latitude == null || longitude == null || formattedPostcode.isEmpty) {
        throw const PostcodeLookupException(
          'The postcode service returned incomplete location details.',
        );
      }

      return PostcodeLocation(
        postcode: formattedPostcode.toUpperCase(),
        latitude: latitude,
        longitude: longitude,
      );
    } on PostcodeLookupException {
      rethrow;
    } catch (_) {
      throw const PostcodeLookupException(
        'Could not update your area. Check your connection and try again.',
      );
    }
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void close() => _client.close();
}

class PostcodeLookupException implements Exception {
  const PostcodeLookupException(this.message);

  final String message;
}
