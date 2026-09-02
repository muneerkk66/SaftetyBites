import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safebite/services/open_food_facts_service.dart';

void main() {
  test('product lookup identifies SafeBiteAI to Open Food Facts', () async {
    late http.Request captured;
    final service = OpenFoodFactsService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'product': {
              'code': '5000112546415',
              'product_name': 'Example product',
            },
          }),
          200,
        );
      }),
    );

    await service.lookup('5000112546415');

    expect(captured.headers['User-Agent'], contains('SafeBiteAI/1.0'));
    expect(
        captured.headers['User-Agent'], contains('support@safebiteai.co.uk'));
  });

  test('alternative search uses one lightweight category request', () async {
    final requests = <http.Request>[];
    final service = OpenFoodFactsService(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'products': List.generate(
              12,
              (index) => {
                'code': '5000000000${index.toString().padLeft(2, '0')}',
                'product_name': 'Alternative $index',
                'brands': 'Example',
                'ingredients_text': 'Cocoa, sugar',
                'categories_tags': ['en:chocolates'],
              },
            ),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final products = await service.searchAlternatives(
      categoryIds: {'en:snacks', 'en:chocolates'},
    );

    expect(products, hasLength(12));
    expect(requests, hasLength(1));
    expect(requests.single.url.queryParameters['categories_tags'],
        'en:chocolates');
    expect(requests.single.url.queryParameters['sort_by'], 'last_modified_t');
    expect(requests.single.url.queryParameters['page_size'], '24');
  });
}
