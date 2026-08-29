import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/allergen.dart';
import '../models/product.dart';
import 'product_search_catalog.dart';

enum ProductLookupFailure {
  invalidBarcode,
  notFound,
  offline,
  unavailable,
  invalidResponse,
}

class ProductLookupException implements Exception {
  const ProductLookupException(this.message, {required this.failure});

  final String message;
  final ProductLookupFailure failure;
}

class OpenFoodFactsService implements ProductSearchCatalog {
  OpenFoodFactsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<ProductInfo> lookup(String barcode) async {
    final normalized = barcode.replaceAll(RegExp(r'\D'), '');
    if (normalized.length < 8) {
      throw const ProductLookupException(
        'That barcode looks incomplete.',
        failure: ProductLookupFailure.invalidBarcode,
      );
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
          'categories_tags',
          'completeness',
          'popularity_key',
          'image_front_small_url',
        ].join(','),
      },
    );

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (!kIsWeb) {
        headers['User-Agent'] = 'SafeBiteAI/1.0 (support@safebiteai.co.uk)';
      }
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const ProductLookupException(
          'Product information is unavailable right now.',
          failure: ProductLookupFailure.unavailable,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final productJson = json['product'] as Map<String, dynamic>?;
      if (productJson == null) {
        throw const ProductLookupException(
          'We could not find this barcode. Scan the ingredients label instead.',
          failure: ProductLookupFailure.notFound,
        );
      }

      return _productFromJson(productJson, fallbackBarcode: normalized);
    } on ProductLookupException {
      rethrow;
    } on TimeoutException {
      throw const ProductLookupException(
        'The product lookup took too long. Try again.',
        failure: ProductLookupFailure.offline,
      );
    } on http.ClientException {
      throw const ProductLookupException(
        'Connect to the internet and try again.',
        failure: ProductLookupFailure.offline,
      );
    } on FormatException {
      throw const ProductLookupException(
        'We could not read the product information.',
        failure: ProductLookupFailure.invalidResponse,
      );
    }
  }

  @override
  Future<List<ProductInfo>> searchAlternatives({
    required Set<String> categoryIds,
    int pageSize = 50,
  }) async {
    if (categoryIds.isEmpty) return const [];

    final results = <String, ProductInfo>{};
    final categories = categoryIds.toList().reversed.take(2);
    final requestSize = pageSize.clamp(12, 24);
    for (final category in categories) {
      final uri = Uri.https(
        'world.openfoodfacts.org',
        '/api/v2/search',
        {
          'categories_tags': category,
          'countries_tags_en': 'united-kingdom',
          'sort_by': 'last_modified_t',
          'page': '1',
          'page_size': '$requestSize',
          'fields': [
            'code',
            'product_name',
            'brands',
            'ingredients_text',
            'allergens_tags',
            'traces_tags',
            'categories_tags',
            'completeness',
            'popularity_key',
            'image_front_small_url',
          ].join(','),
        },
      );

      try {
        final response = await _client
            .get(uri, headers: _headers())
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) continue;
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final products = json['products'] as List<dynamic>? ?? const [];
        for (final rawProduct in products) {
          if (rawProduct is! Map<String, dynamic>) continue;
          final product = _productFromJson(rawProduct);
          if (product.barcode.isNotEmpty) {
            results[product.barcode] = product;
          }
        }
      } on TimeoutException {
        continue;
      } on http.ClientException {
        continue;
      } on FormatException {
        continue;
      }

      if (results.length >= 12) break;
    }
    return results.values.toList();
  }

  ProductInfo _productFromJson(
    Map<String, dynamic> productJson, {
    String fallbackBarcode = '',
  }) {
    return ProductInfo(
      barcode: _text(productJson['code'], fallback: fallbackBarcode),
      name: _text(productJson['product_name'], fallback: 'Unknown product'),
      brand: _text(productJson['brands'], fallback: 'Brand not listed'),
      ingredients: _text(productJson['ingredients_text']),
      allergenIds: _mapTags(productJson['allergens_tags']),
      traceAllergenIds: _mapTags(productJson['traces_tags']),
      imageUrl: productJson['image_front_small_url'] as String?,
      categoryIds: _stringSet(productJson['categories_tags']),
      completeness: _number(productJson['completeness']),
      popularity: _number(productJson['popularity_key']),
    );
  }

  Map<String, String> _headers() {
    final headers = <String, String>{'Accept': 'application/json'};
    if (!kIsWeb) {
      headers['User-Agent'] = 'SafeBiteAI/1.0 (support@safebiteai.co.uk)';
    }
    return headers;
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

  Set<String> _stringSet(dynamic rawValues) {
    if (rawValues is! List<dynamic>) return const {};
    return rawValues
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
