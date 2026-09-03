import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _updateState(_authService.currentUser);
    _authSubscription = _authService.authStateChanges.listen(_updateState);
    ensureInitialized();
  }

  final AuthService _authService = AuthService();
  StreamSubscription<Map<String, dynamic>?>? _authSubscription;

  bool _isLoggedIn = false;
  bool _isInitializing = true;
  bool _isInitialized = false;
  Object? _initializationError;
  String? _userId;
  String? _email;
  String? _nickname;
  String? _profileImageUrl;
  String? _loginProvider;
  bool _hasCompletedProfile = false;
  Object? _profileSyncError;

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _isInitialized;
  Object? get initializationError => _initializationError;
  String? get userId => _userId;
  String? get email => _email;
  String? get nickname => _nickname;
  String? get profileImageUrl => _profileImageUrl;
  String? get loginProvider => _loginProvider;
  bool get hasCompletedProfile => _hasCompletedProfile;
  bool get hasProfileSyncError => _profileSyncError != null;
  Object? get profileSyncError => _profileSyncError;

  static const bool showLoginFeatures = true;

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    _isInitializing = true;
    _initializationError = null;
    notifyListeners();

    try {
      await _authService.initialize();
      _isInitialized = true;
    } catch (error) {
      _initializationError = error;
      debugPrint('Auth initialization failed: $error');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String provider, {required String customNickname}) async {
    if (provider != 'google') {
      throw UnsupportedError('현재는 Google 로그인만 지원합니다.');
    }

    final user = await _authService.signInWithGoogle();
    _updateState(user);
    return user != null;
  }

  Future<void> logout() => _authService.signOut();

  Future<void> deleteAccount() => _authService.deleteAccount();

  Future<void> updateNickname(String newNickname) =>
      _authService.updateNickname(newNickname);

  void _updateState(Map<String, dynamic>? userMap) {
    if (userMap == null) {
      _isLoggedIn = false;
      _userId = null;
      _email = null;
      _nickname = null;
      _profileImageUrl = null;
      _loginProvider = null;
      _hasCompletedProfile = false;
      _profileSyncError = null;
    } else {
      _isLoggedIn = true;
      _userId = userMap['uid'] as String?;
      _email = userMap['email'] as String?;
      _nickname = (userMap['nickname'] ?? userMap['displayName']) as String?;
      _profileImageUrl = userMap['photoUrl'] as String?;
      _loginProvider = userMap['provider'] as String?;
      _hasCompletedProfile = userMap['hasCompletedProfile'] == true;
      _profileSyncError = userMap['profileSyncError'];
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
