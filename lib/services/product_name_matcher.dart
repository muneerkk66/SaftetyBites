import '../models/product.dart';

const _ignoredWords = {
  'a',
  'an',
  'and',
  'by',
  'food',
  'for',
  'of',
  'pack',
  'packet',
  'product',
  'the',
  'with',
};

List<String> productNameTerms(String value) {
  final normalized =
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  if (normalized.isEmpty) return const [];
  return normalized
      .split(RegExp(r'\s+'))
      .where((term) =>
          term.length > 1 &&
          !_ignoredWords.contains(term) &&
          !RegExp(r'^\d+(g|kg|ml|l)?$').hasMatch(term))
      .toSet()
      .toList();
}

ProductInfo? bestProductNameMatch({
  required String name,
  required String brand,
  required List<ProductInfo> candidates,
}) {
  if (candidates.isEmpty) return null;
  final scored = candidates
      .map(
        (candidate) => (
          product: candidate,
          score: productNameMatchScore(
            name: name,
            brand: brand,
            candidate: candidate,
          ),
        ),
      )
      .toList()
    ..sort((first, second) => second.score.compareTo(first.score));
  final best = scored.first;
  return best.score >= 60 ? best.product : null;
}

double productNameMatchScore({
  required String name,
  required String brand,
  required ProductInfo candidate,
}) {
  final queryName = _normalized(name);
  final candidateName = _normalized(candidate.name);
  if (queryName.isEmpty || candidateName.isEmpty) return 0;

  final queryTerms = productNameTerms(name).toSet();
  final candidateTerms = productNameTerms(candidate.name).toSet();
  if (queryTerms.isEmpty || candidateTerms.isEmpty) return 0;
  final sharedNameTerms = queryTerms.intersection(candidateTerms).length;
  if (sharedNameTerms == 0) return 0;
  final queryCoverage = sharedNameTerms / queryTerms.length;
  final candidateCoverage = sharedNameTerms / candidateTerms.length;
  if (queryName != candidateName &&
      (queryCoverage < 0.8 || candidateCoverage < 0.8)) {
    return 0;
  }

  var score = queryName == candidateName ? 100.0 : 0.0;
  score += queryCoverage * 55;
  score += candidateCoverage * 20;
  if (queryName.contains(candidateName) || candidateName.contains(queryName)) {
    score += 15;
  }

  final queryBrand = _normalized(brand);
  if (queryBrand.isNotEmpty) {
    final candidateBrand = _normalized(candidate.brand);
    if (queryBrand == candidateBrand) {
      score += 25;
    } else {
      final brandTerms = productNameTerms(brand).toSet();
      final candidateBrandTerms = productNameTerms(candidate.brand).toSet();
      final sharedBrandTerms = brandTerms.intersection(candidateBrandTerms);
      score += sharedBrandTerms.isEmpty ? -25 : 15;
    }
  } else if (queryTerms.length < 2 && queryName != candidateName) {
    return 0;
  }
  return score;
}

String _normalized(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
