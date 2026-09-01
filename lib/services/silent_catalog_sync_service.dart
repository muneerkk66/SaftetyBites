import 'package:shared_preferences/shared_preferences.dart';

import '../models/offline_catalog.dart';
import 'product_repository.dart';

class SilentCatalogSyncService {
  SilentCatalogSyncService({
    Future<OfflineCatalogStats> Function()? loadStats,
    Future<int> Function()? bootstrapCatalog,
    Future<int> Function()? syncCatalog,
    Future<SharedPreferences> Function()? loadPreferences,
    DateTime Function()? now,
  })  : _loadStats = loadStats ?? ProductRepository.instance.catalogStats,
        _bootstrapCatalog = bootstrapCatalog ??
            ProductRepository.instance.bootstrapBundledCatalog,
        _syncCatalog =
            syncCatalog ?? ProductRepository.instance.syncOfflineCatalog,
        _loadPreferences = loadPreferences ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now;

  static final instance = SilentCatalogSyncService();
  static const _lastSuccessKey = 'offline_catalog_last_sync_success_v1';

  final Future<OfflineCatalogStats> Function() _loadStats;
  final Future<int> Function() _bootstrapCatalog;
  final Future<int> Function() _syncCatalog;
  final Future<SharedPreferences> Function() _loadPreferences;
  final DateTime Function() _now;

  Future<bool> syncIfDue({
    Duration minimumInterval = const Duration(hours: 24),
  }) async {
    try {
      final stats = await _loadStats();
      if (!stats.supportsFullCatalog) return false;
      try {
        await _bootstrapCatalog();
      } catch (_) {}
      final preferences = await _loadPreferences();
      final now = _now().toUtc();
      final lastSuccess = DateTime.tryParse(
        preferences.getString(_lastSuccessKey) ?? '',
      );
      if (lastSuccess != null &&
          now.difference(lastSuccess.toUtc()) < minimumInterval) {
        return false;
      }
      await _syncCatalog();
      await preferences.setString(_lastSuccessKey, now.toIso8601String());
      return true;
    } catch (_) {
      return false;
    }
  }
}
