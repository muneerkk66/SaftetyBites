import 'package:flutter_test/flutter_test.dart';
import 'package:safebite/core/app_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists intro completion independently', () async {
    SharedPreferences.setMockInitialValues({});
    final session = await AppSession.load();

    expect(session.introComplete, isFalse);
    await session.completeIntro();

    final restored = await AppSession.load();
    expect(restored.introComplete, isTrue);
    expect(restored.onboardingComplete, isFalse);
  });
}
