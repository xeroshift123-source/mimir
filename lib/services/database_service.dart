import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
      DocumentSnapshot doc =
          await _db.collection('commanders').doc(openId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint("DB 조회 에러: ${e.toString()}");
    }
    return null;
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
      {"tid": 1001, "lv": 200},
      {"tid": 1101, "lv": 200},
      {"tid": 1102, "lv": 200},
      {"tid": 1103, "lv": 200},
      {"tid": 1201, "lv": 200},
      {"tid": 1202, "lv": 200},
      {"tid": 1203, "lv": 200},
      {"tid": 1204, "lv": 200},
      {"tid": 1205, "lv": 200},
    ];

    return {
      "nickname": "은화단",
      "synchroLevel": 700,
      "recycleRoom": recycleRoom,
      "characters": characters,
    };
  }
}
