import 'package:flutter/material.dart';

import 'core/app_session.dart';
import 'core/app_theme.dart';
import 'core/auth_controller.dart';
import 'screens/auth/account_access_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/onboarding/intro_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

class SafeBiteAIApp extends StatelessWidget {
  const SafeBiteAIApp({
    super.key,
    required this.session,
    required this.auth,
  });

  final AppSession session;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeBiteAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          if (!session.introComplete) {
            return IntroScreen(session: session);
          }
          if (!session.accountGateComplete) {
            return AccountAccessScreen(
              auth: auth,
              onComplete: session.completeAccountGate,
            );
          }
          if (!session.onboardingComplete) {
            return OnboardingScreen(session: session, auth: auth);
          }
          return HomeShell(session: session, auth: auth);
        },
      ),
    );
  }
}
