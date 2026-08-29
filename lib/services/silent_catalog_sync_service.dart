import 'package:shared_preferences/shared_preferences.dart';

import '../models/offline_catalog.dart';
import 'product_repository.dart';

class SilentCatalogSyncService {
  SilentCatalogSyncService({
    Future<OfflineCatalogStats> Function()? loadStats,
    Future<int> Function()? syncCatalog,
    Future<SharedPreferences> Function()? loadPreferences,
    DateTime Function()? now,
  })  : _loadStats = loadStats ?? ProductRepository.instance.catalogStats,
        _syncCatalog =
            syncCatalog ?? ProductRepository.instance.syncOfflineCatalog,
        _loadPreferences = loadPreferences ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now;

  static final instance = SilentCatalogSyncService();
  static const _lastAttemptKey = 'offline_catalog_last_sync_attempt_v1';

  final Future<OfflineCatalogStats> Function() _loadStats;
  final Future<int> Function() _syncCatalog;
  final Future<SharedPreferences> Function() _loadPreferences;
  final DateTime Function() _now;

  Future<bool> syncIfDue({
    Duration minimumInterval = const Duration(hours: 24),
  }) async {
    try {
      final stats = await _loadStats();
      if (!stats.supportsFullCatalog) return false;
      final preferences = await _loadPreferences();
      final now = _now().toUtc();
      final lastAttempt = DateTime.tryParse(
        preferences.getString(_lastAttemptKey) ?? '',
      );
      if (lastAttempt != null &&
          now.difference(lastAttempt.toUtc()) < minimumInterval) {
        return false;
      }
      await preferences.setString(_lastAttemptKey, now.toIso8601String());
      await _syncCatalog();
      return true;
    } catch (_) {
      return false;
    }
  }
}
