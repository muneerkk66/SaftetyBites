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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
