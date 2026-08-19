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

    final detected = product.allergenIds.intersection(member.allergenIds);
    final traces = product.traceAllergenIds.intersection(member.allergenIds);
    final level = detected.isNotEmpty
        ? MatchLevel.avoid
        : traces.isNotEmpty
            ? MatchLevel.caution
            : MatchLevel.noListedMatch;

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
