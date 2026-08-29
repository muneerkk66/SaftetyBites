class OfflineCatalogStats {
  const OfflineCatalogStats({
    required this.productCount,
    this.version,
    this.updatedAt,
    required this.supportsFullCatalog,
  });

  final int productCount;
  final String? version;
  final DateTime? updatedAt;
  final bool supportsFullCatalog;
}

class OfflineCatalogManifest {
  const OfflineCatalogManifest({
    required this.version,
    required this.downloadUrl,
    required this.sha256,
    required this.productCount,
  });

  final String version;
  final Uri downloadUrl;
  final String sha256;
  final int productCount;

  factory OfflineCatalogManifest.fromJson(
    Map<String, dynamic> json, {
    required Uri manifestUrl,
  }) {
    final version = json['version']?.toString().trim() ?? '';
    final rawUrl = json['downloadUrl']?.toString().trim() ?? '';
    final sha256 = json['sha256']?.toString().trim().toLowerCase() ?? '';
    final productCount = int.tryParse(json['productCount']?.toString() ?? '');
    if (version.isEmpty ||
        rawUrl.isEmpty ||
        sha256.length != 64 ||
        productCount == null ||
        productCount < 1) {
      throw const FormatException('The offline catalogue manifest is invalid.');
    }
    return OfflineCatalogManifest(
      version: version,
      downloadUrl: manifestUrl.resolve(rawUrl),
      sha256: sha256,
      productCount: productCount,
    );
  }
}
