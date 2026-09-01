import '../models/allergen.dart';
import '../models/family_member.dart';
import '../models/product.dart';

abstract final class AllergenMatcher {
  static Set<String> detectAllergens(String text) {
    final normalized = text.toLowerCase();
    return Allergens.options
        .where((option) =>
            option.terms.any((term) => _containsTerm(normalized, term)))
        .map((option) => option.id)
        .toSet();
  }

  static MemberAssessment assess(ProductInfo product, FamilyMember member) {
    if (!product.hasIngredientData) {
      return MemberAssessment(
        memberId: member.id,
        level: MatchLevel.unableToVerify,
        detectedAllergenIds: const {},
        traceAllergenIds: const {},
      );
    }

    final memberAllergenIds = Allergens.expandLegacyIds(member.allergenIds);
    final detected = Allergens.expandLegacyIds(product.allergenIds)
        .intersection(memberAllergenIds);
    final traces = Allergens.expandLegacyIds(product.traceAllergenIds)
        .intersection(memberAllergenIds);
    final normalizedIngredients = product.ingredients.toLowerCase();
    if (normalizedIngredients.isNotEmpty) {
      for (final id in memberAllergenIds) {
        final option = Allergens.byId(id);
        if (option.terms.any(
          (term) => _containsTerm(normalizedIngredients, term),
        )) {
          detected.add(id);
        }
      }
    }
    final level = detected.isNotEmpty
        ? MatchLevel.avoid
        : traces.isNotEmpty
            ? MatchLevel.caution
            : product.allergenDataComplete
                ? MatchLevel.noListedMatch
                : MatchLevel.unableToVerify;

    return MemberAssessment(
      memberId: member.id,
      level: level,
      detectedAllergenIds: detected,
      traceAllergenIds: traces,
    );
  }

  static bool _containsTerm(String text, String term) {
    final escaped = RegExp.escape(term.toLowerCase());
    return RegExp('(^|[^a-z])$escaped(?:s|es)?([^a-z]|\$)').hasMatch(text);
  }
}
