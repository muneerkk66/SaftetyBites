import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/offline_catalog.dart';
import '../models/product.dart';
import 'catalog_pack_importer.dart';
import 'missing_product_reporter.dart';
import 'open_food_facts_service.dart';
import 'paid_product_service.dart';
import 'product_local_store.dart';
import 'product_name_matcher.dart';
import 'product_search_catalog.dart';

enum ProductLookupOrigin {
  offlineCatalog,
  verifiedCatalog,
  openFoodFacts,
  paidLive,
}

class ProductLookupResult {
  const ProductLookupResult({
    required this.product,
    required this.origin,
  });

  final ProductInfo product;
  final ProductLookupOrigin origin;

  bool get storedLocally => origin != ProductLookupOrigin.paidLive;
}

class OfflineCatalogException implements Exception {
  const OfflineCatalogException(this.message);

  final String message;
}

class ProductRepository implements ProductSearchCatalog {
  ProductRepository({
    ProductLocalStore? localStore,
    OpenFoodFactsService? openFoodFacts,
    PaidProductService? paidService,
    MissingProductReporter? missingReporter,
    CatalogPackImporter? catalogImporter,
    http.Client? client,
    String? manifestUrl,
  })  : _localStore = localStore ?? createProductLocalStore(),
        _openFoodFacts = openFoodFacts ?? OpenFoodFactsService(),
        _paidService = paidService ?? FirebasePaidProductService(),
        _missingReporter = missingReporter ?? FirebaseMissingProductReporter(),
        _catalogImporter = catalogImporter ?? createCatalogPackImporter(),
        _client = client ?? http.Client(),
        _manifestUrl = manifestUrl ??
            const String.fromEnvironment(
              'OFFLINE_CATALOG_MANIFEST_URL',
              defaultValue:
                  'https://safebites-4a21a.web.app/catalog/manifest.json',
            );

  static final ProductRepository instance = ProductRepository();

  final ProductLocalStore _localStore;
  final OpenFoodFactsService _openFoodFacts;
  final PaidProductService _paidService;
  final MissingProductReporter _missingReporter;
  final CatalogPackImporter _catalogImporter;
  final http.Client _client;
  final String _manifestUrl;

  Future<ProductLookupResult> lookup(String barcode) async {
    final normalized = barcode.replaceAll(RegExp(r'\D'), '');
    if (normalized.length < 8) {
      throw const ProductLookupException(
        'That barcode looks incomplete.',
        failure: ProductLookupFailure.invalidBarcode,
      );
    }

    ProductInfo? localProduct;
    try {
      localProduct = await _localStore.findByBarcode(normalized);
    } catch (_) {
      localProduct = null;
    }
    if (localProduct != null) {
      if (localProduct.ingredients.trim().isEmpty) {
        return _lookupIncompleteProduct(
          localProduct,
          fallbackOrigin: ProductLookupOrigin.offlineCatalog,
        );
      }
      return ProductLookupResult(
        product: localProduct,
        origin: ProductLookupOrigin.offlineCatalog,
      );
    }

    try {
      final product = await _openFoodFacts.lookup(normalized);
      try {
        await _localStore.upsert(product);
      } catch (_) {}
      if (product.ingredients.trim().isEmpty) {
        return await _lookupIncompleteProduct(
          product,
          fallbackOrigin: ProductLookupOrigin.openFoodFacts,
        );
      }
      return ProductLookupResult(
        product: product,
        origin: ProductLookupOrigin.openFoodFacts,
      );
    } on ProductLookupException catch (error) {
      if (error.failure == ProductLookupFailure.invalidBarcode ||
          error.failure == ProductLookupFailure.offline) {
        rethrow;
      }
      return _lookupPaidOrReport(normalized, fallbackError: error);
    }
  }

  @override
  Future<List<ProductInfo>> searchAlternatives({
    required Set<String> categoryIds,
    int pageSize = 50,
  }) async {
    final local = await _localStore.searchByCategories(
      categoryIds,
      limit: pageSize,
    );
    if (local.length >= 12) return local;
    final online = await _openFoodFacts.searchAlternatives(
      categoryIds: categoryIds,
      pageSize: pageSize,
    );
    if (online.isNotEmpty) await _localStore.upsertAll(online);
    final combined = <String, ProductInfo>{
      for (final product in local) product.barcode: product,
      for (final product in online) product.barcode: product,
    };
    return combined.values.toList();
  }

  Future<OfflineCatalogStats> catalogStats() => _localStore.stats();

  Future<int> bootstrapBundledCatalog({
    void Function(int imported, int expected)? onProgress,
  }) async {
    if (!_localStore.supportsFullCatalog) return 0;
    final manifest = await _catalogImporter.bundledManifest();
    if (manifest == null) return 0;
    final current = await _localStore.stats();
    if (current.version == manifest.version &&
        current.productCount >= manifest.productCount * 0.95) {
      return 0;
    }
    final imported = await _catalogImporter.importBundled(
      manifest,
      onBatch: (products) => _localStore.upsertCatalogAll(
        products,
        version: manifest.version,
      ),
      onProgress: onProgress,
    );
    await _localStore.markCatalogImported(
      version: manifest.version,
      updatedAt: DateTime.now(),
    );
    return imported;
  }

