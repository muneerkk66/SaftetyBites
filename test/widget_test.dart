import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safebite/app.dart';
import 'package:safebite/core/app_session.dart';
import 'package:safebite/core/auth_controller.dart';

void main() {
  testWidgets('shows the product introduction before account access',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final session = await AppSession.load();
    final auth = AuthController.guest();

    await tester.pumpWidget(SafeBiteAIApp(session: session, auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('SafeBiteAI'), findsOneWidget);
    expect(find.text('Know before\nyou bite.'), findsOneWidget);
    expect(find.text('See how SafeBiteAI protects you'), findsOneWidget);

    await tester.tap(find.text('See how SafeBiteAI protects you'));
    await tester.pumpAndSettle();

    expect(find.text('Set up your protection'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Account access is unavailable.'), findsOneWidget);

    final guestButton = find.text('Continue without an account');
    await tester.ensureVisible(guestButton);
    await tester.tap(guestButton);
    await tester.pumpAndSettle();

    expect(find.text('Where do you shop?'), findsOneWidget);
  });
}
