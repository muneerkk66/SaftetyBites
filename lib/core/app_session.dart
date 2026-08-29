import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/family_member.dart';
import '../models/product.dart';

class AppSession extends ChangeNotifier {
  AppSession._({
    required SharedPreferences preferences,
    required this.introComplete,
    required this.accountGateComplete,
    required this.onboardingComplete,
    required this.postcode,
    required this.latitude,
    required this.longitude,
    required this.storeRadiusMiles,
    required this.selectedStores,
    required this.family,
    required this.healthDataConsent,
  }) : _preferences = preferences;

  static const _onboardingKey = 'onboarding_complete';
  static const _introKey = 'intro_complete_v1';
  static const _accountGateKey = 'account_gate_complete';
  static const _postcodeKey = 'postcode';
  static const _latitudeKey = 'latitude';
  static const _longitudeKey = 'longitude';
  static const _storeRadiusKey = 'store_radius_miles';
  static const _storesKey = 'selected_stores';
  static const _familyKey = 'family';
  static const _healthDataConsentKey = 'health_data_consent_v1';

  final SharedPreferences _preferences;

  bool introComplete;
  bool accountGateComplete;
  bool onboardingComplete;
  String postcode;
  double? latitude;
  double? longitude;
  double storeRadiusMiles;
  Set<String> selectedStores;
  List<FamilyMember> family;
  bool healthDataConsent;
  final List<ProductInfo> recentlyChecked = [];

  static Future<AppSession> load() async {
    final preferences = await SharedPreferences.getInstance();
    final rawFamily = preferences.getString(_familyKey);
    final family = rawFamily == null
        ? <FamilyMember>[]
        : (jsonDecode(rawFamily) as List<dynamic>)
            .map((item) => FamilyMember.fromJson(item as Map<String, dynamic>))
            .toList();

    return AppSession._(
      preferences: preferences,
      introComplete: preferences.getBool(_introKey) ?? false,
      accountGateComplete: preferences.getBool(_accountGateKey) ?? false,
      onboardingComplete: preferences.getBool(_onboardingKey) ?? false,
      postcode: preferences.getString(_postcodeKey) ?? '',
      latitude: preferences.getDouble(_latitudeKey),
      longitude: preferences.getDouble(_longitudeKey),
      storeRadiusMiles: preferences.getDouble(_storeRadiusKey) ?? 5,
      selectedStores: Set<String>.from(
        preferences.getStringList(_storesKey) ?? <String>[],
      ),
      family: family,
      healthDataConsent: preferences.getBool(_healthDataConsentKey) ?? false,
    );
  }

  Future<void> completeIntro() async {
    introComplete = true;
    await _preferences.setBool(_introKey, true);
    notifyListeners();
  }

  Future<void> completeAccountGate() async {
    accountGateComplete = true;
    await _preferences.setBool(_accountGateKey, true);
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String postcode,
    required double? latitude,
    required double? longitude,
    required double storeRadiusMiles,
    required Set<String> stores,
    required FamilyMember primaryMember,
    required bool healthDataConsent,
  }) async {
    this.postcode = postcode.trim().toUpperCase();
    this.latitude = latitude;
    this.longitude = longitude;
    this.storeRadiusMiles = storeRadiusMiles;
    selectedStores = stores;
    family = [primaryMember];
    this.healthDataConsent = healthDataConsent;
    onboardingComplete = true;
    await _persist();
    notifyListeners();
  }

  Future<void> addFamilyMember(FamilyMember member) async {
    family = [...family, member];
    await _persistFamily();
    notifyListeners();
  }

  Future<void> updateFamilyMember(FamilyMember member) async {
    family =
        family.map((item) => item.id == member.id ? member : item).toList();
    await _persistFamily();
    notifyListeners();
  }

  Future<void> removeFamilyMember(String id) async {
    family = family.where((member) => member.id != id).toList();
    await _persistFamily();
    notifyListeners();
  }

  Future<void> recordHealthDataConsent() async {
    healthDataConsent = true;
    await _preferences.setBool(_healthDataConsentKey, true);
    notifyListeners();
  }

  void saveCheckedProduct(ProductInfo product) {
    recentlyChecked.removeWhere((item) => item.barcode == product.barcode);
    recentlyChecked.insert(0, product);
    if (recentlyChecked.length > 10) recentlyChecked.removeLast();
    notifyListeners();
  }

  bool get hasLocation => latitude != null && longitude != null;

  String get locationLabel => postcode.isEmpty ? 'Current area' : postcode;

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    String? postcode,
  }) async {
    this.latitude = latitude;
    this.longitude = longitude;
    if (postcode != null && postcode.trim().isNotEmpty) {
      this.postcode = postcode.trim().toUpperCase();
    }
    await _persistLocation();
    notifyListeners();
  }

  Future<void> updateStorePreferences({
    required Set<String> stores,
    required double radiusMiles,
  }) async {
    selectedStores = Set<String>.from(stores);
    storeRadiusMiles = radiusMiles;
    await Future.wait([
      _preferences.setStringList(_storesKey, selectedStores.toList()),
      _preferences.setDouble(_storeRadiusKey, storeRadiusMiles),
    ]);
    notifyListeners();
  }

  Future<void> resetPrototype() async {
    introComplete = false;
    onboardingComplete = false;
    accountGateComplete = false;
    postcode = '';
    latitude = null;
    longitude = null;
    storeRadiusMiles = 5;
    selectedStores = {};
    family = [];
    healthDataConsent = false;
    recentlyChecked.clear();
    await _preferences.clear();
    notifyListeners();
  }

  Future<void> _persist() async {
    await Future.wait([
      _preferences.setBool(_onboardingKey, onboardingComplete),
      _preferences.setString(_postcodeKey, postcode),
      _preferences.setStringList(_storesKey, selectedStores.toList()),
      _preferences.setDouble(_storeRadiusKey, storeRadiusMiles),
      _persistFamily(),
      _preferences.setBool(_healthDataConsentKey, healthDataConsent),
      latitude == null
          ? _preferences.remove(_latitudeKey)
          : _preferences.setDouble(_latitudeKey, latitude!),
      longitude == null
          ? _preferences.remove(_longitudeKey)
          : _preferences.setDouble(_longitudeKey, longitude!),
    ]);
  }

  Future<void> _persistLocation() async {
    await Future.wait([
      _preferences.setString(_postcodeKey, postcode),
      _preferences.setDouble(_latitudeKey, latitude!),
      _preferences.setDouble(_longitudeKey, longitude!),
    ]);
  }

  Future<void> _persistFamily() {
    return _preferences.setString(
      _familyKey,
      jsonEncode(family.map((member) => member.toJson()).toList()),
    );
  }
}
