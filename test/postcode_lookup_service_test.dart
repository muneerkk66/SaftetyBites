import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safebite/services/postcode_lookup_service.dart';

void main() {
  test('returns coordinates for a valid UK postcode', () async {
    final service = PostcodeLookupService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'status': 200,
            'result': {
              'postcode': 'SW1A 1AA',
              'latitude': 51.50101,
              'longitude': -0.141563,
            },
          }),
          200,
        ),
      ),
    );

    final location = await service.lookup('sw1a 1aa');

    expect(location.postcode, 'SW1A 1AA');
    expect(location.latitude, 51.50101);
    expect(location.longitude, -0.141563);
  });

  test('reports an unknown postcode clearly', () async {
    final service = PostcodeLookupService(
      client: MockClient((_) async => http.Response('{}', 404)),
    );

    expect(
      () => service.lookup('NOT REAL'),
      throwsA(
        isA<PostcodeLookupException>().having(
          (error) => error.message,
          'message',
          'We could not find that UK postcode.',
        ),
      ),
    );
  });
}
