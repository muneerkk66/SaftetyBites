import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_session.dart';

enum RecallNotificationStatus {
  unavailable,
  notRequested,
  enabled,
  denied,
}

class RecallNotificationService extends ChangeNotifier {
  RecallNotificationService._();

  static final instance = RecallNotificationService._();
  static const _topicsKey = 'recall_notification_topics_v1';
  static const _subscriptionTokenKey = 'recall_subscription_token_v1';
  static const _installationIdKey = 'recall_installation_id_v1';
  static const _registrationFingerprintKey =
      'recall_registration_fingerprint_v2';
  static const _registrationSyncedAtKey = 'recall_registration_synced_at_v2';
  static const _unreadAlertIdsKey = 'unread_recall_alert_ids_v1';
  static const _unmatchedUnreadKey = 'unmatched_recall_notification_v1';
  static const _badgeChannel = MethodChannel('com.necsca.safebitesapp/badge');
  static const _messagingTimeout = Duration(seconds: 8);
  static const _registrationTimeout = Duration(seconds: 15);
  static const _registrationRefreshInterval = Duration(hours: 24);
  static const _retailerSlugs = <String, String>{
    'Tesco': 'tesco',
    'Aldi': 'aldi',
    'Asda': 'asda',
    'Sainsbury’s': 'sainsburys',
    'Lidl': 'lidl',
    'Morrisons': 'morrisons',
    'Waitrose': 'waitrose',
    'Iceland': 'iceland',
    'Co-op': 'coop',
    'M&S': 'marks_spencer',
  };

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  bool _initialized = false;
  final Set<String> _unreadAlertIds = {};
  bool _hasUnmatchedUnread = false;
  bool _unreadStateLoaded = false;
  VoidCallback? _onNotificationOpened;

  bool get hasUnread => _unreadAlertIds.isNotEmpty || _hasUnmatchedUnread;

  int get unreadCount => _unreadAlertIds.length + (_hasUnmatchedUnread ? 1 : 0);

  bool isAlertUnread(String alertId) => _unreadAlertIds.contains(alertId);

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west2');

