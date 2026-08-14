import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<Map<String, dynamic>?>? _authSubscription;

  bool _isLoggedIn = false;
  String? _userId;
  String? _nickname;
  String? _profileImageUrl;
  String? _loginProvider;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get nickname => _nickname;
  String? get profileImageUrl => _profileImageUrl;
  String? get loginProvider => _loginProvider;

  static const bool showLoginFeatures = true;

  /// Returns whether actual Firebase Authentication backend is operational.
  bool get isRealAuthActive =>
      _authService.isRealAuthActive && _useRealFirebaseMode;

  bool _useRealFirebaseMode =
      true; // Try Real Firebase Google Auth backend first on local dev & prod
  bool get useRealFirebaseMode => _useRealFirebaseMode;

  bool _isInitializing = false;
  bool _isInitialized = false;

  void setRealFirebaseMode(bool enabled) {
    _useRealFirebaseMode = enabled;
    if (enabled) {
      ensureInitialized();
    } else {
      notifyListeners();
    }
  }

  Future<void> ensureInitialized() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;
    try {
      await _authService.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint("Auth initialization failed: $e");
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  AuthProvider() {
    // 💡 Synchronously read cached initial user state from AuthService
    _updateState(_authService.currentUser);

    // Ensure Real Firebase Auth service initialized
    ensureInitialized();

    // 💡 Listen to unified authentication updates reactively (both real & simulated)
    _authSubscription = _authService.authStateChanges.listen((userMap) {
      _updateState(userMap);
    });
  }

  void _updateState(Map<String, dynamic>? userMap) {
    if (userMap != null) {
      _isLoggedIn = true;
      _userId = userMap['uid'] as String?;
      _nickname = userMap['displayName'] as String? ?? '지휘관';
      _profileImageUrl = userMap['photoUrl'] as String?;
      _loginProvider = userMap['provider'] as String? ?? 'google';

      // 💡 Automatically resolve bound openId from Firestore DB on login & print debug log
      final uid = _userId;
      if (uid != null && uid.isNotEmpty) {
        DatabaseService().getUserDoc(uid).then((userDoc) async {
          debugPrint("==================================================");
          debugPrint("🔍 [DB Debug Log] Logged-in Google UID: $uid");
          debugPrint("📄 [DB Debug Log] User Document from Firestore: $userDoc");
          
          final openId = userDoc?['openId'] as String?;
          debugPrint("🔗 [DB Debug Log] Resolved Linked openId: $openId");

          if (openId != null && openId.isNotEmpty) {
            final commanderProfile = await DatabaseService().getCommanderProfile(openId);
            debugPrint("🛡️ [DB Debug Log] Commander Profile from Firestore: ${commanderProfile != null ? commanderProfile['nickname'] : 'null'}");

            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('auth_bound_openid', openId);
              await prefs.setString('last_synced_openid', openId);
            } catch (_) {}
          } else {
            debugPrint("⚠️ [DB Debug Log] No linked openId found for this user in Firestore DB.");
          }
          debugPrint("==================================================");
        });
      }
    } else {
      _isLoggedIn = false;
      _userId = null;
      _nickname = null;
      _profileImageUrl = null;
      _loginProvider = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Perform login (Attempts real Firebase Google OAuth popup, falls back to simulated mode)
  Future<void> login(String provider, {required String customNickname}) async {
    if (provider == 'google' && _useRealFirebaseMode) {
      final result = await _authService.signInWithGoogleReal();
      if (result != null) return;
    }
    // Simulation mode ONLY when real Firebase is NOT active
    await _authService.signInWithGoogleSimulated(customNickname);
  }

  /// Perform unified sign-out
  Future<void> logout() async {
    await _authService.signOut();
  }

  /// Update the current user nickname
  Future<void> updateNickname(String newNickname) async {
    await _authService.updateNickname(newNickname);
  }
}
