import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/family_member.dart';
import '../models/product.dart';

class AppSession extends ChangeNotifier {
  AppSession._({
    required SharedPreferences preferences,
    required this.accountGateComplete,
    required this.onboardingComplete,
    required this.postcode,
    required this.selectedStores,
    required this.family,
  }) : _preferences = preferences;

  static const _onboardingKey = 'onboarding_complete';
  static const _accountGateKey = 'account_gate_complete';
  static const _postcodeKey = 'postcode';
  static const _storesKey = 'selected_stores';
  static const _familyKey = 'family';

  final SharedPreferences _preferences;

  bool accountGateComplete;
  bool onboardingComplete;
  String postcode;
  Set<String> selectedStores;
  List<FamilyMember> family;
  bool debugRecallEnabled = false;
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
      accountGateComplete: preferences.getBool(_accountGateKey) ?? false,
      onboardingComplete: preferences.getBool(_onboardingKey) ?? false,
      postcode: preferences.getString(_postcodeKey) ?? '',
      selectedStores: Set<String>.from(
        preferences.getStringList(_storesKey) ?? <String>[],
      ),
      family: family,
    );
  }

  Future<void> completeAccountGate() async {
    accountGateComplete = true;
    await _preferences.setBool(_accountGateKey, true);
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String postcode,
    required Set<String> stores,
    required FamilyMember primaryMember,
  }) async {
    this.postcode = postcode.trim().toUpperCase();
    selectedStores = stores;
    family = [primaryMember];
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

  void saveCheckedProduct(ProductInfo product) {
    recentlyChecked.removeWhere((item) => item.barcode == product.barcode);
    recentlyChecked.insert(0, product);
    if (recentlyChecked.length > 10) recentlyChecked.removeLast();
    notifyListeners();
  }

  void setDebugRecallEnabled(bool enabled) {
    debugRecallEnabled = enabled;
    notifyListeners();
  }

  Future<void> resetPrototype() async {
    onboardingComplete = false;
    accountGateComplete = false;
    postcode = '';
    selectedStores = {};
    family = [];
    debugRecallEnabled = false;
    recentlyChecked.clear();
    await _preferences.clear();
    notifyListeners();
  }

  Future<void> _persist() async {
    await Future.wait([
      _preferences.setBool(_onboardingKey, onboardingComplete),
      _preferences.setString(_postcodeKey, postcode),
      _preferences.setStringList(_storesKey, selectedStores.toList()),
      _persistFamily(),
    ]);
  }

  Future<void> _persistFamily() {
    return _preferences.setString(
      _familyKey,
      jsonEncode(family.map((member) => member.toJson()).toList()),
    );
  }
}
