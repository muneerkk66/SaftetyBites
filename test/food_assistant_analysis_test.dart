import 'package:flutter_test/flutter_test.dart';

import 'package:safebite/models/food_assistant_analysis.dart';
import 'package:safebite/models/product.dart';

void main() {
  test('parses image analysis as incomplete without a full label', () {
    final analysis = FoodAssistantAnalysis.fromJson({
      'reply': 'I can identify the likely product, but not its ingredients.',
      'product': {
        'name': 'Example cereal bar',
        'brand': 'Example',
        'barcode': '',
        'ingredients': '',
        'listedAllergenIds': <String>[],
        'traceAllergenIds': <String>[],
        'hasCompleteIngredientLabel': false,
        'confidence': 0.82,
      },
      'findings': [
        {'level': 'info', 'text': 'Front packaging is visible.'},
      ],
      'needsAnotherImage': true,
      'nextImagePrompt': 'Photograph the full ingredients label.',
      'suggestedQuestions': ['What should I photograph?'],
    });

    expect(analysis.product.name, 'Example cereal bar');
    expect(analysis.product.allergenDataComplete, isFalse);
    expect(analysis.needsAnotherImage, isTrue);
    expect(analysis.confidence, 0.82);
  });

  test('enriches an image identity with offline catalogue evidence', () {
    final imageAnalysis = FoodAssistantAnalysis.fromJson({
      'reply': 'The front of the pack is visible.',
      'product': {
        'name': 'Example cereal bar',
        'brand': 'Example',
        'barcode': '',
        'ingredients': '',
        'listedAllergenIds': <String>[],
        'traceAllergenIds': <String>[],
        'hasCompleteIngredientLabel': false,
        'confidence': 0.82,
      },
      'findings': <Map<String, dynamic>>[],
      'needsAnotherImage': true,
      'nextImagePrompt': 'Photograph the ingredients label.',
      'suggestedQuestions': <String>[],
    });
    const catalogProduct = ProductInfo(
      barcode: '5000000000001',
      name: 'Example cereal bar',
      brand: 'Example',
      ingredients: 'Oats, milk',
      allergenIds: {'milk', 'gluten'},
      traceAllergenIds: {},
    );

    final enriched = imageAnalysis.withCatalogProduct(catalogProduct);

    expect(enriched.product, catalogProduct);
    expect(enriched.needsAnotherImage, isFalse);
    expect(enriched.reply, contains('offline catalogue'));
    expect(enriched.findings.first.text, contains('offline catalogue'));
  });
}
