import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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
      false; // Default to Simulated Mode for absolute safety on local dev
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

    // 💡 Listen to unified authentication updates reactively (both real & simulated)
    _authSubscription = _authService.authStateChanges.listen((userMap) {
      _updateState(userMap);
    });
  }

  void _updateState(Map<String, dynamic>? userMap) {
    if (userMap != null) {
      _isLoggedIn = true;
      _userId = userMap['uid'] as String?;
      _nickname = userMap['displayName'] as String?;
      _profileImageUrl = userMap['photoUrl'] as String?;
      _loginProvider = userMap['provider'] as String?;
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

  /// Perform login (Google utilizes real Firebase Auth when available, others simulate)
  Future<void> login(String provider, {required String customNickname}) async {
    if (provider == 'google') {
      await _authService.signIn(customNickname: customNickname);
    } else {
      // Discord and Apple fall back to simulated mode elegantly
      await _authService.signInWithGoogleSimulated(customNickname);
    }
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
