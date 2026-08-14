// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'database_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isFirebaseInitialized = false;
  bool _useRealFirebase = false;

  // Real SDK Clients
  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;

  // Simulated Fallback User State Controllers
  bool _simulatedLoggedIn = false;
  String? _simulatedUid;
  String? _simulatedEmail;
  String? _simulatedDisplayName;

  // Current User Cache for synchronous access during AuthProvider load
  Map<String, dynamic>? _currentUserMap;

  final StreamController<Map<String, dynamic>?> _authStreamController =
      StreamController<Map<String, dynamic>?>.broadcast();

  /// Returns whether actual Firebase Authentication backend is fully initialized and operational.
  bool get isRealAuthActive => _isFirebaseInitialized && _useRealFirebase;

  /// Exposes user authentication state updates dynamically (works in both real & simulated modes).
  Stream<Map<String, dynamic>?> get authStateChanges => _authStreamController.stream;

  /// Synchronously retrieve the current logged-in user details.
  Map<String, dynamic>? get currentUser => _currentUserMap;

  void _updateUser(Map<String, dynamic>? userMap) {
    _currentUserMap = userMap;
    _authStreamController.add(userMap);
  }

  /// Initialize Firebase Auth & Google Sign-In with robust error handling.
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final auth = FirebaseAuth.instance;
      _auth = auth;
      _isFirebaseInitialized = true;
      _useRealFirebase = true;
      debugPrint("✔ MIMIR Auth: Firebase Google Auth backend connected!");

      auth.authStateChanges().listen(
        (User? user) {
          if (user != null) {
            _updateUser({
              'uid': user.uid,
              'email': user.email ?? '',
              'displayName': user.displayName ?? '지휘관',
              'photoUrl': user.photoURL ?? '',
              'provider': 'google',
            });
          } else {
            _updateUser(null);
          }
        },
        onError: (dynamic authStateError) {
          debugPrint("⚠️ authStateChanges stream info: $authStateError");
        },
      );
    } catch (e) {
      debugPrint("⚠️ Firebase Auth Initialization fallback: $e");
      _isFirebaseInitialized = false;
      _useRealFirebase = false;
      await _loadSimulatedSession();
    }
  }

  // --- Real Firebase/Google Sign-In logic ---

  Future<Map<String, dynamic>?> signInWithGoogleReal() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final auth = _auth ?? FirebaseAuth.instance;
      _auth = auth;

      UserCredential userCredential;
      if (kIsWeb) {
        final GoogleSignIn gSignIn = GoogleSignIn(
          clientId: '944224854885-h22023gfgeaii9to9pc2qd8lauig9mbo.apps.googleusercontent.com',
          scopes: ['email'],
        );
        final googleUser = await gSignIn.signIn();
        if (googleUser == null) {
          throw Exception("구글 계정 선택이 취소되었습니다.");
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final tokenStr = googleAuth.accessToken;

        if (tokenStr == null || tokenStr.isEmpty) {
          throw Exception("구글 인증 토큰(accessToken)을 취득하지 못했습니다.");
        }

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: tokenStr,
        );

        userCredential = await auth.signInWithCredential(credential);
      } else {
        _googleSignIn ??= GoogleSignIn(scopes: ['email']);
        final googleUser = await _googleSignIn?.signIn();
        if (googleUser == null) {
          throw Exception("구글 계정 선택이 취소되었습니다.");
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await auth.signInWithCredential(credential);
      }

      final User? user = userCredential.user;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final cachedNick = prefs.getString('user_nickname');

        String fallbackName = '지휘관';
        final emailStr = user.email;
        if (emailStr != null && emailStr.contains('@')) {
          final parts = emailStr.split('@');
          if (parts.isNotEmpty && parts.first.isNotEmpty) {
            fallbackName = parts.first;
          }
        }

        final rawDisp = user.displayName;
        final dispName = (cachedNick != null && cachedNick.trim().isNotEmpty)
            ? cachedNick.trim()
            : ((rawDisp != null && rawDisp.trim().isNotEmpty)
                ? rawDisp.trim()
                : fallbackName);

        final userMap = <String, dynamic>{
          'uid': user.uid,
          'email': emailStr ?? '',
          'displayName': dispName,
          'nickname': dispName,
          'photoUrl': user.photoURL ?? '',
          'provider': 'google',
        };
        _updateUser(userMap);
        DatabaseService().saveUserProfile(userMap);
        return userMap;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("⚠️ FirebaseAuthException code: ${e.code}, message: ${e.message}");
      if (e.code == 'popup-closed-by-user') {
        throw Exception("로그인 팝업창이 닫혔습니다.");
      } else if (e.code == 'unauthorized-domain') {
        throw Exception("Firebase 콘솔 승인된 도메인(Authorized domains)에 현재 주소가 등록되지 않았습니다.");
      } else if (e.code == 'operation-not-allowed') {
        throw Exception("Firebase 콘솔에서 Google 로그인 제공업체(Sign-in provider)가 비활성화되어 있습니다.");
      } else if (e.code == 'popup-blocked') {
        throw Exception("브라우저 팝업이 차단되었습니다. 팝업 허용 후 다시 시도해 주세요.");
      } else {
        throw Exception("구글 로그인 오류 (${e.code}): ${e.message ?? e.toString()}");
      }
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      debugPrint("⚠️ Real Google Sign-in failed: $errStr");
      throw Exception("구글 로그인 실패: $errStr");
    }
    return null;
  }

  // --- Simulated Fallback Auth Logic ---

  Future<void> _loadSimulatedSession() async {
    final prefs = await SharedPreferences.getInstance();
    _simulatedLoggedIn = prefs.getBool('auth_is_logged_in') ?? false;
    if (_simulatedLoggedIn) {
      _simulatedUid = prefs.getString('auth_user_id');
      _simulatedDisplayName = prefs.getString('auth_nickname');
      _simulatedEmail = '${_simulatedUid ?? 'commander'}@mimir.com';

      _updateUser({
        'uid': _simulatedUid,
        'email': _simulatedEmail,
        'displayName': _simulatedDisplayName,
        'photoUrl': 'google',
        'provider': 'google',
      });
    } else {
      _updateUser(null);
    }
  }

  Future<Map<String, dynamic>> signInWithGoogleSimulated(String customNickname) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = 'commander_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    _simulatedLoggedIn = true;
    _simulatedUid = uid;
    
    final trimmedName = customNickname.trim();
    final suffix = uid.length >= 4 ? uid.substring(uid.length - 4) : '0000';
    final dispName = trimmedName.isEmpty ? '지휘관_$suffix' : trimmedName;
    _simulatedDisplayName = dispName;
    _simulatedEmail = '$uid@mimir.com';

    await prefs.setBool('auth_is_logged_in', true);
    await prefs.setString('auth_user_id', uid);
    await prefs.setString('auth_nickname', dispName);
    await prefs.setString('auth_profile_image_url', 'google');
    await prefs.setString('auth_login_provider', 'google');

    final userMap = {
      'uid': uid,
      'email': _simulatedEmail,
      'displayName': dispName,
      'photoUrl': 'google',
      'provider': 'google',
    };

    _updateUser(userMap);
    return userMap;
  }

  // --- Unified Public Interface ---

  /// Perform Google Sign-In (automatically routes to real or simulated mode based on context)
  Future<Map<String, dynamic>?> signIn({required String customNickname}) async {
    if (isRealAuthActive) {
      return await signInWithGoogleReal();
    } else {
      return await signInWithGoogleSimulated(customNickname);
    }
  }

  /// Perform Sign-Out (works seamlessly in both real & simulated contexts)
  Future<void> signOut() async {
    if (isRealAuthActive) {
      await _googleSignIn?.signOut();
      await _auth?.signOut();
      _updateUser(null);
    } else {
      final prefs = await SharedPreferences.getInstance();
      _simulatedLoggedIn = false;
      _simulatedUid = null;
      _simulatedDisplayName = null;
      _simulatedEmail = null;

      await prefs.remove('auth_is_logged_in');
      await prefs.remove('auth_user_id');
      await prefs.remove('auth_nickname');
      await prefs.remove('auth_profile_image_url');
      await prefs.remove('auth_login_provider');

      _updateUser(null);
    }
  }

  /// Update nickname (propagates to local SharedPreferences during simulation)
  Future<void> updateNickname(String newDisplayName) async {
    if (isRealAuthActive) {
      final user = _auth?.currentUser;
      if (user != null) {
        await user.updateDisplayName(newDisplayName);
        _updateUser({
          'uid': user.uid,
          'email': user.email,
          'displayName': newDisplayName,
          'photoUrl': user.photoURL,
          'provider': 'google',
        });
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      _simulatedDisplayName = newDisplayName;
      await prefs.setString('auth_nickname', newDisplayName);
      _updateUser({
        'uid': _simulatedUid,
        'email': _simulatedEmail,
        'displayName': _simulatedDisplayName,
        'photoUrl': 'google',
        'provider': 'google',
      });
    }
  }
}
