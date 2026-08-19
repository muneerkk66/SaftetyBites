import '../models/product.dart';
import 'allergen_matcher.dart';

class LabelScanResult {
  const LabelScanResult({
    required this.text,
    required this.allergenIds,
    required this.traceAllergenIds,
  });

  final String text;
  final Set<String> allergenIds;
  final Set<String> traceAllergenIds;
}

class LabelScannerService {
  Future<LabelScanResult?> scanIngredients() async => null;

  LabelScanResult fromText(String text) {
    final sections = _splitSections(text);
    return LabelScanResult(
      text: text,
      allergenIds: AllergenMatcher.detectAllergens(sections[0]),
      traceAllergenIds: AllergenMatcher.detectAllergens(sections[1]),
    );
  }

  ProductInfo mergeWithProduct(ProductInfo product, LabelScanResult scan) {
    return product.copyWith(
      ingredients: scan.text,
      allergenIds: {...product.allergenIds, ...scan.allergenIds},
      traceAllergenIds: {...product.traceAllergenIds, ...scan.traceAllergenIds},
    );
  }

  List<String> _splitSections(String text) {
    final normalized = text.toLowerCase();
    const markers = [
      'may contain',
      'possible traces',
      'made in a factory',
      'made in a facility',
    ];
    final indexes = markers
        .map(normalized.indexOf)
        .where((index) => index >= 0)
        .toList()
      ..sort();
    if (indexes.isEmpty) return [text, ''];
    final splitAt = indexes.first;
    return [text.substring(0, splitAt), text.substring(splitAt)];
  }
}
