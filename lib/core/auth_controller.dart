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
  bool isBusy = false;
  String? configurationMessage;

  bool get isSignedIn => user != null;

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

  Future<void> signIn({required String email, required String password}) {
    return _run(
      () => _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  Future<void> createAccount({
    required String email,
    required String password,
  }) {
    return _run(
      () => _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  Future<void> _run(Future<UserCredential> Function() operation) async {
    if (_auth == null) {
      throw StateError('Firebase Authentication is not configured.');
    }
    isBusy = true;
    notifyListeners();
    try {
      await operation();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Enter a valid email address.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'The email or password is incorrect.',
        'email-already-in-use' =>
          'An account already exists for this email address.',
        'weak-password' => 'Use a password with at least 6 characters.',
        'operation-not-allowed' =>
          'Enable Email/Password in Firebase Authentication first.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        _ => error.message ?? 'Authentication could not be completed.',
      };
    }
    return 'Authentication could not be completed.';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
