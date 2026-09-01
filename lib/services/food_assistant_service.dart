import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/food_assistant_analysis.dart';

class FoodAssistantException implements Exception {
  const FoodAssistantException(this.message);

  final String message;
}

class FoodAssistantService {
  FoodAssistantService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west2');

  static const maximumImageBytes = 6000000;

  final FirebaseFunctions _functions;

  Future<FoodAssistantAnalysis> ask({
    required String message,
    Uint8List? imageBytes,
    String? mimeType,
    FoodAssistantAnalysis? context,
    List<FoodAssistantTurn> history = const [],
  }) async {
    if (imageBytes != null && imageBytes.length > maximumImageBytes) {
      throw const FoodAssistantException(
        'That image is too large. Choose a smaller or lower-quality photo.',
      );
    }
    if (imageBytes == null && context == null) {
      throw const FoodAssistantException(
        'Add a product or ingredient-label photo first.',
      );
    }

    try {
      final callable = _functions.httpsCallable(
        'foodAssistant',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );
      final response = await callable.call<dynamic>({
        'message': message.trim(),
        if (imageBytes != null) 'imageBase64': base64Encode(imageBytes),
        if (imageBytes != null) 'mimeType': mimeType ?? 'image/jpeg',
        if (context != null) 'context': context.toContextJson(),
        'history': history
            .skip(history.length > 8 ? history.length - 8 : 0)
            .map((item) => item.toJson())
            .toList(),
      });
      final data =
          jsonDecode(jsonEncode(response.data)) as Map<String, dynamic>;
      return FoodAssistantAnalysis.fromJson(data);
    } on FirebaseFunctionsException catch (error) {
      final message = error.message?.trim();
      if (error.code == 'unauthenticated') {
        throw const FoodAssistantException(
          'Sign in with Apple or Google to use the AI food assistant.',
        );
      }
      throw FoodAssistantException(
        message == null || message.isEmpty
            ? 'The AI food assistant is unavailable right now.'
            : message,
      );
    } on FoodAssistantException {
      rethrow;
    } catch (_) {
      throw const FoodAssistantException(
        'The AI food assistant is unavailable right now. Try again shortly.',
      );
    }
  }
}
