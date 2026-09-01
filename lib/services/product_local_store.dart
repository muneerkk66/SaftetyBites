import '../models/offline_catalog.dart';
import '../models/product.dart';
import 'product_local_store_stub.dart'
    if (dart.library.io) 'product_local_store_native.dart' as platform;

abstract interface class ProductLocalStore {
  bool get supportsFullCatalog;

  Future<ProductInfo?> findByBarcode(String barcode);

  Future<List<ProductInfo>> searchByName(
    String name, {
    String brand = '',
    int limit = 40,
  });

  Future<List<ProductInfo>> searchByCategories(
    Set<String> categoryIds, {
    int limit = 50,
  });

  Future<void> upsert(ProductInfo product);

  Future<void> upsertAll(List<ProductInfo> products);

  Future<void> upsertCatalogAll(
    List<ProductInfo> products, {
    required String version,
  });

  Future<OfflineCatalogStats> stats();

  Future<void> markCatalogImported({
    required String version,
    required DateTime updatedAt,
  });
}

ProductLocalStore createProductLocalStore() =>
    platform.createProductLocalStore();
