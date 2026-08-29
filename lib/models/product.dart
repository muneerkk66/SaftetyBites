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
    this.categoryIds = const <String>{},
    this.completeness = 0,
    this.popularity = 0,
    this.allergenDataComplete = true,
  });

  final String barcode;
  final String name;
  final String brand;
  final String ingredients;
  final Set<String> allergenIds;
  final Set<String> traceAllergenIds;
  final String? imageUrl;
  final String dataSource;
  final Set<String> categoryIds;
  final double completeness;
  final double popularity;
  final bool allergenDataComplete;

  bool get hasIngredientData =>
      ingredients.trim().isNotEmpty ||
      allergenIds.isNotEmpty ||
      traceAllergenIds.isNotEmpty;

  ProductInfo copyWith({
    String? name,
    String? brand,
    String? ingredients,
    Set<String>? allergenIds,
    Set<String>? traceAllergenIds,
    String? imageUrl,
    String? dataSource,
    Set<String>? categoryIds,
    double? completeness,
    double? popularity,
    bool? allergenDataComplete,
  }) {
    return ProductInfo(
      barcode: barcode,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      ingredients: ingredients ?? this.ingredients,
      allergenIds: allergenIds ?? this.allergenIds,
      traceAllergenIds: traceAllergenIds ?? this.traceAllergenIds,
      imageUrl: imageUrl ?? this.imageUrl,
      dataSource: dataSource ?? this.dataSource,
      categoryIds: categoryIds ?? this.categoryIds,
      completeness: completeness ?? this.completeness,
      popularity: popularity ?? this.popularity,
      allergenDataComplete: allergenDataComplete ?? this.allergenDataComplete,
    );
  }

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    Set<String> stringSet(dynamic value) {
      if (value is! List<dynamic>) return <String>{};
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet();
    }

    double number(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return ProductInfo(
      barcode: json['barcode']?.toString() ?? json['code']?.toString() ?? '',
      name: json['name']?.toString() ??
          json['product_name']?.toString() ??
          'Unknown product',
      brand: json['brand']?.toString() ??
          json['brands']?.toString() ??
          'Brand not listed',
      ingredients: json['ingredients']?.toString() ??
          json['ingredients_text']?.toString() ??
          '',
      allergenIds: stringSet(json['allergenIds'] ?? json['allergen_ids']),
      traceAllergenIds:
          stringSet(json['traceAllergenIds'] ?? json['trace_allergen_ids']),
      imageUrl: (json['imageUrl'] ?? json['image_url'])?.toString(),
      dataSource: json['dataSource']?.toString() ??
          json['data_source']?.toString() ??
          'Open Food Facts',
      categoryIds: stringSet(json['categoryIds'] ?? json['category_ids']),
      completeness: number(json['completeness']),
      popularity: number(json['popularity']),
      allergenDataComplete: json['allergenDataComplete'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'ingredients': ingredients,
        'allergenIds': allergenIds.toList(),
        'traceAllergenIds': traceAllergenIds.toList(),
        'imageUrl': imageUrl,
        'dataSource': dataSource,
        'categoryIds': categoryIds.toList(),
        'completeness': completeness,
        'popularity': popularity,
        'allergenDataComplete': allergenDataComplete,
      };
}

class AlternativeRecommendation {
  const AlternativeRecommendation({
    required this.product,
    required this.reason,
  });

  final ProductInfo product;
  final String reason;
}

class AlternativeSearchResult {
  const AlternativeSearchResult({
    required this.recommendations,
    required this.usedAiRanking,
  });

  final List<AlternativeRecommendation> recommendations;
  final bool usedAiRanking;
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
