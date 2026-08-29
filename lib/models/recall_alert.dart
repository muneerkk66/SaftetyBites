class RecallAlert {
  const RecallAlert({
    required this.id,
    required this.title,
    required this.summary,
    required this.retailer,
    required this.publishedLabel,
    required this.action,
    this.isRelevant = false,
    this.alertType = 'PRIN',
    this.sourceUrl = '',
    this.allergenIds = const [],
    this.retailerIds = const [],
    this.products = const [],
  });

  final String id;
  final String title;
  final String summary;
  final String retailer;
  final String publishedLabel;
  final String action;
  final bool isRelevant;
  final String alertType;
  final String sourceUrl;
  final List<String> allergenIds;
  final List<String> retailerIds;
  final List<RecallProduct> products;

  String get typeLabel => switch (alertType) {
        'AA' => 'Allergy alert',
        'PRIN' => 'Product recall',
        'FAFA' => 'Food alert for action',
        _ => 'Food safety alert',
      };

  factory RecallAlert.fromJson(Map<String, dynamic> json) {
    final businesses = _strings(json['businessNames']);
    final modified = DateTime.tryParse(json['modifiedAt']?.toString() ?? '');
    return RecallAlert(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'UK food safety alert',
      summary: json['summary']?.toString() ?? '',
      retailer: businesses.isEmpty ? 'Food Standards Agency' : businesses.first,
      publishedLabel: modified == null
          ? 'Official UK alert'
          : '${modified.day.toString().padLeft(2, '0')}/'
              '${modified.month.toString().padLeft(2, '0')}/${modified.year}',
      action: json['consumerAdvice']?.toString() ?? '',
      alertType: json['alertType']?.toString() ?? 'ALERT',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      allergenIds: _strings(json['allergenIds']),
      retailerIds: _strings(json['retailerIds']),
      products: (json['products'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => RecallProduct.fromJson(item.cast<String, dynamic>()))
          .toList(),
    );
  }

  static List<String> _strings(Object? value) =>
      (value as List<dynamic>? ?? const []).map((item) => '$item').toList();
}

class RecallProduct {
  const RecallProduct({
    required this.name,
    required this.packSize,
    required this.batchDetails,
  });

  final String name;
  final String packSize;
  final String batchDetails;

  factory RecallProduct.fromJson(Map<String, dynamic> json) => RecallProduct(
        name: json['name']?.toString() ?? '',
        packSize: json['packSize']?.toString() ?? '',
        batchDetails: json['batchDetails']?.toString() ?? '',
      );
}
