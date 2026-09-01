import 'package:flutter_test/flutter_test.dart';

import 'package:safebite/models/allergen.dart';
import 'package:safebite/models/family_member.dart';
import 'package:safebite/models/product.dart';
import 'package:safebite/services/allergen_matcher.dart';
import 'package:safebite/services/label_scanner_service.dart';

void main() {
  test('covers all 14 regulated UK allergen categories', () {
    expect(Allergens.regulatedOptions, hasLength(14));
    expect(
      Allergens.regulatedOptions.map((option) => option.id),
      containsAll(['crustaceans', 'molluscs']),
    );
  });

  test('separates crustaceans from molluscs', () {
    expect(
      AllergenMatcher.detectAllergens('Contains prawns'),
      contains('crustaceans'),
    );
    expect(
      AllergenMatcher.detectAllergens('Contains mussels'),
      contains('molluscs'),
    );
  });

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

  test('does not show a clear result for partial provider coverage', () {
    const product = ProductInfo(
      barcode: '12345679',
      name: 'Live product',
      brand: 'Test',
      ingredients: '',
      allergenIds: {'milk'},
      traceAllergenIds: {},
      allergenDataComplete: false,
    );
    const member = FamilyMember(
      id: '2',
      name: 'Alex',
      relationship: 'Adult',
      allergenIds: {'mustard'},
    );

    final assessment = AllergenMatcher.assess(product, member);

    expect(assessment.level, MatchLevel.unableToVerify);
  });

  test('checks a custom ingredient against the full ingredient list', () {
    const product = ProductInfo(
      barcode: '12345680',
      name: 'Buckwheat crackers',
      brand: 'Test',
      ingredients: 'Buckwheat flour, water and salt',
      allergenIds: {},
      traceAllergenIds: {},
    );
    final member = FamilyMember(
      id: '3',
      name: 'Jo',
      relationship: 'Adult',
      allergenIds: {Allergens.customId('Buckwheat')},
    );

    final assessment = AllergenMatcher.assess(product, member);

    expect(assessment.level, MatchLevel.avoid);
    expect(
      assessment.detectedAllergenIds,
      contains(Allergens.customId('Buckwheat')),
    );
  });

  test('migrates the legacy shellfish preference to both categories', () {
    final member = FamilyMember.fromJson({
      'id': '4',
      'name': 'Lee',
      'relationship': 'Adult',
      'allergenIds': ['shellfish'],
    });

    expect(member.allergenIds, containsAll(['crustaceans', 'molluscs']));
    expect(member.allergenIds, isNot(contains('shellfish')));
  });
}
