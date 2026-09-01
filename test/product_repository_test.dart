import 'package:flutter_test/flutter_test.dart';
import 'package:safebite/models/offline_catalog.dart';
import 'package:safebite/models/product.dart';
import 'package:safebite/services/catalog_pack_importer.dart';
import 'package:safebite/services/missing_product_reporter.dart';
import 'package:safebite/services/open_food_facts_service.dart';
import 'package:safebite/services/paid_product_service.dart';
import 'package:safebite/services/product_local_store.dart';
import 'package:safebite/services/product_repository.dart';

void main() {
  const localProduct = ProductInfo(
    barcode: '5000000000001',
    name: 'Local product',
    brand: 'SafeBiteAI',
    ingredients: 'Oats',
    allergenIds: {'gluten'},
    traceAllergenIds: {},
  );
  const onlineProduct = ProductInfo(
    barcode: '5000000000002',
    name: 'Online product',
    brand: 'SafeBiteAI',
    ingredients: 'Rice',
    allergenIds: {},
    traceAllergenIds: {},
  );
  const paidProduct = ProductInfo(
    barcode: '5000000000003',
    name: 'Paid result',
    brand: 'SafeBiteAI',
    ingredients: '',
    allergenIds: {},
    traceAllergenIds: {},
    dataSource: 'FatSecret live lookup',
    allergenDataComplete: false,
  );
  const verifiedProduct = ProductInfo(
    barcode: '5000000000003',
    name: 'Verified result',
    brand: 'SafeBiteAI',
    ingredients: 'Oats',
    allergenIds: {'gluten'},
    traceAllergenIds: {},
    dataSource: 'SafeBiteAI verified',
  );

  test('returns local product without online calls', () async {
    final store = _MemoryStore([localProduct]);
    final openFoodFacts = _FakeOpenFoodFacts(product: onlineProduct);
    final repository = _repository(store, openFoodFacts: openFoodFacts);

    final result = await repository.lookup(localProduct.barcode);

    expect(result.origin, ProductLookupOrigin.offlineCatalog);
    expect(result.product.name, 'Local product');
    expect(openFoodFacts.lookupCalls, 0);
  });

  test('matches an AI product identity to the local catalogue', () async {
    const expected = ProductInfo(
      barcode: '5449000131805',
      name: 'Coca Cola Zero Sugar',
      brand: 'Coca-Cola',
      ingredients: 'Carbonated water, colour, sweeteners',
      allergenIds: {},
      traceAllergenIds: {},
    );
    const other = ProductInfo(
      barcode: '5000000000099',
      name: 'Chocolate Zero Sugar Bar',
      brand: 'Another brand',
      ingredients: 'Cocoa',
      allergenIds: {},
      traceAllergenIds: {},
    );
    final repository = _repository(
      _MemoryStore([other, expected]),
      openFoodFacts: _FakeOpenFoodFacts(product: onlineProduct),
    );

    final match = await repository.findLocalProduct(
      name: 'Coca-Cola Zero Sugar',
      brand: 'Coca Cola',
    );

    expect(match, expected);
  });

  test('does not guess from a generic AI product name', () async {
    const candidate = ProductInfo(
      barcode: '5000000000098',
      name: 'Dark Chocolate Bar',
      brand: 'Another brand',
      ingredients: 'Cocoa',
      allergenIds: {},
      traceAllergenIds: {},
    );
    final repository = _repository(
      _MemoryStore([candidate]),
      openFoodFacts: _FakeOpenFoodFacts(product: onlineProduct),
    );

    final match = await repository.findLocalProduct(
      name: 'Chocolate',
    );

    expect(match, isNull);
  });

  test('does not match a different flavour from the same brand', () async {
    const candidate = ProductInfo(
      barcode: '5000000000097',
      name: 'Chocolate Corn Flakes',
      brand: 'Example',
      ingredients: 'Corn, cocoa, milk',
      allergenIds: {'milk'},
      traceAllergenIds: {},
    );
    final repository = _repository(
      _MemoryStore([candidate]),
      openFoodFacts: _FakeOpenFoodFacts(product: onlineProduct),
    );

    final match = await repository.findLocalProduct(
      name: 'Corn Flakes',
      brand: 'Example',
    );

    expect(match, isNull);
  });

  test('stores Open Food Facts results for later offline checks', () async {
    final store = _MemoryStore();
    final repository = _repository(
      store,
      openFoodFacts: _FakeOpenFoodFacts(product: onlineProduct),
    );

    final result = await repository.lookup(onlineProduct.barcode);

    expect(result.origin, ProductLookupOrigin.openFoodFacts);
    expect(await store.findByBarcode(onlineProduct.barcode), onlineProduct);
  });

  test('reports identified products whose ingredient list is missing',
      () async {
    final reporter = _FakeMissingReporter();
    final repository = _repository(
      _MemoryStore(),
      openFoodFacts: _FakeOpenFoodFacts(product: paidProduct),
      missingReporter: reporter,
    );

    final result = await repository.lookup(paidProduct.barcode);
    await Future<void>.delayed(Duration.zero);

    expect(result.product.name, 'Paid result');
    expect(reporter.calls, 1);
    expect(reporter.lastReason, MissingProductReason.incompleteIngredients);
  });

  test('uses and stores a verified fallback for incomplete online data',
      () async {
    final store = _MemoryStore();
    final reporter = _FakeMissingReporter();
    final repository = _repository(
      store,
      openFoodFacts: _FakeOpenFoodFacts(product: paidProduct),
      paidService: _FakePaidService(verifiedProduct),
      missingReporter: reporter,
    );

    final result = await repository.lookup(verifiedProduct.barcode);

    expect(result.origin, ProductLookupOrigin.verifiedCatalog);
    expect(result.product, verifiedProduct);
    expect(await store.findByBarcode(verifiedProduct.barcode), verifiedProduct);
    expect(reporter.calls, 0);
  });

  test('reports incomplete products returned from the local cache', () async {
    final reporter = _FakeMissingReporter();
    final repository = _repository(
      _MemoryStore([paidProduct]),
      openFoodFacts: _FakeOpenFoodFacts(product: onlineProduct),
      missingReporter: reporter,
    );

    final result = await repository.lookup(paidProduct.barcode);
    await Future<void>.delayed(Duration.zero);

    expect(result.origin, ProductLookupOrigin.offlineCatalog);
    expect(reporter.calls, 1);
    expect(reporter.lastReason, MissingProductReason.incompleteIngredients);
  });

  test('continues online when the local database read fails', () async {
    final repository = _repository(
      _MemoryStore.failing(throwOnRead: true),
      openFoodFacts: _FakeOpenFoodFacts(product: onlineProduct),
    );

    final result = await repository.lookup(onlineProduct.barcode);

    expect(result.origin, ProductLookupOrigin.openFoodFacts);
    expect(result.product, onlineProduct);
  });

  test('returns online product when local caching fails', () async {
    final repository = _repository(
      _MemoryStore.failing(throwOnWrite: true),
      openFoodFacts: _FakeOpenFoodFacts(product: onlineProduct),
    );

    final result = await repository.lookup(onlineProduct.barcode);

    expect(result.origin, ProductLookupOrigin.openFoodFacts);
    expect(result.product, onlineProduct);
  });

  test('does not store paid provider results', () async {
    final store = _MemoryStore();
    final repository = _repository(
      store,
      openFoodFacts: _FakeOpenFoodFacts(
        error: const ProductLookupException(
          'Missing',
          failure: ProductLookupFailure.notFound,
        ),
      ),
      paidService: _FakePaidService(paidProduct),
    );

    final result = await repository.lookup(paidProduct.barcode);

    expect(result.origin, ProductLookupOrigin.paidLive);
    expect(await store.findByBarcode(paidProduct.barcode), isNull);
  });

  test('reports a product when paid provider setup fails', () async {
    final reporter = _FakeMissingReporter();
    final repository = _repository(
      _MemoryStore(),
      openFoodFacts: _FakeOpenFoodFacts(
        error: const ProductLookupException(
          'Missing',
          failure: ProductLookupFailure.notFound,
        ),
      ),
      paidService: _FakePaidService(
        null,
        error: const PaidProductServiceException(
          'Barcode access is not enabled.',
          failure: PaidProductFailure.configuration,
        ),
      ),
      missingReporter: reporter,
    );

    await expectLater(
      repository.lookup('5000000000004'),
      throwsA(
        isA<ProductLookupException>()
            .having((error) => error.failure, 'failure',
                ProductLookupFailure.unavailable)
            .having((error) => error.message, 'message',
                'Barcode access is not enabled.'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(reporter.calls, 1);
    expect(reporter.lastReason, MissingProductReason.paidProviderUnavailable);
  });

  test('reports a genuinely missing product once', () async {
    final reporter = _FakeMissingReporter();
    final repository = _repository(
      _MemoryStore(),
      openFoodFacts: _FakeOpenFoodFacts(
        error: const ProductLookupException(
          'Missing',
          failure: ProductLookupFailure.notFound,
        ),
      ),
      paidService: _FakePaidService(null),
      missingReporter: reporter,
    );

    await expectLater(
      repository.lookup('5000000000005'),
      throwsA(isA<ProductLookupException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(reporter.calls, 1);
  });
}

ProductRepository _repository(
  _MemoryStore store, {
  required _FakeOpenFoodFacts openFoodFacts,
  PaidProductService? paidService,
  MissingProductReporter? missingReporter,
}) {
  return ProductRepository(
    localStore: store,
    openFoodFacts: openFoodFacts,
    paidService: paidService ?? _FakePaidService(null),
    missingReporter: missingReporter ?? _FakeMissingReporter(),
    catalogImporter: _FakeCatalogImporter(),
  );
}

class _MemoryStore implements ProductLocalStore {
  _MemoryStore([List<ProductInfo> seed = const []])
      : throwOnRead = false,
        throwOnWrite = false,
        products = {for (final product in seed) product.barcode: product};

  _MemoryStore.failing({
    this.throwOnRead = false,
    this.throwOnWrite = false,
  }) : products = {};

  final Map<String, ProductInfo> products;
  final bool throwOnRead;
  final bool throwOnWrite;

  @override
  bool get supportsFullCatalog => true;

  @override
  Future<ProductInfo?> findByBarcode(String barcode) async {
    if (throwOnRead) throw StateError('Database read failed');
    return products[barcode];
  }

  @override
  Future<List<ProductInfo>> searchByName(
    String name, {
    String brand = '',
    int limit = 40,
  }) async =>
      products.values.take(limit).toList();

  @override
  Future<void> markCatalogImported({
    required String version,
    required DateTime updatedAt,
  }) async {}

  @override
  Future<List<ProductInfo>> searchByCategories(
    Set<String> categoryIds, {
    int limit = 50,
  }) async =>
      products.values
          .where(
              (item) => item.categoryIds.intersection(categoryIds).isNotEmpty)
          .take(limit)
          .toList();

  @override
  Future<OfflineCatalogStats> stats() async => OfflineCatalogStats(
        productCount: products.length,
        supportsFullCatalog: true,
      );

  @override
  Future<void> upsert(ProductInfo product) async {
    if (throwOnWrite) throw StateError('Database write failed');
    products[product.barcode] = product;
  }

  @override
  Future<void> upsertAll(List<ProductInfo> products) async {
    for (final product in products) {
      this.products[product.barcode] = product;
    }
  }

  @override
  Future<void> upsertCatalogAll(
    List<ProductInfo> products, {
    required String version,
  }) =>
      upsertAll(products);
}

class _FakeOpenFoodFacts extends OpenFoodFactsService {
  _FakeOpenFoodFacts({this.product, this.error});

  final ProductInfo? product;
  final ProductLookupException? error;
  int lookupCalls = 0;

  @override
  Future<ProductInfo> lookup(String barcode) async {
    lookupCalls++;
    if (error != null) throw error!;
    return product!;
  }
}

class _FakePaidService implements PaidProductService {
  _FakePaidService(this.product, {this.error});

  final ProductInfo? product;
  final PaidProductServiceException? error;

  @override
  Future<ProductInfo?> lookup(String barcode) async {
    if (error != null) throw error!;
    return product;
  }
}

class _FakeMissingReporter implements MissingProductReporter {
  int calls = 0;
  MissingProductReason? lastReason;

  @override
  Future<void> report(
    String barcode, {
    MissingProductReason reason = MissingProductReason.notFound,
  }) async {
    calls++;
    lastReason = reason;
  }
}

class _FakeCatalogImporter implements CatalogPackImporter {
  @override
  Future<OfflineCatalogManifest?> bundledManifest() async => null;

  @override
  Future<int> importBundled(
    OfflineCatalogManifest manifest, {
    required Future<void> Function(List<ProductInfo> products) onBatch,
    void Function(int imported, int expected)? onProgress,
  }) async =>
      0;

  @override
  Future<int> import(
    OfflineCatalogManifest manifest, {
    required Future<void> Function(List<ProductInfo> products) onBatch,
    void Function(int imported, int expected)? onProgress,
  }) async =>
      0;
}
