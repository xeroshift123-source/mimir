import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LinkedCommanderAccount {
  const LinkedCommanderAccount({
    required this.openId,
    required this.nickname,
    required this.server,
  });

  final String openId;
  final String nickname;
  final String server;
}

class CommanderRefreshCooldown implements Exception {
  const CommanderRefreshCooldown(this.retryAfterSeconds);

  final int retryAfterSeconds;
}

class DatabaseService {
  static const _guestProfileEndpoint =
      'https://us-central1-nikke-mimir.cloudfunctions.net/getGuestCommanderProfile';

  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'mimirdb',
  );

  // 지휘관의 openId로 우리 Firestore에서 박제된 덱 정보 즉시 읽어오기 (CORS 없음!)
  Future<Map<String, dynamic>?> getCommanderProfile(String openId) async {
    if (openId == 'eunhwa_is_the_best') {
      return _getMockEunhwaProfile();
    }

    if (FirebaseAuth.instance.currentUser == null) {
      return _getGuestCommanderProfile(openId);
    }

    try {
      DocumentSnapshot doc = await _db
          .collection('commanders')
          .doc(openId)
          .get(const GetOptions(source: Source.server));
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint("DB 조회 에러: ${e.toString()}");
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getGuestCommanderProfile(String openId) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedOpenId = prefs.getString('last_synced_openid')?.trim();
    final accessToken = prefs.getString('guest_profile_access_token')?.trim();
    if (cachedOpenId != openId || accessToken == null || accessToken.isEmpty) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(_guestProfileEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'openId': openId, 'accessToken': accessToken}),
      );
      final result = jsonDecode(response.body);
      if (result is Map &&
          response.statusCode == 200 &&
          result['success'] == true) {
        return Map<String, dynamic>.from(result['data'] as Map);
      }
      debugPrint(
          '게스트 프로필 조회 실패: ${result is Map ? result['error'] : response.statusCode}');
    } catch (error) {
      debugPrint('게스트 프로필 조회 에러: $error');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    final snapshot = await _db.collection('users').doc(uid).get();
    return snapshot.data();
  }

  Future<List<LinkedCommanderAccount>> getLinkedCommanderAccounts(
    String uid,
  ) async {
    final userProfile = await getUserProfile(uid);
    final linkedIds = <String>[];

    final rawLinkedIds = userProfile?['linkedOpenIds'];
    if (rawLinkedIds is List) {
      for (final value in rawLinkedIds) {
        final openId = value?.toString().trim() ?? '';
        if (openId.isNotEmpty && !linkedIds.contains(openId)) {
          linkedIds.add(openId);
        }
      }
    }

    final legacyOpenId = userProfile?['openId']?.toString().trim() ?? '';
    if (legacyOpenId.isNotEmpty && !linkedIds.contains(legacyOpenId)) {
      linkedIds.add(legacyOpenId);
    }

    return Future.wait(
      linkedIds.map((openId) async {
        final profile = await getCommanderProfile(openId);
        final nickname = profile?['nickname']?.toString().trim();
        final server = profile?['server']?.toString().trim();
        return LinkedCommanderAccount(
          openId: openId,
          nickname:
              nickname == null || nickname.isEmpty ? '지휘관 정보 없음' : nickname,
          server: server == null || server.isEmpty ? '알 수 없음' : server,
        );
      }),
    );
  }

  Future<String?> getSelectedCommanderOpenId(String? uid) async {
    if (uid != null && uid.isNotEmpty) {
      try {
        final profile = await getUserProfile(uid);
        final linkedIds = _linkedOpenIdsFromProfile(profile);
        final selectedOpenId = profile?['selectedOpenId']?.toString().trim();
        final legacyOpenId = profile?['openId']?.toString().trim();

        final resolved = selectedOpenId != null &&
                selectedOpenId.isNotEmpty &&
                linkedIds.contains(selectedOpenId)
            ? selectedOpenId
            : legacyOpenId != null &&
                    legacyOpenId.isNotEmpty &&
                    linkedIds.contains(legacyOpenId)
                ? legacyOpenId
                : linkedIds.firstOrNull;

        if (resolved != null) {
          await _rememberSelectedCommander(resolved);
          if (selectedOpenId != resolved &&
              FirebaseAuth.instance.currentUser?.uid == uid) {
            try {
              await _db.collection('users').doc(uid).set({
                'selectedOpenId': resolved,
                'selectedOpenIdUpdatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (error) {
              debugPrint('선택된 지휘관 마이그레이션 에러: $error');
            }
          }
        }
        return resolved;
      } catch (error) {
        debugPrint('선택된 지휘관 조회 에러: $error');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedOpenId = prefs.getString('last_synced_openid')?.trim();
    return cachedOpenId == null || cachedOpenId.isEmpty ? null : cachedOpenId;
  }

  Future<void> selectCommanderForUser(String uid, String openId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != uid) {
      throw StateError('로그인 인증을 확인할 수 없습니다.');
    }

    final normalizedOpenId = openId.trim();
    final profile = await getUserProfile(uid);
    final linkedIds = _linkedOpenIdsFromProfile(profile);
    if (normalizedOpenId.isEmpty || !linkedIds.contains(normalizedOpenId)) {
      throw StateError('연동된 지휘관만 표시 계정으로 선택할 수 있습니다.');
    }

    await _db.collection('users').doc(uid).set({
      'selectedOpenId': normalizedOpenId,
      'selectedOpenIdUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _rememberSelectedCommander(normalizedOpenId);
  }

  List<String> _linkedOpenIdsFromProfile(Map<String, dynamic>? profile) {
    final linkedIds = <String>[];
    final rawLinkedIds = profile?['linkedOpenIds'];
    if (rawLinkedIds is List) {
      for (final value in rawLinkedIds) {
        final openId = value?.toString().trim() ?? '';
        if (openId.isNotEmpty && !linkedIds.contains(openId)) {
          linkedIds.add(openId);
        }
      }
    }

    final legacyOpenId = profile?['openId']?.toString().trim() ?? '';
    if (legacyOpenId.isNotEmpty && !linkedIds.contains(legacyOpenId)) {
      linkedIds.add(legacyOpenId);
    }
    return linkedIds;
  }

  Future<void> _rememberSelectedCommander(String openId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_synced_openid', openId);
  }

  Future<void> refreshLinkedCommander(String openId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('로그인 인증 토큰을 발급할 수 없습니다.');
    }

    final response = await http.post(
      Uri.parse(
        'https://us-central1-nikke-mimir.cloudfunctions.net/scrapeNikkeProfile',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'refresh': true,
        'openId': openId,
      }),
    );
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 429) {
      final retryAfter = (result['retryAfterSeconds'] as num?)?.ceil() ?? 30;
      throw CommanderRefreshCooldown(retryAfter.clamp(1, 30));
    }
    if (response.statusCode != 200 || result['success'] != true) {
      throw StateError(result['error']?.toString() ?? '정보 갱신에 실패했습니다.');
    }
  }

  Future<void> unlinkCommanderFromUser(String uid, String openId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != uid) {
      throw StateError('로그인 인증을 확인할 수 없습니다.');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('로그인 인증 토큰을 발급할 수 없습니다.');
    }

    final response = await http.post(
      Uri.parse(
        'https://us-central1-nikke-mimir.cloudfunctions.net/unlinkBlablaAccount',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'openId': openId}),
    );
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || result['success'] != true) {
      throw StateError(result['error']?.toString() ?? '연동 해제에 실패했습니다.');
    }

    final prefs = await SharedPreferences.getInstance();
    final activeOpenId = result['activeOpenId']?.toString().trim() ?? '';
    final selectedOpenId =
        result['selectedOpenId']?.toString().trim() ?? activeOpenId;
    final activeSyncUrl = result['activeSyncUrl']?.toString().trim() ?? '';
    if (selectedOpenId.isEmpty) {
      await prefs.remove('last_synced_openid');
      await prefs.remove('guest_profile_access_token');
    } else {
      await prefs.setString('last_synced_openid', selectedOpenId);
    }
    if (activeSyncUrl.isEmpty) {
      await prefs.remove('saved_sync_url');
    } else {
      await prefs.setString('saved_sync_url', activeSyncUrl);
    }
    await prefs.remove('auth_bound_openid');
  }

  Future<Map<String, dynamic>> _getMockEunhwaProfile() async {
    final List<Map<String, dynamic>> characters = [];
    final List<String> slots = ['head', 'torso', 'arm', 'leg'];
    final List<int> overloadOptions = [7000515, 7000815, 7000715];
    final nikkeJson = await rootBundle.loadString('assets/nikkes.json');
    final nikkes = jsonDecode(nikkeJson) as List<dynamic>;
    final nameCodes = nikkes
        .map((nikke) => (nikke as Map<String, dynamic>)['blablaNameCode'])
        .whereType<int>();

    for (final code in nameCodes) {
      final equipment = slots.map((slot) {
        return {
          "slot": slot,
          "tid": 3110901,
          "level": 5,
          "tier": 10,
          "overloadOptions": overloadOptions,
        };
      }).toList();

      characters.add({
        "name_code": code,
        "grade": 3,
        "core": 7,
        "bondLevel": 40,
        "skills": {
          "skill1": 10,
          "skill2": 10,
          "burst": 10,
        },
        "favoriteItem": {"tid": 200000, "level": 15},
        "equipment": equipment,
      });
    }

    final recycleRoom = [
      {"tid": 1001, "lv": 500},
      {"tid": 1101, "lv": 500},
      {"tid": 1102, "lv": 500},
      {"tid": 1103, "lv": 500},
      {"tid": 1201, "lv": 500},
      {"tid": 1202, "lv": 500},
      {"tid": 1203, "lv": 500},
      {"tid": 1204, "lv": 500},
      {"tid": 1205, "lv": 500},
    ];

    return {
      "nickname": "은화단",
      "synchroLevel": 700,
      "towerFloor": 759,
      "normalCampaign": "48-36",
      "hardCampaign": "38-36",
      "ownedNikkesCount": 183,
      "combatPower": 978491,
      "joinedAt": "2024-11-15T00:00:00Z",
      "overclockSeasonHighScore": 28,
      "overclockSubseasonHighScore": 28,
      "overclockHighScore": 28,
      "recycleRoom": recycleRoom,
      "characters": characters,
    };
  }
}
