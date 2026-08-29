import 'package:cloud_functions/cloud_functions.dart';

import '../models/recall_alert.dart';

class RecallFeedResult {
  const RecallFeedResult({required this.alerts, required this.checkedAt});

  final List<RecallAlert> alerts;
  final DateTime? checkedAt;
}

class RecallFeedService {
  RecallFeedService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west2');

  final FirebaseFunctions _functions;

  Future<RecallFeedResult> latest() async {
    try {
      final callable = _functions.httpsCallable(
        'listFoodAlerts',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 35)),
      );
      final result = await callable.call<Map<String, dynamic>>();
      final rawAlerts = result.data['alerts'];
      return RecallFeedResult(
        alerts: rawAlerts is List
            ? rawAlerts
                .whereType<Map>()
                .map(
                  (alert) =>
                      RecallAlert.fromJson(alert.cast<String, dynamic>()),
                )
                .where((alert) => alert.id.isNotEmpty)
                .toList()
            : const [],
        checkedAt:
            DateTime.tryParse(result.data['checkedAt']?.toString() ?? ''),
      );
    } catch (_) {
      throw const RecallFeedException(
        'Could not check official UK food alerts. Please try again.',
      );
    }
  }
}

class RecallFeedException implements Exception {
  const RecallFeedException(this.message);

  final String message;
}
