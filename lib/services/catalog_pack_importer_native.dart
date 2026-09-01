import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/offline_catalog.dart';
import '../models/product.dart';
import 'catalog_pack_importer.dart';

CatalogPackImporter createCatalogPackImporter() => _NativeCatalogPackImporter();

class _NativeCatalogPackImporter implements CatalogPackImporter {
  _NativeCatalogPackImporter({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _manifestAsset = 'assets/catalog/manifest.json';

  @override
  Future<OfflineCatalogManifest?> bundledManifest() async {
    final manifestText = await rootBundle.loadString(_manifestAsset);
    return OfflineCatalogManifest.fromJson(
      jsonDecode(manifestText) as Map<String, dynamic>,
      manifestUrl: Uri.parse('asset:///$_manifestAsset'),
    );
  }

  @override
  Future<int> importBundled(
    OfflineCatalogManifest manifest, {
    required Future<void> Function(List<ProductInfo> products) onBatch,
    void Function(int imported, int expected)? onProgress,
  }) async {
    final filename = manifest.downloadUrl.pathSegments.last;
    final data = await rootBundle.load('assets/catalog/$filename');
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    if (sha256.convert(bytes).toString() != manifest.sha256) {
      throw const FormatException(
        'The bundled catalogue failed its integrity check.',
      );
    }
    return _importStream(
      Stream.value(bytes),
      manifest,
      onBatch: onBatch,
      onProgress: onProgress,
    );
  }

  @override
  Future<int> import(
    OfflineCatalogManifest manifest, {
    required Future<void> Function(List<ProductInfo> products) onBatch,
    void Function(int imported, int expected)? onProgress,
  }) async {
    final temporaryDirectory = await getTemporaryDirectory();
    final packFile = File(
      '${temporaryDirectory.path}/safebite-${manifest.version}.jsonl.gz',
    );
    try {
      await _download(manifest.downloadUrl, packFile);
      final digest = await sha256.bind(packFile.openRead()).first;
      if (digest.toString() != manifest.sha256) {
        throw const FormatException(
          'The downloaded catalogue failed its integrity check.',
        );
      }

      return await _importStream(
        packFile.openRead(),
        manifest,
        onBatch: onBatch,
        onProgress: onProgress,
      );
    } finally {
      if (await packFile.exists()) await packFile.delete();
    }
  }

  Future<int> _importStream(
    Stream<List<int>> compressed,
    OfflineCatalogManifest manifest, {
    required Future<void> Function(List<ProductInfo> products) onBatch,
    void Function(int imported, int expected)? onProgress,
  }) async {
    final products = <ProductInfo>[];
    var imported = 0;
    final lines = compressed
        .transform(gzip.decoder)
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final json = jsonDecode(line) as Map<String, dynamic>;
      final product = ProductInfo.fromJson(json);
      if (product.barcode.isEmpty) continue;
      products.add(product);
      if (products.length >= 400) {
        await onBatch(List<ProductInfo>.from(products));
        imported += products.length;
        products.clear();
        onProgress?.call(imported, manifest.productCount);
      }
    }
    if (products.isNotEmpty) {
      await onBatch(products);
      imported += products.length;
      onProgress?.call(imported, manifest.productCount);
    }
    if (imported < manifest.productCount * 0.95) {
      throw const FormatException(
        'The catalogue did not contain the expected number of products.',
      );
    }
    return imported;
  }

  Future<void> _download(Uri url, File destination) async {
    final request = http.Request('GET', url);
    request.headers['Accept'] = 'application/gzip, application/octet-stream';
    final response = await _client.send(request).timeout(
          const Duration(seconds: 30),
        );
    if (response.statusCode != 200) {
      throw HttpException(
        'The offline catalogue could not be downloaded.',
        uri: url,
      );
    }
    final sink = destination.openWrite();
    try {
      await response.stream.pipe(sink);
    } finally {
      await sink.close();
    }
  }
}
