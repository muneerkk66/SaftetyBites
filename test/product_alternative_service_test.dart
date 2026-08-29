import 'package:flutter_test/flutter_test.dart';

import 'package:safebite/models/family_member.dart';
import 'package:safebite/models/product.dart';
import 'package:safebite/services/open_food_facts_service.dart';
import 'package:safebite/services/product_alternative_service.dart';

void main() {
  const source = ProductInfo(
    barcode: '11111111',
    name: 'Milk chocolate',
    brand: 'Example',
    ingredients: 'Sugar, cocoa, milk',
    allergenIds: {'milk'},
    traceAllergenIds: {},
    categoryIds: {'en:chocolates'},
  );
  const family = [
    FamilyMember(
      id: '1',
      name: 'Sam',
      relationship: 'Child',
      allergenIds: {'milk'},
    ),
  ];

  test('filters listed and trace allergens before AI ranking', () async {
    final ranker = _RecordingRanker();
    final service = ProductAlternativeService(
      catalog: _FakeCatalog([
        const ProductInfo(
          barcode: '22222222',
          name: 'Dark chocolate',
          brand: 'Good',
          ingredients: 'Cocoa mass, sugar',
          allergenIds: {},
          traceAllergenIds: {},
          categoryIds: {'en:chocolates'},
        ),
        const ProductInfo(
          barcode: '33333333',
          name: 'Milk bar',
          brand: 'Blocked',
          ingredients: 'Sugar, milk',
          allergenIds: {'milk'},
          traceAllergenIds: {},
          categoryIds: {'en:chocolates'},
        ),
        const ProductInfo(
          barcode: '44444444',
          name: 'Trace bar',
          brand: 'Blocked',
          ingredients: 'Cocoa. May contain milk.',
          allergenIds: {},
          traceAllergenIds: {},
          categoryIds: {'en:chocolates'},
        ),
      ]),
      ranker: ranker,
    );

    final result = await service.findAlternatives(
      source: source,
      family: family,
    );

    expect(ranker.received.map((item) => item.barcode), ['22222222']);
    expect(result.recommendations.single.product.barcode, '22222222');
    expect(result.usedAiRanking, isTrue);
  });

  test('uses deterministic recommendations when AI is unavailable', () async {
    final service = ProductAlternativeService(
      catalog: _FakeCatalog([
        const ProductInfo(
          barcode: '22222222',
          name: 'Dark chocolate',
          brand: 'Good',
          ingredients: 'Cocoa mass, sugar',
          allergenIds: {},
          traceAllergenIds: {},
          categoryIds: {'en:chocolates'},
        ),
      ]),
      ranker: _FailingRanker(),
    );

    final result = await service.findAlternatives(
      source: source,
      family: family,
    );

    expect(result.recommendations.single.product.barcode, '22222222');
    expect(result.usedAiRanking, isFalse);
  });

  test('shows a useful message when catalogue search is unavailable', () async {
    final service = ProductAlternativeService(
      catalog: _FailingCatalog(),
      ranker: _FailingRanker(),
    );

    await expectLater(
      service.findAlternatives(source: source, family: family),
      throwsA(
        isA<ProductAlternativeException>().having(
          (error) => error.message,
          'message',
          'Product search is temporarily busy. Please wait a moment and try again.',
        ),
      ),
    );
  });
}

class _FakeCatalog extends OpenFoodFactsService {
  _FakeCatalog(this.products);

  final List<ProductInfo> products;

  @override
  Future<List<ProductInfo>> searchAlternatives({
    required Set<String> categoryIds,
    int pageSize = 50,
  }) async {
    return products;
  }
}

class _RecordingRanker implements AlternativeRanker {
  List<ProductInfo> received = [];

  @override
  Future<List<AlternativeRecommendation>> rank({
    required ProductInfo source,
    required Set<String> householdAllergenIds,
    required List<ProductInfo> candidates,
  }) async {
    received = candidates;
    return candidates
        .map((product) => AlternativeRecommendation(
              product: product,
              reason: 'Closest match.',
            ))
        .toList();
  }
}

class _FailingCatalog extends OpenFoodFactsService {
  @override
  Future<List<ProductInfo>> searchAlternatives({
    required Set<String> categoryIds,
    int pageSize = 50,
  }) {
    throw StateError('Search unavailable');
  }
}

class _FailingRanker implements AlternativeRanker {
  @override
  Future<List<AlternativeRecommendation>> rank({
    required ProductInfo source,
    required Set<String> householdAllergenIds,
    required List<ProductInfo> candidates,
  }) {
    throw StateError('AI unavailable');
  }
}
