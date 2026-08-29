import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/offline_catalog.dart';
import '../models/product.dart';
import 'product_local_store.dart';

ProductLocalStore createProductLocalStore() => _SqliteProductLocalStore();

class _SqliteProductLocalStore implements ProductLocalStore {
  Database? _database;

  @override
  bool get supportsFullCatalog => true;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;
    final database = await openDatabase(
      path.join(await getDatabasesPath(), 'safebite_products.db'),
      version: 2,
      onCreate: (database, _) => _ensureSchema(database),
      onUpgrade: (database, _, __) => _ensureSchema(database),
      onOpen: _ensureSchema,
    );
    _database = database;
    return database;
  }

  Future<void> _ensureSchema(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS products (
        barcode TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        ingredients TEXT NOT NULL,
        allergen_ids TEXT NOT NULL,
        trace_allergen_ids TEXT NOT NULL,
        image_url TEXT,
        data_source TEXT NOT NULL,
        completeness REAL NOT NULL,
        popularity REAL NOT NULL,
        allergen_data_complete INTEGER NOT NULL,
        catalog_version TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');
    final productColumns =
        await database.rawQuery('PRAGMA table_info(products)');
    if (!productColumns.any((column) => column['name'] == 'catalog_version')) {
      await database.execute(
        'ALTER TABLE products ADD COLUMN catalog_version TEXT',
      );
    }
    await database.execute('''
      CREATE TABLE IF NOT EXISTS product_categories (
        barcode TEXT NOT NULL,
        category_id TEXT NOT NULL,
        PRIMARY KEY (barcode, category_id)
      )
    ''');
    await database.execute('''
      CREATE INDEX IF NOT EXISTS category_lookup
      ON product_categories(category_id, barcode)
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  @override
  Future<ProductInfo?> findByBarcode(String barcode) async {
    final database = await _db;
    final rows = await database.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _productFromRow(
      rows.first,
      await _categoriesFor(database, [barcode]),
    );
  }

  @override
  Future<List<ProductInfo>> searchByCategories(
    Set<String> categoryIds, {
    int limit = 50,
  }) async {
    if (categoryIds.isEmpty) return const [];
    final database = await _db;
    final placeholders = List.filled(categoryIds.length, '?').join(',');
    final rows = await database.rawQuery('''
      SELECT p.*, COUNT(c.category_id) AS category_matches
      FROM products p
      JOIN product_categories c ON c.barcode = p.barcode
      WHERE c.category_id IN ($placeholders)
      GROUP BY p.barcode
      ORDER BY category_matches DESC, p.popularity DESC
      LIMIT ?
    ''', [...categoryIds, limit]);
    final barcodes = rows.map((row) => row['barcode']! as String).toList();
    final categories = await _categoriesFor(database, barcodes);
    return rows.map((row) => _productFromRow(row, categories)).toList();
  }

  @override
  Future<void> upsert(ProductInfo product) => upsertAll([product]);

  @override
  Future<void> upsertAll(List<ProductInfo> products) async {
    await _upsertAll(products);
  }

  @override
  Future<void> upsertCatalogAll(
    List<ProductInfo> products, {
    required String version,
  }) async {
    await _upsertAll(products, catalogVersion: version);
  }

  Future<void> _upsertAll(
    List<ProductInfo> products, {
    String? catalogVersion,
  }) async {
    if (products.isEmpty) return;
    final database = await _db;
    await database.transaction((transaction) async {
      final batch = transaction.batch();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final product in products) {
        batch.insert(
          'products',
          _rowFromProduct(product, now, catalogVersion: catalogVersion),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.delete(
          'product_categories',
          where: 'barcode = ?',
          whereArgs: [product.barcode],
        );
        for (final category in product.categoryIds) {
          batch.insert(
            'product_categories',
            {'barcode': product.barcode, 'category_id': category},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<OfflineCatalogStats> stats() async {
    final database = await _db;
    final count = Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM products'),
        ) ??
        0;
    final metadata = await database.query('metadata');
    final values = {
      for (final row in metadata)
        row['key']! as String: row['value']! as String,
    };
    return OfflineCatalogStats(
      productCount: count,
      version: values['catalog_version'],
      updatedAt: DateTime.tryParse(values['catalog_updated_at'] ?? ''),
      supportsFullCatalog: true,
    );
  }

  @override
  Future<void> markCatalogImported({
    required String version,
    required DateTime updatedAt,
  }) async {
    final database = await _db;
    await database.rawDelete('''
      DELETE FROM product_categories
      WHERE barcode IN (
        SELECT barcode FROM products
        WHERE catalog_version IS NOT NULL AND catalog_version != ?
      )
    ''', [version]);
    await database.delete(
      'products',
      where: 'catalog_version IS NOT NULL AND catalog_version != ?',
      whereArgs: [version],
    );
    final batch = database.batch();
    batch.insert(
      'metadata',
      {'key': 'catalog_version', 'value': version},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'metadata',
      {
        'key': 'catalog_updated_at',
        'value': updatedAt.toUtc().toIso8601String()
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await batch.commit(noResult: true);
  }

  Map<String, Object?> _rowFromProduct(
    ProductInfo product,
    int updatedAt, {
    String? catalogVersion,
  }) =>
      {
        'barcode': product.barcode,
        'name': product.name,
        'brand': product.brand,
        'ingredients': product.ingredients,
        'allergen_ids': jsonEncode(product.allergenIds.toList()),
        'trace_allergen_ids': jsonEncode(product.traceAllergenIds.toList()),
        'image_url': product.imageUrl,
        'data_source': product.dataSource,
        'completeness': product.completeness,
        'popularity': product.popularity,
        'allergen_data_complete': product.allergenDataComplete ? 1 : 0,
        'catalog_version': catalogVersion,
        'updated_at': updatedAt,
      };

  ProductInfo _productFromRow(
    Map<String, Object?> row,
    Map<String, Set<String>> categories,
  ) {
    Set<String> decodeSet(Object? value) =>
        (jsonDecode(value?.toString() ?? '[]') as List<dynamic>)
            .map((item) => item.toString())
            .toSet();

    final barcode = row['barcode']! as String;
    return ProductInfo(
      barcode: barcode,
      name: row['name']! as String,
      brand: row['brand']! as String,
      ingredients: row['ingredients']! as String,
      allergenIds: decodeSet(row['allergen_ids']),
      traceAllergenIds: decodeSet(row['trace_allergen_ids']),
      imageUrl: row['image_url'] as String?,
      dataSource: row['data_source']! as String,
      categoryIds: categories[barcode] ?? const {},
      completeness: (row['completeness']! as num).toDouble(),
      popularity: (row['popularity']! as num).toDouble(),
      allergenDataComplete: row['allergen_data_complete'] == 1,
    );
  }

  Future<Map<String, Set<String>>> _categoriesFor(
    Database database,
    List<String> barcodes,
  ) async {
    if (barcodes.isEmpty) return {};
    final placeholders = List.filled(barcodes.length, '?').join(',');
    final rows = await database.rawQuery(
      'SELECT barcode, category_id FROM product_categories '
      'WHERE barcode IN ($placeholders)',
      barcodes,
    );
    final result = <String, Set<String>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row['barcode']! as String, () => <String>{})
          .add(row['category_id']! as String);
    }
    return result;
  }
}
