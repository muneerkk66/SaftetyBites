import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_session.dart';
import 'core/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await AppSession.load();
  final auth = await AuthController.load();
  if (auth.isSignedIn && !session.accountGateComplete) {
    await session.completeAccountGate();
  }
  runApp(SafeBiteApp(session: session, auth: auth));
}
