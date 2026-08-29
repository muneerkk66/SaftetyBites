import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/offline_catalog.dart';
import '../models/product.dart';
import 'product_local_store.dart';

ProductLocalStore createProductLocalStore() => _BrowserProductLocalStore();

class _BrowserProductLocalStore implements ProductLocalStore {
  static const _cacheKey = 'product_lookup_cache_v1';
  static const _maxProducts = 250;

  @override
  bool get supportsFullCatalog => false;

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<ProductInfo?> findByBarcode(String barcode) async {
    final products = await _read();
    final json = products[barcode];
    return json == null ? null : ProductInfo.fromJson(json);
  }

  @override
  Future<List<ProductInfo>> searchByCategories(
    Set<String> categoryIds, {
    int limit = 50,
  }) async {
    final products = (await _read())
        .values
        .map(ProductInfo.fromJson)
        .where((product) =>
            product.categoryIds.intersection(categoryIds).isNotEmpty)
        .take(limit)
        .toList();
    return products;
  }

  @override
  Future<void> upsert(ProductInfo product) => upsertAll([product]);

  @override
  Future<void> upsertAll(List<ProductInfo> products) async {
    if (products.isEmpty) return;
    final cache = await _read();
    for (final product in products) {
      cache.remove(product.barcode);
      cache[product.barcode] = product.toJson();
    }
    while (cache.length > _maxProducts) {
      cache.remove(cache.keys.first);
    }
    final preferences = await _preferences;
    await preferences.setString(_cacheKey, jsonEncode(cache));
  }

  @override
  Future<void> upsertCatalogAll(
    List<ProductInfo> products, {
    required String version,
  }) =>
      upsertAll(products);

  @override
  Future<OfflineCatalogStats> stats() async => OfflineCatalogStats(
        productCount: (await _read()).length,
        supportsFullCatalog: false,
      );

  @override
  Future<void> markCatalogImported({
    required String version,
    required DateTime updatedAt,
  }) async {}

  Future<Map<String, Map<String, dynamic>>> _read() async {
    final preferences = await _preferences;
    final raw = preferences.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(
            key,
            Map<String, dynamic>.from(value as Map),
          ));
    } catch (_) {
      return {};
    }
  }
}
