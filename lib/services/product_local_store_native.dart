import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/offline_catalog.dart';
import '../models/product.dart';
import 'product_local_store.dart';
import 'product_name_matcher.dart';

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
      version: 3,
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
        category_id TEXT,
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
    if (!productColumns.any((column) => column['name'] == 'category_id')) {
      await database.execute(
        'ALTER TABLE products ADD COLUMN category_id TEXT',
      );
    }
    final legacyCategoryTable = await database.rawQuery('''
      SELECT name FROM sqlite_master
      WHERE type = 'table' AND name = 'product_categories'
    ''');
    if (legacyCategoryTable.isNotEmpty) {
      await database.execute('''
        UPDATE products
        SET category_id = (
          SELECT category_id
          FROM product_categories
          WHERE product_categories.barcode = products.barcode
          ORDER BY rowid DESC
          LIMIT 1
        )
        WHERE category_id IS NULL
      ''');
      await database.execute('DROP INDEX IF EXISTS category_lookup');
      await database.execute('DROP TABLE product_categories');
    }
    await database.execute('''
      CREATE INDEX IF NOT EXISTS category_lookup
      ON products(category_id, popularity)
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
    return _productFromRow(rows.first);
  }

  @override
  Future<List<ProductInfo>> searchByName(
    String name, {
    String brand = '',
    int limit = 40,
  }) async {
    final terms = productNameTerms(name)
      ..sort((first, second) => second.length.compareTo(first.length));
    if (terms.isEmpty) return const [];
    final database = await _db;
    final rows = await database.query(
      'products',
      where: 'LOWER(name) LIKE ?',
      whereArgs: ['%${terms.first}%'],
      orderBy: 'popularity DESC',
      limit: limit.clamp(10, 80),
    );
    return rows.map(_productFromRow).toList();
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
      SELECT p.*
      FROM products p
      WHERE p.category_id IN ($placeholders)
      ORDER BY p.popularity DESC, p.completeness DESC
      LIMIT ?
    ''', [...categoryIds, limit]);
    return rows.map(_productFromRow).toList();
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
    await database.execute('VACUUM');
    await database.execute('PRAGMA optimize');
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
        'category_id':
            product.categoryIds.isEmpty ? null : product.categoryIds.last,
        'catalog_version': catalogVersion,
        'updated_at': updatedAt,
      };

  ProductInfo _productFromRow(
    Map<String, Object?> row,
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
      categoryIds: row['category_id'] == null
          ? const {}
          : {row['category_id']! as String},
      completeness: (row['completeness']! as num).toDouble(),
      popularity: (row['popularity']! as num).toDouble(),
      allergenDataComplete: row['allergen_data_complete'] == 1,
    );
  }
}
