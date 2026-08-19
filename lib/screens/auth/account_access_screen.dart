import 'dart:async';

import 'package:firebase_ui_auth/firebase_ui_auth.dart' hide AuthController;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../widgets/brand_mark.dart';

class AccountAccessScreen extends StatelessWidget {
  const AccountAccessScreen({
    super.key,
    required this.auth,
    required this.onComplete,
    this.allowGuest = true,
  });

  final AuthController auth;
  final Future<void> Function() onComplete;
  final bool allowGuest;

  @override
  Widget build(BuildContext context) {
    if (!auth.isConfigured) {
      return _FirebaseUnavailable(
        message: auth.configurationMessage,
        allowGuest: allowGuest,
        onComplete: onComplete,
      );
    }

    return SignInScreen(
      providers: [
        EmailAuthProvider(),
        GoogleProvider(
          clientId:
              '491951991132-hn7nv1mdc3jfsosjkf8t5m9c5h1ql59a.apps.googleusercontent.com',
          iOSPreferPlist: true,
        ),
      ],
      showAuthActionSwitch: true,
      showPasswordVisibilityToggle: true,
      headerMaxExtent: 280,
      headerBuilder: (context, constraints, shrinkOffset) {
        return const _AccountHero(compact: true);
      },
      sideBuilder: (context, constraints) {
        return const _AccountHero();
      },
      styles: const {
        EmailFormStyle(signInButtonVariant: ButtonVariant.filled),
      },
      subtitleBuilder: (context, action) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            action == AuthAction.signUp
                ? 'Create an account to protect your household.'
                : 'Welcome back to SafeBite.',
          ),
        );
      },
      footerBuilder: allowGuest
          ? (context, action) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: onComplete,
                  child: const Text('Continue without an account'),
                ),
              );
            }
          : null,
      actions: [
        AuthStateChangeAction<SignedIn>((context, state) {
          unawaited(onComplete());
        }),
        AuthStateChangeAction<UserCreated>((context, state) {
          unawaited(onComplete());
        }),
      ],
    );
  }
}

class _FirebaseUnavailable extends StatelessWidget {
  const _FirebaseUnavailable({
    required this.message,
    required this.allowGuest,
    required this.onComplete,
  });

  final String? message;
  final bool allowGuest;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.acid,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandMark(),
                      const SizedBox(height: 24),
                      Text(
                        'Account access is unavailable.',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message ?? 'Please try again later.',
                        textAlign: TextAlign.center,
                      ),
                      if (allowGuest) ...[
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: onComplete,
                          child: const Text('Continue without an account'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 220 : 360),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/safebite-grocery-hero-v1.png'),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppColors.greenDark.withOpacity(0.96),
              AppColors.greenDark.withOpacity(0.66),
              Colors.transparent,
            ],
          ),
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            'Know what’s inside.\nBefore it’s inside.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.acid,
                  fontSize: compact ? 30 : 42,
                  height: 0.98,
                ),
          ),
        ),
      ),
    );
  }
}
