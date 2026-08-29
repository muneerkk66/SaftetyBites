import '../models/product.dart';

abstract interface class ProductSearchCatalog {
  Future<List<ProductInfo>> searchAlternatives({
    required Set<String> categoryIds,
    int pageSize = 50,
  });
}
