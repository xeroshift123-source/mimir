import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'mimirdb',
  );

  // 지휘관의 openId로 우리 Firestore에서 박제된 덱 정보 즉시 읽어오기 (CORS 없음!)
  Future<Map<String, dynamic>?> getCommanderProfile(String openId) async {
    try {
      DocumentSnapshot doc = await _db.collection('commanders').doc(openId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint("DB 조회 에러: ${e.toString()}");
    }
    return null;
  }
}
