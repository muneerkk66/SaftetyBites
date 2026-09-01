import 'product.dart';

enum AssistantFindingLevel { info, positive, warning }

class AssistantFinding {
  const AssistantFinding({required this.level, required this.text});

  final AssistantFindingLevel level;
  final String text;

  factory AssistantFinding.fromJson(Map<String, dynamic> json) {
    final level = switch (json['level']?.toString()) {
      'positive' => AssistantFindingLevel.positive,
      'warning' => AssistantFindingLevel.warning,
      _ => AssistantFindingLevel.info,
    };
    return AssistantFinding(
      level: level,
      text: json['text']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'text': text,
      };
}

class FoodAssistantAnalysis {
  const FoodAssistantAnalysis({
    required this.reply,
    required this.product,
    required this.findings,
    required this.needsAnotherImage,
    required this.nextImagePrompt,
    required this.suggestedQuestions,
    required this.confidence,
  });

  final String reply;
  final ProductInfo product;
  final List<AssistantFinding> findings;
  final bool needsAnotherImage;
  final String nextImagePrompt;
  final List<String> suggestedQuestions;
  final double confidence;

  FoodAssistantAnalysis withCatalogProduct(ProductInfo catalogProduct) {
    final productLabel = catalogProduct.brand.trim().isEmpty
        ? catalogProduct.name
        : '${catalogProduct.brand} ${catalogProduct.name}';
    return FoodAssistantAnalysis(
      reply: 'I identified $productLabel and found a matching entry in the '
          'offline catalogue. I’m showing its recorded ingredients and '
          'allergen details. Compare them with the current pack because '
          'recipes can change.',
      product: catalogProduct,
      findings: [
        const AssistantFinding(
          level: AssistantFindingLevel.info,
          text: 'Matched by product identity to the offline catalogue.',
        ),
        ...findings,
      ],
      needsAnotherImage: false,
      nextImagePrompt: '',
      suggestedQuestions: {
        'Explain the recorded allergens',
        ...suggestedQuestions,
      }.take(4).toList(),
      confidence: confidence,
    );
  }

  factory FoodAssistantAnalysis.fromJson(Map<String, dynamic> json) {
    final rawProduct = json['product'] is Map<String, dynamic>
        ? json['product'] as Map<String, dynamic>
        : <String, dynamic>{};
    final confidence = _number(rawProduct['confidence']).clamp(0, 1).toDouble();
    final completeLabel = rawProduct['hasCompleteIngredientLabel'] == true;
    final product = ProductInfo.fromJson({
      'barcode': rawProduct['barcode'],
      'name': rawProduct['name'],
      'brand': rawProduct['brand'],
      'ingredients': rawProduct['ingredients'],
      'allergenIds': rawProduct['listedAllergenIds'],
      'traceAllergenIds': rawProduct['traceAllergenIds'],
      'dataSource': 'SafeBiteAI image analysis',
      'completeness': completeLabel ? confidence : confidence * 0.5,
      'allergenDataComplete': completeLabel,
    });

    return FoodAssistantAnalysis(
      reply: json['reply']?.toString().trim() ?? '',
      product: product,
      findings: _maps(json['findings'])
          .map(AssistantFinding.fromJson)
          .where((item) => item.text.isNotEmpty)
          .toList(),
      needsAnotherImage: json['needsAnotherImage'] == true,
      nextImagePrompt: json['nextImagePrompt']?.toString().trim() ?? '',
      suggestedQuestions: _strings(json['suggestedQuestions']).take(4).toList(),
      confidence: confidence,
    );
  }

  Map<String, dynamic> toContextJson() => {
        'reply': reply,
        'product': {
          'name': product.name,
          'brand': product.brand,
          'barcode': product.barcode,
          'ingredients': product.ingredients,
          'listedAllergenIds': product.allergenIds.toList(),
          'traceAllergenIds': product.traceAllergenIds.toList(),
          'hasCompleteIngredientLabel': product.allergenDataComplete,
          'confidence': confidence,
        },
        'findings': findings.map((item) => item.toJson()).toList(),
        'needsAnotherImage': needsAnotherImage,
        'nextImagePrompt': nextImagePrompt,
        'suggestedQuestions': suggestedQuestions,
      };
}

class FoodAssistantTurn {
  const FoodAssistantTurn({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List<dynamic>) return const [];
  return value.whereType<Map<String, dynamic>>().toList();
}

List<String> _strings(dynamic value) {
  if (value is! List<dynamic>) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