  Future<ProductInfo?> findLocalProduct({
    String barcode = '',
    required String name,
    String brand = '',
  }) async {
    try {
      final normalizedBarcode = barcode.replaceAll(RegExp(r'\D'), '');
      if (normalizedBarcode.length >= 8) {
        final barcodeMatch = await _localStore.findByBarcode(normalizedBarcode);
        if (barcodeMatch != null) return barcodeMatch;
      }
      final candidates = await _localStore.searchByName(
        name,
        brand: brand,
      );
      return bestProductNameMatch(
        name: name,
        brand: brand,
        candidates: candidates,
      );
    } catch (_) {
      return null;
    }
  }

  Future<int> syncOfflineCatalog({
    void Function(int imported, int expected)? onProgress,
  }) async {
    if (!_localStore.supportsFullCatalog) {
      throw const OfflineCatalogException(
        'Full offline downloads are available in the iOS and Android apps.',
      );
    }
    final manifestText = _manifestUrl.trim();
    if (manifestText.isEmpty) {
      throw const OfflineCatalogException(
        'The offline catalogue download has not been published yet.',
      );
    }
    try {
      final manifestUri = Uri.parse(manifestText);
      final response = await _client
          .get(manifestUri, headers: {'Accept': 'application/json'}).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        throw const OfflineCatalogException(
          'The offline catalogue is unavailable right now.',
        );
      }
      final manifest = OfflineCatalogManifest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
        manifestUrl: manifestUri,
      );
      final current = await _localStore.stats();
      if (current.version == manifest.version &&
          current.productCount >= manifest.productCount * 0.95) {
        return 0;
      }
      final imported = await _catalogImporter.import(
        manifest,
        onBatch: (products) => _localStore.upsertCatalogAll(
          products,
          version: manifest.version,
        ),
        onProgress: onProgress,
      );
      await _localStore.markCatalogImported(
        version: manifest.version,
        updatedAt: DateTime.now(),
      );
      return imported;
    } on OfflineCatalogException {
      rethrow;
    } on TimeoutException {
      throw const OfflineCatalogException(
        'The catalogue request timed out. Try again on a stable connection.',
      );
    } on FormatException {
      throw const OfflineCatalogException(
        'The published offline catalogue is invalid.',
      );
    } on http.ClientException {
      throw const OfflineCatalogException(
        'Connect to the internet before updating the offline catalogue.',
      );
    } catch (_) {
      throw const OfflineCatalogException(
        'The offline catalogue could not be updated.',
      );
    }
  }

  Future<ProductLookupResult> _lookupPaidOrReport(
    String barcode, {
    required ProductLookupException fallbackError,
  }) async {
    try {
      final product = await _paidService.lookup(barcode);
      if (product != null) {
        return ProductLookupResult(
          product: product,
          origin: ProductLookupOrigin.paidLive,
        );
      }
    } on PaidProductServiceException catch (error) {
      unawaited(_missingReporter.report(
        barcode,
        reason: MissingProductReason.paidProviderUnavailable,
      ));
      throw ProductLookupException(
        error.message,
        failure: ProductLookupFailure.unavailable,
      );
    } catch (_) {
      unawaited(_missingReporter.report(
        barcode,
        reason: MissingProductReason.paidProviderUnavailable,
      ));
      throw const ProductLookupException(
        'The extended product lookup is temporarily unavailable. Try again later.',
        failure: ProductLookupFailure.unavailable,
      );
    }
    unawaited(_missingReporter.report(barcode));
    throw ProductLookupException(
      'We checked our offline catalogue and online providers, but could not '
      'confirm this product. It has been added to our review list.',
      failure: fallbackError.failure == ProductLookupFailure.invalidResponse
          ? ProductLookupFailure.invalidResponse
          : ProductLookupFailure.notFound,
    );
  }

  Future<ProductLookupResult> _lookupIncompleteProduct(
    ProductInfo product, {
    required ProductLookupOrigin fallbackOrigin,
  }) async {
    try {
      final fallback = await _paidService.lookup(product.barcode);
      if (fallback != null && fallback.hasIngredientData) {
        if (fallback.dataSource == 'SafeBiteAI verified') {
          try {
            await _localStore.upsert(fallback);
          } catch (_) {}
          return ProductLookupResult(
            product: fallback,
            origin: ProductLookupOrigin.verifiedCatalog,
          );
        }
        return ProductLookupResult(
          product: fallback,
          origin: ProductLookupOrigin.paidLive,
        );
      }
    } catch (_) {}
    _reportIncompleteIngredients(product);
    return ProductLookupResult(product: product, origin: fallbackOrigin);
  }

  void _reportIncompleteIngredients(ProductInfo product) {
    if (product.ingredients.trim().isNotEmpty) return;
    unawaited(
      _missingReporter.report(
        product.barcode,
        reason: MissingProductReason.incompleteIngredients,
      ),
    );
  }
}
