import 'package:flutter_test/flutter_test.dart';

import 'package:safebite/models/family_member.dart';
import 'package:safebite/models/product.dart';
import 'package:safebite/services/allergen_matcher.dart';
import 'package:safebite/services/label_scanner_service.dart';

void main() {
  test('separates listed allergens from may contain warnings', () {
    final scan = LabelScannerService().fromText(
      'Ingredients: wheat flour, cocoa.\nMay contain peanuts and milk.',
    );

    expect(scan.allergenIds, contains('gluten'));
    expect(scan.traceAllergenIds, containsAll(['peanuts', 'milk']));
    expect(scan.allergenIds, isNot(contains('peanuts')));
  });

  test('returns avoid when a family allergen is listed', () {
    const product = ProductInfo(
      barcode: '12345678',
      name: 'Test product',
      brand: 'Test',
      ingredients: 'Contains milk',
      allergenIds: {'milk'},
      traceAllergenIds: {},
    );
    const member = FamilyMember(
      id: '1',
      name: 'Sam',
      relationship: 'Child',
      allergenIds: {'milk'},
    );

    final assessment = AllergenMatcher.assess(product, member);

    expect(assessment.level, MatchLevel.avoid);
  });
}
