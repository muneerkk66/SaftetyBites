import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

      final products = <ProductInfo>[];
      var imported = 0;
      final lines = packFile
          .openRead()
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
    } finally {
      if (await packFile.exists()) await packFile.delete();
    }
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
