import '../models/offline_catalog.dart';
import '../models/product.dart';
import 'catalog_pack_importer.dart';

CatalogPackImporter createCatalogPackImporter() =>
    _UnsupportedCatalogPackImporter();

class _UnsupportedCatalogPackImporter implements CatalogPackImporter {
  @override
  Future<int> import(
    OfflineCatalogManifest manifest, {
    required Future<void> Function(List<ProductInfo> products) onBatch,
    void Function(int imported, int expected)? onProgress,
  }) {
    throw UnsupportedError(
      'The full offline catalogue is available in the iOS and Android apps.',
    );
  }
}
