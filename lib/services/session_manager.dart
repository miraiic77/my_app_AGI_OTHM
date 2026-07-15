import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'role_service.dart';

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  Timer? _logoutTimer;
  static const Duration _timeout = Duration(minutes: 5);

  // Call this when the user successfully logs in
  void startSession() {
    resetTimer();
  }

  // Call this whenever the user interacts with the app
  void resetTimer() {
    _logoutTimer?.cancel();
    _logoutTimer = Timer(_timeout, _performAutoLogout);
  }

void _performAutoLogout() {
  print('⏰ 5 minutes of inactivity. Auto-logging out...');
  RoleService().clearRole(); // Clear cached role
  FirebaseAuth.instance.signOut();
  _logoutTimer?.cancel();
}

  void dispose() {
    _logoutTimer?.cancel();
  }
}