import '../models/offline_catalog.dart';
import '../models/product.dart';
import 'catalog_pack_importer_stub.dart'
    if (dart.library.io) 'catalog_pack_importer_native.dart' as platform;

abstract interface class CatalogPackImporter {
  Future<OfflineCatalogManifest?> bundledManifest();

  Future<int> importBundled(
    OfflineCatalogManifest manifest, {
    required Future<void> Function(List<ProductInfo> products) onBatch,
    void Function(int imported, int expected)? onProgress,
  });

  Future<int> import(
    OfflineCatalogManifest manifest, {
    required Future<void> Function(List<ProductInfo> products) onBatch,
    void Function(int imported, int expected)? onProgress,
  });
}

CatalogPackImporter createCatalogPackImporter() =>
    platform.createCatalogPackImporter();
