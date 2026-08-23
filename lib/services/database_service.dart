import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mimir/utils/blabla_map.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'mimirdb',
  );

  // 지휘관의 openId로 우리 Firestore에서 박제된 덱 정보 즉시 읽어오기 (CORS 없음!)
  Future<Map<String, dynamic>?> getCommanderProfile(String openId) async {
    if (openId == 'eunhwa_is_the_best') {
      return _getMockEunhwaProfile();
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

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    final snapshot = await _db.collection('users').doc(uid).get();
    return snapshot.data();
  }

  Future<void> unlinkCommanderFromUser(String uid) async {
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
    );
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || result['success'] != true) {
      throw StateError(result['error']?.toString() ?? '연동 해제에 실패했습니다.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_synced_openid');
    await prefs.remove('saved_sync_url');
    await prefs.remove('auth_bound_openid');
  }

  Map<String, dynamic> _getMockEunhwaProfile() {
    final List<Map<String, dynamic>> characters = [];
    final List<String> slots = ['head', 'torso', 'arm', 'leg'];
    final List<int> overloadOptions = [7000515, 7000815, 7000715];

    for (var code in BlablaMap.characterNames.keys) {
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
      "recycleRoom": recycleRoom,
      "characters": characters,
    };
  }
}
