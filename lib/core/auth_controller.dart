import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class AuthController extends ChangeNotifier {
  AuthController._();

  factory AuthController.guest({String? message}) {
    return AuthController._()
      ..configurationMessage =
          message ?? 'Account login is not configured on this platform.';
  }

  FirebaseAuth? _auth;
  StreamSubscription<User?>? _subscription;
  User? user;
  bool isConfigured = false;
  String? configurationMessage;

  bool get isSignedIn => user != null;

  String get greetingName {
    final firebaseName = user?.displayName?.trim() ?? '';
    if (firebaseName.isNotEmpty) {
      return firebaseName.split(RegExp(r'\s+')).first;
    }

    final emailName = user?.email?.split('@').first.trim() ?? '';
    if (emailName.isEmpty) return '';
    final readable = emailName.replaceAll(RegExp(r'[._-]+'), ' ');
    return readable
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static Future<AuthController> load() async {
    final controller = AuthController._();
    try {
      await Firebase.initializeApp(
        options: kIsWeb ? DefaultFirebaseOptions.web : null,
      );
      controller._auth = FirebaseAuth.instance;
      controller.user = controller._auth!.currentUser;
      controller.isConfigured = true;
      controller._subscription =
          controller._auth!.authStateChanges().listen((user) {
        controller.user = user;
        controller.notifyListeners();
      });
    } catch (_) {
      controller.configurationMessage =
          'Firebase could not be started. Continue as a guest and try again later.';
    }
    return controller;
  }

  Future<void> signOut() async {
    if (_auth == null) return;
    await _auth!.signOut();
  }

  Future<void> deleteAccount({
    Future<void> Function()? beforeDelete,
  }) async {
    final auth = _auth;
    final currentUser = auth?.currentUser;
    if (auth == null || currentUser == null) {
      throw const AccountDeletionException(
        'Sign in before deleting your account.',
      );
    }

    try {
      final provider = _deletionProvider(currentUser);
      UserCredential? credential;
      if (provider != null) {
        credential = kIsWeb
            ? await currentUser.reauthenticateWithPopup(provider)
            : await currentUser.reauthenticateWithProvider(provider);
      }

      await beforeDelete?.call();

      if (!kIsWeb && provider?.providerId == AppleAuthProvider.PROVIDER_ID) {
        final authorizationCode =
            credential?.additionalUserInfo?.authorizationCode?.trim() ?? '';
        if (authorizationCode.isNotEmpty &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS)) {
          await auth.revokeTokenWithAuthorizationCode(authorizationCode);
        }
      }

      await currentUser.delete();
    } on FirebaseAuthException catch (error) {
      throw AccountDeletionException(_deletionMessage(error));
    } on AccountDeletionException {
      rethrow;
    } catch (_) {
      throw const AccountDeletionException(
        'We could not delete your account. Check your connection and try again.',
      );
    }
  }

  AuthProvider? _deletionProvider(User currentUser) {
    final providerIds =
        currentUser.providerData.map((provider) => provider.providerId).toSet();
    if (providerIds.contains(AppleAuthProvider.PROVIDER_ID)) {
      return AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
    }
    if (providerIds.contains(GoogleAuthProvider.PROVIDER_ID)) {
      return GoogleAuthProvider();
    }
    return null;
  }

  String _deletionMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'popup-closed-by-user' ||
      'web-context-cancelled' ||
      'canceled' =>
        'Account deletion was cancelled.',
      'requires-recent-login' =>
        'For security, sign out and sign in again, then retry account deletion.',
      'network-request-failed' =>
        'Check your internet connection and try account deletion again.',
      _ => error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'We could not delete your account. Please try again.',
    };
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;
}
