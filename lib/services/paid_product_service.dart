import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/product.dart';

abstract interface class PaidProductService {
  Future<ProductInfo?> lookup(String barcode);
}

enum PaidProductFailure {
  authentication,
  configuration,
  unavailable,
}

class PaidProductServiceException implements Exception {
  const PaidProductServiceException(this.message, {required this.failure});

  final String message;
  final PaidProductFailure failure;
}

class FirebasePaidProductService implements PaidProductService {
  FirebasePaidProductService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west2');

  final FirebaseFunctions _functions;

  @override
  Future<ProductInfo?> lookup(String barcode) async {
    final callable = _functions.httpsCallable(
      'lookupFallbackProduct',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    try {
      final response = await callable.call<dynamic>({'barcode': barcode});
      final data = jsonDecode(jsonEncode(response.data));
      if (data is! Map<String, dynamic> || data['product'] == null) return null;
      final product = ProductInfo.fromJson(
        Map<String, dynamic>.from(data['product'] as Map),
      );
      if (product.dataSource == 'SafeBiteAI verified') return product;
      return product.copyWith(
        dataSource: 'FatSecret live lookup',
        allergenDataComplete: false,
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found') return null;
      if (error.code == 'unauthenticated') {
        throw const PaidProductServiceException(
          'Sign in again to use the extended product lookup.',
          failure: PaidProductFailure.authentication,
        );
      }
      if (error.code == 'failed-precondition') {
        throw PaidProductServiceException(
          error.message ??
              'The extended product provider needs additional setup.',
          failure: PaidProductFailure.configuration,
        );
      }
      throw const PaidProductServiceException(
        'The extended product lookup is temporarily unavailable. Try again later.',
        failure: PaidProductFailure.unavailable,
      );
    }
  }
}
