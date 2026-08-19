import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

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
  LabelScannerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<LabelScanResult?> scanIngredients() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (image == null) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(image.path);
      final result = await recognizer.processImage(input);
      return fromText(result.text);
    } finally {
      await recognizer.close();
    }
  }

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
