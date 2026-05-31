// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

import '../firebase_options.dart';

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
      // 💡 On Web, check if Firebase CDN is reachable to prevent dynamic import freezes
      if (kIsWeb) {
        try {
          // A simple HEAD or GET request to the CDN URL to verify connectivity.
          // If blocked by an adblocker or firewall, this throws a catchable network exception.
          await html.HttpRequest.getString('https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js')
              .timeout(const Duration(seconds: 2));
        } catch (e) {
          throw Exception("Firebase CDN is blocked or unreachable (possibly by AdBlocker/Firewall).");
        }
      }

      // 1. Try to initialize Firebase.
      // On Web, firebase_core dynamically loads the modular JS SDK. We use a generous timeout (10 seconds)
      // to allow downloading of SDK files over the network without blocking startup.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 10));

      _auth = FirebaseAuth.instance;
      _googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );

      _isFirebaseInitialized = true;

      // 💡 Verify if credentials are valid or still placeholders
      final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
      if (apiKey.contains('MOCK_API_KEY')) {
        // If dummy placeholder keys are found, run in highly robust Simulation Mode
        _useRealFirebase = false;
        debugPrint("✔ MIMIR Auth: Firebase initialized using Mock Keys. Running in resilient Simulation Mode.");
      } else {
        // Configuration files/keys are valid and set! Enable actual Firebase connection!
        _useRealFirebase = true;
        debugPrint("✔ MIMIR Auth: Firebase successfully connected to Google Authentication backend!");
      }
    } catch (e) {
      // Graceful fallback to Simulation Mode on any error (e.g. missing native configurations or timeout)
      _isFirebaseInitialized = false;
      _useRealFirebase = false;
      debugPrint("⚠️ MIMIR Auth Failure during Firebase init: $e");
      debugPrint("✔ MIMIR Auth Fallback: Switched to Hybrid Simulated Auth Mode (Crash Avoided).");
    }

    // Load initial local mock sessions if in Simulation Mode
    if (!_useRealFirebase) {
      await _loadSimulatedSession();
    } else {
      // If real Firebase is operational, listen to actual authStateChanges
      _auth!.authStateChanges().listen((User? user) {
        if (user != null) {
          _updateUser({
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName,
            'photoUrl': user.photoURL,
            'provider': 'google',
          });
        } else {
          _updateUser(null);
        }
      });
    }
  }

  // --- Real Firebase/Google Sign-In logic ---

  Future<Map<String, dynamic>?> signInWithGoogleReal() async {
    if (!isRealAuthActive) return null;

    try {
      // 1. Trigger the actual Google interactive sign-in window
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) return null; // Sign-in was cancelled by user

      // 2. Fetch authentication details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a new credential for Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the credential
      final UserCredential userCredential = await _auth!.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final userMap = {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? googleUser.displayName,
          'photoUrl': user.photoURL ?? googleUser.photoUrl,
          'provider': 'google',
        };
        _updateUser(userMap);
        return userMap;
      }
    } catch (e) {
      debugPrint("⚠️ Real Google Sign-in failed: $e");
      rethrow;
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
    _simulatedLoggedIn = true;
    _simulatedUid = 'commander_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    final trimmedName = customNickname.trim();
    _simulatedDisplayName = trimmedName.isEmpty ? '사령관_${_simulatedUid!.substring(_simulatedUid!.length - 4)}' : trimmedName;
    _simulatedEmail = '$_simulatedUid@mimir.com';

    await prefs.setBool('auth_is_logged_in', true);
    await prefs.setString('auth_user_id', _simulatedUid!);
    await prefs.setString('auth_nickname', _simulatedDisplayName!);
    await prefs.setString('auth_profile_image_url', 'google');
    await prefs.setString('auth_login_provider', 'google');

    final userMap = {
      'uid': _simulatedUid,
      'email': _simulatedEmail,
      'displayName': _simulatedDisplayName,
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
