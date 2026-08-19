import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safebite/app.dart';
import 'package:safebite/core/app_session.dart';
import 'package:safebite/core/auth_controller.dart';

void main() {
  testWidgets('shows the family-first onboarding', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final session = await AppSession.load();
    final auth = AuthController.guest();

    await tester.pumpWidget(SafeBiteApp(session: session, auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('SafeBite'), findsOneWidget);
    expect(find.text('Account access is unavailable.'), findsOneWidget);

    final guestButton = find.text('Continue without an account');
    await tester.ensureVisible(guestButton);
    await tester.tap(guestButton);
    await tester.pumpAndSettle();

    expect(find.text('Love the food.\nLose the worry.'), findsOneWidget);
    expect(find.text('Set up my household'), findsOneWidget);
  });
}
