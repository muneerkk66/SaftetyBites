import 'package:flutter_test/flutter_test.dart';
import 'package:safebite/models/offline_catalog.dart';
import 'package:safebite/services/silent_catalog_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('silently syncs a supported mobile catalogue when due', () async {
    var syncCalls = 0;
    final service = SilentCatalogSyncService(
      loadStats: () async => const OfflineCatalogStats(
        productCount: 0,
        supportsFullCatalog: true,
      ),
      bootstrapCatalog: () async => 0,
      syncCatalog: () async {
        syncCalls++;
        return 20;
      },
      now: () => DateTime.utc(2026, 8, 26, 10),
    );

    expect(await service.syncIfDue(), isTrue);
    expect(syncCalls, 1);
  });

  test('does not sync again inside the minimum interval', () async {
    SharedPreferences.setMockInitialValues({
      'offline_catalog_last_sync_success_v1':
          DateTime.utc(2026, 8, 26, 9).toIso8601String(),
    });
    var syncCalls = 0;
    final service = SilentCatalogSyncService(
      loadStats: () async => const OfflineCatalogStats(
        productCount: 10,
        supportsFullCatalog: true,
      ),
      bootstrapCatalog: () async => 0,
      syncCatalog: () async {
        syncCalls++;
        return 0;
      },
      now: () => DateTime.utc(2026, 8, 26, 10),
    );

    expect(await service.syncIfDue(), isFalse);
    expect(syncCalls, 0);
  });

  test('retries after a failed catalogue sync', () async {
    var syncCalls = 0;
    final service = SilentCatalogSyncService(
      loadStats: () async => const OfflineCatalogStats(
        productCount: 0,
        supportsFullCatalog: true,
      ),
      bootstrapCatalog: () async => 0,
      syncCatalog: () async {
        syncCalls++;
        if (syncCalls == 1) throw Exception('temporary failure');
        return 20;
      },
      now: () => DateTime.utc(2026, 8, 26, 10),
    );

    expect(await service.syncIfDue(), isFalse);
    expect(await service.syncIfDue(), isTrue);
    expect(syncCalls, 2);
  });

  test('does not download a full catalogue on web', () async {
    var syncCalls = 0;
    final service = SilentCatalogSyncService(
      loadStats: () async => const OfflineCatalogStats(
        productCount: 3,
        supportsFullCatalog: false,
      ),
      bootstrapCatalog: () async => 0,
      syncCatalog: () async {
        syncCalls++;
        return 0;
      },
    );

    expect(await service.syncIfDue(), isFalse);
    expect(syncCalls, 0);
  });
}
