import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/family_member.dart';
import '../models/product.dart';
import 'label_scanner_service.dart';
import 'product_repository.dart';
import 'product_search_catalog.dart';

class ProductAlternativeException implements Exception {
  const ProductAlternativeException(this.message);

  final String message;
}

abstract interface class AlternativeRanker {
  Future<List<AlternativeRecommendation>> rank({
    required ProductInfo source,
    required Set<String> householdAllergenIds,
    required List<ProductInfo> candidates,
  });
}

class FirebaseAlternativeRanker implements AlternativeRanker {
  FirebaseAlternativeRanker({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west2');

  final FirebaseFunctions _functions;

  @override
  Future<List<AlternativeRecommendation>> rank({
    required ProductInfo source,
    required Set<String> householdAllergenIds,
    required List<ProductInfo> candidates,
  }) async {
    final callable = _functions.httpsCallable(
      'rankAlternatives',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    final response = await callable.call<dynamic>({
      'source': _productPayload(source),
      'candidates': candidates.map(_productPayload).toList(),
    });
    final data = jsonDecode(jsonEncode(response.data)) as Map<String, dynamic>;
    final rankings = data['rankings'] as List<dynamic>? ?? const [];
    final byBarcode = {for (final item in candidates) item.barcode: item};
    final recommendations = <AlternativeRecommendation>[];
    for (final rawRanking in rankings) {
      if (rawRanking is! Map<String, dynamic>) continue;
      final barcode = rawRanking['barcode']?.toString() ?? '';
      final product = byBarcode.remove(barcode);
      if (product == null) continue;
      final reason = rawRanking['reason']?.toString().trim() ?? '';
      recommendations.add(AlternativeRecommendation(
        product: product,
        reason: reason.isEmpty ? _fallbackReason(product, source) : reason,
      ));
    }
    recommendations.addAll(byBarcode.values.map(
      (product) => AlternativeRecommendation(
        product: product,
        reason: _fallbackReason(product, source),
      ),
    ));
    return recommendations;
  }

  static Map<String, dynamic> _productPayload(ProductInfo product) => {
        'barcode': product.barcode,
        'name': product.name,
        'brand': product.brand,
        'categories': product.categoryIds.toList(),
        'allergens': product.allergenIds.toList(),
        'traces': product.traceAllergenIds.toList(),
        'completeness': product.completeness,
        'popularity': product.popularity,
      };
}

class ProductAlternativeService {
  ProductAlternativeService({
    ProductSearchCatalog? catalog,
    AlternativeRanker? ranker,
  })  : _catalog = catalog ?? ProductRepository.instance,
        _ranker = ranker ?? FirebaseAlternativeRanker();

  final ProductSearchCatalog _catalog;
  final AlternativeRanker _ranker;
  final LabelScannerService _labelScanner = LabelScannerService();

  Future<AlternativeSearchResult> findAlternatives({
    required ProductInfo source,
    required List<FamilyMember> family,
    int limit = 6,
  }) async {
    final householdAllergens =
        family.expand((member) => member.allergenIds).toSet();
    if (householdAllergens.isEmpty) {
      throw const ProductAlternativeException(
        'Add at least one household allergen before finding alternatives.',
      );
    }
    if (source.categoryIds.isEmpty) {
      throw const ProductAlternativeException(
        'This product does not have enough category information to find a close alternative.',
      );
    }

    late final List<ProductInfo> catalogProducts;
    try {
      catalogProducts = await _catalog.searchAlternatives(
        categoryIds: source.categoryIds,
      );
    } catch (_) {
      throw const ProductAlternativeException(
        'Product search is temporarily busy. Please wait a moment and try again.',
      );
    }
    final eligible = catalogProducts
        .where((product) => product.barcode != source.barcode)
        .map(_withLabelChecks)
        .where((product) => _isEligible(product, householdAllergens))
        .toList()
      ..sort((first, second) =>
          _score(second, source).compareTo(_score(first, source)));

    if (eligible.isEmpty) {
      throw const ProductAlternativeException(
        'No suitable alternatives could be verified from the available product data.',
      );
    }

    final shortlist = eligible.take(12).toList();
    try {
      final ranked = await _ranker.rank(
        source: source,
        householdAllergenIds: householdAllergens,
        candidates: shortlist,
      );
      return AlternativeSearchResult(
        recommendations: ranked.take(limit).toList(),
        usedAiRanking: true,
      );
    } catch (_) {
      return AlternativeSearchResult(
        recommendations: shortlist
            .take(limit)
            .map((product) => AlternativeRecommendation(
                  product: product,
                  reason: _fallbackReason(product, source),
                ))
            .toList(),
        usedAiRanking: false,
      );
    }
  }

  ProductInfo _withLabelChecks(ProductInfo product) {
    if (product.ingredients.trim().isEmpty) return product;
    final scan = _labelScanner.fromText(product.ingredients);
    return product.copyWith(
      allergenIds: {...product.allergenIds, ...scan.allergenIds},
      traceAllergenIds: {
        ...product.traceAllergenIds,
        ...scan.traceAllergenIds,
      },
    );
  }

  bool _isEligible(ProductInfo product, Set<String> householdAllergens) {
    if (product.ingredients.trim().isEmpty) return false;
    return product.allergenIds.intersection(householdAllergens).isEmpty &&
        product.traceAllergenIds.intersection(householdAllergens).isEmpty;
  }

  double _score(ProductInfo product, ProductInfo source) {
    final categoryMatches =
        product.categoryIds.intersection(source.categoryIds).length;
    return categoryMatches * 1000 +
        product.completeness * 100 +
        product.popularity +
        (product.imageUrl == null ? 0 : 25);
  }
}

String _fallbackReason(ProductInfo product, ProductInfo source) {
  final sharedCategories =
      product.categoryIds.intersection(source.categoryIds).length;
  if (sharedCategories > 1) {
    return 'A close match in the same product category.';
  }
  return 'A similar option with no listed household allergen conflict.';
}
