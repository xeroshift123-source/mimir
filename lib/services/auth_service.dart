import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

class AuthService {
  AuthService._internal();

  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  StreamSubscription<User?>? _firebaseAuthSubscription;
  Future<void>? _initialization;
  Map<String, dynamic>? _currentUserMap;

  final Map<String, Future<Map<String, dynamic>>> _profileSyncs = {};
  String? _lastSyncedUid;
  DateTime? _lastSyncedAt;
  Map<String, dynamic>? _lastSyncedUserMap;

  final StreamController<Map<String, dynamic>?> _authStreamController =
      StreamController<Map<String, dynamic>?>.broadcast();

  Stream<Map<String, dynamic>?> get authStateChanges =>
      _authStreamController.stream;

  Map<String, dynamic>? get currentUser => _currentUserMap;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!kIsWeb) {
      throw UnsupportedError('현재 Google 로그인 1차 구현은 웹만 지원합니다.');
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'mimirdb',
    );

    await _auth!.setPersistence(Persistence.LOCAL);

    await _firebaseAuthSubscription?.cancel();
    _firebaseAuthSubscription = _auth!.authStateChanges().listen(
      (user) async {
        if (user == null) {
          _clearProfileSyncCache();
          _updateUser(null);
          return;
        }

        final userMap = await _syncUserProfileSafely(user);
        _updateUser(userMap);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Firebase 인증 상태 구독 실패: $error');
      },
    );
  }

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    await initialize();

    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'prompt': 'select_account'});
    final credential = await _auth!.signInWithPopup(provider);
    final user = credential.user;

    if (user == null) {
      return null;
    }

    // 인증 성공은 Firestore 프로필 동기화 성공 여부와 분리한다.
    final userMap = await _syncUserProfileSafely(user);
    _updateUser(userMap);
    return userMap;
  }

  Future<void> signOut() async {
    await initialize();
    await _auth!.signOut();
    _clearProfileSyncCache();
  }

  Future<void> deleteAccount() async {
    await initialize();
    final user = _auth!.currentUser;
    if (user == null) {
      throw StateError('로그인된 사용자가 없습니다.');
    }

    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'prompt': 'select_account'});
    await user.reauthenticateWithPopup(provider);

    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('로그인 인증 토큰을 발급할 수 없습니다.');
    }

    final response = await http.post(
      Uri.parse(
        'https://us-central1-nikke-mimir.cloudfunctions.net/deleteMimirAccount',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(const <String, dynamic>{}),
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw StateError('서버 응답 형식이 올바르지 않습니다.');
    }
    final result = Map<String, dynamic>.from(decoded);
    if (response.statusCode != 200 || result['success'] != true) {
      throw StateError(result['error']?.toString() ?? '회원 탈퇴에 실패했습니다.');
    }

    await _auth!.signOut();
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('last_synced_openid'),
      prefs.remove('guest_profile_access_token'),
      prefs.remove('saved_sync_url'),
      prefs.remove('auth_bound_openid'),
    ]);
    _clearProfileSyncCache();
    _updateUser(null);
  }

  Future<void> updateNickname(String newDisplayName) async {
    await initialize();
    final user = _auth!.currentUser;
    if (user == null) {
      throw StateError('로그인된 사용자가 없습니다.');
    }

    await user.updateDisplayName(newDisplayName);
    await user.reload();
    final refreshedUser = _auth!.currentUser;
    if (refreshedUser == null) {
      throw StateError('사용자 정보를 새로고침할 수 없습니다.');
    }

    final userMap = await _syncUserProfile(
      refreshedUser,
      nickname: newDisplayName,
      force: true,
    );
    _updateUser(userMap);
  }

  Future<Map<String, dynamic>> _syncUserProfileSafely(User user) async {
    try {
      return await _syncUserProfile(user);
    } catch (error) {
      debugPrint('Firebase 사용자 프로필 동기화 실패: $error');
      return _toUserMap(
        user,
        profileSyncError: error,
      );
    }
  }

  Future<Map<String, dynamic>> _syncUserProfile(
    User user, {
    String? nickname,
    bool force = false,
  }) {
    if (!force) {
      final inFlight = _profileSyncs[user.uid];
      if (inFlight != null) {
        return inFlight;
      }

      final syncedAt = _lastSyncedAt;
      if (_lastSyncedUid == user.uid &&
          syncedAt != null &&
          DateTime.now().difference(syncedAt) < const Duration(seconds: 2) &&
          _lastSyncedUserMap != null) {
        return Future.value(_lastSyncedUserMap!);
      }
    }

    late final Future<Map<String, dynamic>> operation;
    operation = _writeUserProfile(user, nickname: nickname).then((userMap) {
      _lastSyncedUid = user.uid;
      _lastSyncedAt = DateTime.now();
      _lastSyncedUserMap = userMap;
      return userMap;
    }).whenComplete(() {
      if (identical(_profileSyncs[user.uid], operation)) {
        _profileSyncs.remove(user.uid);
      }
    });

    if (!force) {
      _profileSyncs[user.uid] = operation;
    }
    return operation;
  }

  Map<String, dynamic> _toUserMap(
    User user, {
    Map<String, dynamic>? profile,
    Object? profileSyncError,
  }) {
    final nickname = _readNickname(profile);
    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': nickname ?? user.displayName,
      'nickname': nickname,
      'hasCompletedProfile': nickname != null,
      'photoUrl': user.photoURL,
      'provider': 'google',
      'profileSyncError': profileSyncError,
    };
  }

  Future<Map<String, dynamic>> _writeUserProfile(
    User user, {
    String? nickname,
  }) async {
    final document = _firestore!.collection('users').doc(user.uid);
    final snapshot = await document.get();
    final existingProfile = snapshot.data() ?? <String, dynamic>{};
    final profile = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'photoUrl': user.photoURL,
      'provider': 'google',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!existingProfile.containsKey('createdAt')) {
      profile['createdAt'] = FieldValue.serverTimestamp();
    }

    final normalizedNickname = nickname?.trim();
    if (normalizedNickname != null && normalizedNickname.isNotEmpty) {
      profile['nickname'] = normalizedNickname;
      profile['displayName'] = normalizedNickname;
      profile['profileCompletedAt'] = FieldValue.serverTimestamp();
    } else if (!existingProfile.containsKey('displayName')) {
      profile['displayName'] = user.displayName;
    }

    await document.set(profile, SetOptions(merge: true));
    return _toUserMap(
      user,
      profile: {...existingProfile, ...profile},
    );
  }

  String? _readNickname(Map<String, dynamic>? profile) {
    final value = profile?['nickname'];
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  void _clearProfileSyncCache() {
    _profileSyncs.clear();
    _lastSyncedUid = null;
    _lastSyncedAt = null;
    _lastSyncedUserMap = null;
  }

  void _updateUser(Map<String, dynamic>? userMap) {
    _currentUserMap = userMap;
    _authStreamController.add(userMap);
  }
}
