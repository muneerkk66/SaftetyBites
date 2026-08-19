import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/allergen.dart';
import '../models/product.dart';

class ProductLookupException implements Exception {
  const ProductLookupException(this.message);

  final String message;
}

class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<ProductInfo> lookup(String barcode) async {
    final normalized = barcode.replaceAll(RegExp(r'\D'), '');
    if (normalized.length < 8) {
      throw const ProductLookupException('That barcode looks incomplete.');
    }

    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v3/product/$normalized',
      {
        'fields': [
          'code',
          'product_name',
          'brands',
          'ingredients_text',
          'allergens_tags',
          'traces_tags',
          'image_front_small_url',
        ].join(','),
      },
    );

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (!kIsWeb) {
        headers['User-Agent'] = 'SafeBite/1.0 (support@wemendai.app)';
      }
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const ProductLookupException(
            'Product information is unavailable right now.');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final productJson = json['product'] as Map<String, dynamic>?;
      if (productJson == null) {
        throw const ProductLookupException(
          'We could not find this barcode. Scan the ingredients label instead.',
        );
      }

      return ProductInfo(
        barcode: normalized,
        name: _text(productJson['product_name'], fallback: 'Unknown product'),
        brand: _text(productJson['brands'], fallback: 'Brand not listed'),
        ingredients: _text(productJson['ingredients_text']),
        allergenIds: _mapTags(productJson['allergens_tags']),
        traceAllergenIds: _mapTags(productJson['traces_tags']),
        imageUrl: productJson['image_front_small_url'] as String?,
      );
    } on ProductLookupException {
      rethrow;
    } on TimeoutException {
      throw const ProductLookupException(
          'The product lookup took too long. Try again.');
    } on http.ClientException {
      throw const ProductLookupException(
          'Connect to the internet and try again.');
    } on FormatException {
      throw const ProductLookupException(
          'We could not read the product information.');
    }
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Set<String> _mapTags(dynamic rawTags) {
    if (rawTags is! List<dynamic>) return {};
    final tags = rawTags
        .map((tag) =>
            tag.toString().split(':').last.toLowerCase().replaceAll('-', ' '))
        .toList();
    final joined = tags.join(' ');
    final matches = Allergens.options
        .where((option) => option.terms.any(joined.toLowerCase().contains))
        .map((option) => option.id)
        .toSet();
    if (tags.any((tag) => tag == 'nuts' || tag == 'tree nuts')) {
      matches.add('tree_nuts');
    }
    return matches;
  }
}
