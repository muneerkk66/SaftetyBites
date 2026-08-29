import 'package:flutter_test/flutter_test.dart';
import 'package:safebite/core/app_session.dart';
import 'package:safebite/models/family_member.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists selected stores and search radius', () async {
    SharedPreferences.setMockInitialValues({});
    final session = await AppSession.load();

    await session.completeOnboarding(
      postcode: 'SW1A 1AA',
      latitude: 51.50101,
      longitude: -0.141563,
      storeRadiusMiles: 10,
      stores: {'Tesco', 'Aldi'},
      primaryMember: const FamilyMember(
        id: 'primary',
        name: 'Muneer',
        relationship: 'You',
        allergenIds: {},
      ),
      healthDataConsent: false,
    );
    await session.updateStorePreferences(
      stores: {'Tesco'},
      radiusMiles: 20,
    );

    final restored = await AppSession.load();
    expect(restored.selectedStores, {'Tesco'});
    expect(restored.storeRadiusMiles, 20);
    expect(restored.healthDataConsent, isFalse);
  });

  test('persists explicit health data consent', () async {
    SharedPreferences.setMockInitialValues({});
    final session = await AppSession.load();

    await session.recordHealthDataConsent();

    final restored = await AppSession.load();
    expect(restored.healthDataConsent, isTrue);
  });
}
