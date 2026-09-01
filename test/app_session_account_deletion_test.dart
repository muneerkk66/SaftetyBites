import 'package:flutter_test/flutter_test.dart';
import 'package:safebite/core/app_session.dart';
import 'package:safebite/models/family_member.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('account deletion reset clears local household data', () async {
    SharedPreferences.setMockInitialValues({});
    final session = await AppSession.load();
    await session.completeIntro();
    await session.completeAccountGate();
    await session.completeOnboarding(
      postcode: 'SW1A 1AA',
      latitude: 51.50101,
      longitude: -0.141563,
      storeRadiusMiles: 10,
      stores: {'Tesco'},
      primaryMember: const FamilyMember(
        id: 'primary',
        name: 'Test user',
        relationship: 'You',
        allergenIds: {'milk'},
      ),
      healthDataConsent: true,
    );

    await session.resetPrototype();

    final restored = await AppSession.load();
    expect(restored.introComplete, isFalse);
    expect(restored.accountGateComplete, isFalse);
    expect(restored.onboardingComplete, isFalse);
    expect(restored.postcode, isEmpty);
    expect(restored.latitude, isNull);
    expect(restored.longitude, isNull);
    expect(restored.selectedStores, isEmpty);
    expect(restored.family, isEmpty);
    expect(restored.healthDataConsent, isFalse);
  });
}
