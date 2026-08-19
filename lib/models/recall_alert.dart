class RecallAlert {
  const RecallAlert({
    required this.id,
    required this.title,
    required this.summary,
    required this.retailer,
    required this.publishedLabel,
    required this.action,
    this.isRelevant = false,
  });

  final String id;
  final String title;
  final String summary;
  final String retailer;
  final String publishedLabel;
  final String action;
  final bool isRelevant;
}
