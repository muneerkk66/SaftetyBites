import 'package:cloud_functions/cloud_functions.dart';

abstract interface class MissingProductReporter {
  Future<void> report(
    String barcode, {
    MissingProductReason reason = MissingProductReason.notFound,
  });
}

enum MissingProductReason {
  notFound,
  paidProviderUnavailable,
  incompleteIngredients,
}

class FirebaseMissingProductReporter implements MissingProductReporter {
  FirebaseMissingProductReporter({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west2');

  final FirebaseFunctions _functions;

  @override
  Future<void> report(
    String barcode, {
    MissingProductReason reason = MissingProductReason.notFound,
  }) async {
    try {
      await _functions
          .httpsCallable(
        'reportMissingProduct',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 8),
        ),
      )
          .call<void>({'barcode': barcode, 'reason': reason.name});
    } catch (_) {}
  }
}
