enum MatchLevel { avoid, caution, noListedMatch, unableToVerify }

class ProductInfo {
  const ProductInfo({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.ingredients,
    required this.allergenIds,
    required this.traceAllergenIds,
    this.imageUrl,
    this.dataSource = 'Open Food Facts',
  });

  final String barcode;
  final String name;
  final String brand;
  final String ingredients;
  final Set<String> allergenIds;
  final Set<String> traceAllergenIds;
  final String? imageUrl;
  final String dataSource;

  bool get hasIngredientData =>
      ingredients.trim().isNotEmpty ||
      allergenIds.isNotEmpty ||
      traceAllergenIds.isNotEmpty;

  ProductInfo copyWith({
    String? ingredients,
    Set<String>? allergenIds,
    Set<String>? traceAllergenIds,
  }) {
    return ProductInfo(
      barcode: barcode,
      name: name,
      brand: brand,
      ingredients: ingredients ?? this.ingredients,
      allergenIds: allergenIds ?? this.allergenIds,
      traceAllergenIds: traceAllergenIds ?? this.traceAllergenIds,
      imageUrl: imageUrl,
      dataSource: dataSource,
    );
  }
}

class MemberAssessment {
  const MemberAssessment({
    required this.memberId,
    required this.level,
    required this.detectedAllergenIds,
    required this.traceAllergenIds,
  });

  final String memberId;
  final MatchLevel level;
  final Set<String> detectedAllergenIds;
  final Set<String> traceAllergenIds;
}