  Future<void> initialize({
    required AppSession session,
    required VoidCallback onNotificationOpened,
  }) async {
    if (!isSupported) return;
    _onNotificationOpened = onNotificationOpened;
    await _loadUnreadState();
    if (!_initialized) {
      try {
        _badgeChannel.setMethodCallHandler(_handleNativeBadgeCall);
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await FirebaseMessaging.instance
              .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
        _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
          unawaited(_recordUnread(message));
        });
        _openedSubscription =
            FirebaseMessaging.onMessageOpenedApp.listen((message) {
          unawaited(_recordUnread(message));
          _onNotificationOpened?.call();
        });
        _tokenSubscription =
            FirebaseMessaging.instance.onTokenRefresh.listen((_) {
          unawaited(syncPreferences(session));
        });
        _initialized = true;
        await _consumePendingNativeNotification();
        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          await _recordUnread(initialMessage);
          _onNotificationOpened?.call();
        } else {
          await refreshUnreadState();
        }
      } catch (_) {
        await _foregroundSubscription?.cancel();
        await _openedSubscription?.cancel();
        await _tokenSubscription?.cancel();
        _foregroundSubscription = null;
        _openedSubscription = null;
        _tokenSubscription = null;
        _initialized = false;
        return;
      }
    }
    await syncPreferences(session);
  }

  Future<RecallNotificationStatus> status() async {
    if (!isSupported) return RecallNotificationStatus.unavailable;
    final settings = await FirebaseMessaging.instance
        .getNotificationSettings()
        .timeout(_messagingTimeout);
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        RecallNotificationStatus.enabled,
      AuthorizationStatus.denied => RecallNotificationStatus.denied,
      _ => RecallNotificationStatus.notRequested,
    };
  }

  Future<RecallNotificationStatus> requestAndSync(AppSession session) async {
    if (!isSupported) return RecallNotificationStatus.unavailable;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await syncPreferences(session);
      return RecallNotificationStatus.enabled;
    }
    return RecallNotificationStatus.denied;
  }

  Future<void> syncPreferences(AppSession session) async {
    if (!isSupported) return;
    final notificationStatus = await status();
    if (notificationStatus != RecallNotificationStatus.enabled) {
      return;
    }
    final messagingToken = await _messagingToken();
    if (messagingToken == null) return;

    final preferences = await SharedPreferences.getInstance();
    await _removeLegacyTopicSubscriptions(preferences);
    final retailerIds = <String>{};
    for (final store in session.selectedStores) {
      final slug = _retailerSlugs[store];
      if (slug != null) retailerIds.add(slug);
    }
    final sortedRetailerIds = retailerIds.toList()..sort();
    final fingerprint = sha256
        .convert(utf8.encode('$messagingToken\n${sortedRetailerIds.join(',')}'))
        .toString();
    final previousFingerprint =
        preferences.getString(_registrationFingerprintKey);
    final syncedAtMilliseconds =
        preferences.getInt(_registrationSyncedAtKey) ?? 0;
    final lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(
      syncedAtMilliseconds,
      isUtc: true,
    );
    final registrationIsFresh = previousFingerprint == fingerprint &&
        DateTime.now().toUtc().difference(lastSyncedAt) <
            _registrationRefreshInterval;
    if (registrationIsFresh) return;

    final installationId = await _installationId(preferences);
    try {
      final callable = _functions.httpsCallable(
        'syncRecallInstallation',
        options: HttpsCallableOptions(timeout: _registrationTimeout),
      );
      await callable.call<dynamic>({
        'installationId': installationId,
        'token': messagingToken,
        'retailerIds': sortedRetailerIds,
        'platform':
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      await Future.wait([
        preferences.setString(_registrationFingerprintKey, fingerprint),
        preferences.setInt(
          _registrationSyncedAtKey,
          DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      ]);
    } catch (_) {
      return;
    }
  }

  Future<void> unregisterAndClear() async {
    final preferences = await SharedPreferences.getInstance();
    final installationId =
        preferences.getString(_installationIdKey)?.trim().toLowerCase() ?? '';
    if (RegExp(r'^[a-f0-9]{32}$').hasMatch(installationId)) {
      try {
        final callable = _functions.httpsCallable(
          'deleteRecallInstallation',
          options: HttpsCallableOptions(timeout: _registrationTimeout),
        );
        await callable.call<dynamic>({'installationId': installationId});
      } catch (_) {}
    }

    if (isSupported) {
      try {
        await FirebaseMessaging.instance
            .deleteToken()
            .timeout(_messagingTimeout);
      } catch (_) {}
    }

    _unreadAlertIds.clear();
    _hasUnmatchedUnread = false;
    await Future.wait([
      preferences.remove(_installationIdKey),
      preferences.remove(_registrationFingerprintKey),
      preferences.remove(_registrationSyncedAtKey),
      preferences.remove(_unreadAlertIdsKey),
      preferences.remove(_unmatchedUnreadKey),
    ]);
    await _syncNativeBadge();
    notifyListeners();
  }

  Future<void> _removeLegacyTopicSubscriptions(
    SharedPreferences preferences,
  ) async {
    final topics = preferences.getStringList(_topicsKey) ?? const [];
    for (final topic in topics) {
      try {
        await FirebaseMessaging.instance
            .unsubscribeFromTopic(topic)
            .timeout(_messagingTimeout);
      } catch (_) {
        continue;
      }
    }
    if (topics.isNotEmpty || preferences.containsKey(_subscriptionTokenKey)) {
      await Future.wait([
        preferences.remove(_topicsKey),
        preferences.remove(_subscriptionTokenKey),
      ]);
    }
  }

  Future<String> _installationId(SharedPreferences preferences) async {
    final existing = preferences.getString(_installationIdKey)?.trim() ?? '';
    if (RegExp(r'^[a-f0-9]{32}$').hasMatch(existing)) return existing;
    final random = Random.secure();
    final identifier = List<int>.generate(16, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    await preferences.setString(_installationIdKey, identifier);
    return identifier;
  }

  Future<void> refreshUnreadState() async {
    if (!isSupported) return;
    await _loadUnreadState();
    await _consumePendingNativeNotification();
    try {
      final nativeUnread =
          await _badgeChannel.invokeMethod<bool>('hasUnread') ?? false;
      if (nativeUnread && !hasUnread) {
        _hasUnmatchedUnread = true;
        await _persistUnreadState();
        notifyListeners();
      } else if (!nativeUnread && hasUnread) {
        await _badgeChannel.invokeMethod<void>('markUnread');
      }
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  Future<void> markAlertsRead() async {
    final changed = hasUnread;
    _unreadAlertIds.clear();
    _hasUnmatchedUnread = false;
    await _persistUnreadState();
    await _syncNativeBadge();
    if (changed) notifyListeners();
  }

  Future<void> markAlertRead(String alertId) async {
    if (!_unreadAlertIds.remove(alertId)) return;
    await _persistUnreadState();
    await _syncNativeBadge();
    notifyListeners();
  }

  Future<void> resolveUnmatchedAlert(Iterable<String> visibleAlertIds) async {
    if (!_hasUnmatchedUnread) return;
    String? alertId;
    for (final candidate in visibleAlertIds) {
      if (candidate.isNotEmpty) {
        alertId = candidate;
        break;
      }
    }
    if (alertId == null) return;
    _hasUnmatchedUnread = false;
    _unreadAlertIds.add(alertId);
    await _persistUnreadState();
    notifyListeners();
  }

  Future<void> _recordUnread(RemoteMessage message) async {
    await _recordUnreadAlertId(message.data['alertId']?.trim());
  }

  Future<void> _recordUnreadAlertId(String? alertId) async {
    final wasUnread = hasUnread;
    final normalizedAlertId = alertId?.trim() ?? '';
    if (normalizedAlertId.isEmpty) {
      _hasUnmatchedUnread = true;
    } else {
      _unreadAlertIds.add(normalizedAlertId);
    }
    await _persistUnreadState();
    await _syncNativeBadge();
    if (!wasUnread || normalizedAlertId.isNotEmpty) notifyListeners();
  }

  Future<void> _consumePendingNativeNotification() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final payload = await _badgeChannel.invokeMapMethod<String, dynamic>(
        'consumePendingNotification',
      );
      if (payload == null) return;
      await _recordUnreadAlertId(payload['alertId']?.toString());
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  Future<dynamic> _handleNativeBadgeCall(MethodCall call) async {
    if (call.method != 'notificationReceived') return null;
    final arguments = call.arguments;
    if (arguments is Map) {
      await _recordUnreadAlertId(arguments['alertId']?.toString());
    } else {
      await _recordUnreadAlertId(null);
    }
    return null;
  }

  Future<void> _loadUnreadState() async {
    if (_unreadStateLoaded) return;
    final preferences = await SharedPreferences.getInstance();
    _unreadAlertIds.addAll(
      preferences.getStringList(_unreadAlertIdsKey) ?? const [],
    );
    _hasUnmatchedUnread = preferences.getBool(_unmatchedUnreadKey) ?? false;
    _unreadStateLoaded = true;
    if (hasUnread) notifyListeners();
  }

  Future<void> _persistUnreadState() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setStringList(
        _unreadAlertIdsKey,
        _unreadAlertIds.toList()..sort(),
      ),
      preferences.setBool(_unmatchedUnreadKey, _hasUnmatchedUnread),
    ]);
  }

  Future<void> _syncNativeBadge() async {
    if (!isSupported) return;
    try {
      await _badgeChannel.invokeMethod<void>(
        hasUnread ? 'markUnread' : 'clearUnread',
      );
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  Future<String?> _messagingToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (var attempt = 0; attempt < 8; attempt++) {
        final token = await FirebaseMessaging.instance
            .getAPNSToken()
            .timeout(_messagingTimeout, onTimeout: () => null)
            .onError((_, __) => null);
        if (token != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      final token = await FirebaseMessaging.instance
          .getAPNSToken()
          .timeout(_messagingTimeout, onTimeout: () => null)
          .onError((_, __) => null);
      if (token == null) return null;
    }
    return FirebaseMessaging.instance
        .getToken()
        .timeout(_messagingTimeout, onTimeout: () => null)
        .onError((_, __) => null);
  }

  @override
  void dispose() {
    _badgeChannel.setMethodCallHandler(null);
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.dispose();
  }
}
