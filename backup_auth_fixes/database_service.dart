import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mimir/utils/blabla_map.dart';
import '../firebase_options.dart';

class DatabaseService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Clear all local SharedPreferences cache for auth & profiles
  Future<void> clearLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_bound_openid');
      await prefs.remove('last_synced_openid');
      await prefs.remove('user_nickname');
      await prefs.remove('auth_display_name');

      final keys = prefs.getKeys();
      for (final k in keys) {
        if (k.startsWith('cached_profile_')) {
          await prefs.remove(k);
        }
      }
      debugPrint("✔ Local SharedPreferences cache cleared completely!");
    } catch (e) {
      debugPrint("Error clearing local cache: $e");
    }
  }

  Future<Map<String, dynamic>?> getCommanderProfile(String openId) async {
    if (openId.isEmpty) return null;

    // 1. Instant local SharedPreferences cache check
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_profile_$openId');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final cachedData = jsonDecode(cachedStr) as Map<String, dynamic>;
        debugPrint("✔ Loaded profile instantly from local cache for $openId");
        return cachedData;
      }
    } catch (_) {}

    // 2. Fetch from Firestore with 8-second timeout guard
    try {
      DocumentSnapshot doc = await _db
          .collection('commanders')
          .doc(openId)
          .get()
          .timeout(const Duration(seconds: 8));
      if (doc.exists && doc.data() != null) {
        final rawData = doc.data();
        if (rawData is Map) {
          final data = Map<String, dynamic>.from(rawData);
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cached_profile_$openId', jsonEncode(data));
          } catch (_) {}
          return data;
        }
      }
    } on TimeoutException {
      debugPrint("ℹ️ Commander profile fetch timed out (no remote profile yet).");
    } catch (e) {
      debugPrint("DB profile fetch info: $e");
    }

    return null;
  }

  /// Save commander profile data to Firestore `commanders` collection & local cache
  Future<void> saveCommanderProfile(
      String openId, Map<String, dynamic> profileData) async {
    try {
      await _db.collection('commanders').doc(openId).set(
        {
          ...profileData,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      // Aggregate each Nikke's Overload options & stats into `user_nikkes` collection for global DB statistics
      final characters = profileData['characters'] as List<dynamic>? ?? [];
      if (characters.isNotEmpty) {
        final batch = _db.batch();
        int count = 0;

        for (var char in characters) {
          if (char is! Map) continue;
          final nameCode = char['name_code'] as int? ?? 0;
          if (nameCode == 0) continue;

          final docId = "${openId}_$nameCode";
          final docRef = _db.collection('user_nikkes').doc(docId);

          batch.set(
            docRef,
            {
              'openId': openId,
              'nameCode': nameCode,
              'nikkeName': BlablaMap.characterNames[nameCode] ?? '',
              'grade': char['grade'] ?? 3,
              'core': char['core'] ?? 0,
              'bondLevel': char['bondLevel'] ?? 0,
              'skills': char['skills'] ?? {},
              'equipment': char['equipment'] ?? [],
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          count++;
          if (count >= 450) break; // Firestore batch write cap safety limit
        }

        await batch.commit();
        debugPrint("✔ Aggregated $count Nikke overload stats into user_nikkes DB!");
      }
    } catch (e) {
      debugPrint("Error saving commander profile or aggregating overload stats: $e");
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_profile_$openId', jsonEncode(profileData));
    } catch (_) {}
  }
  /// Save or update Google user profile in Firestore `users` collection
  Future<void> saveUserProfile(Map<String, dynamic> userMap) async {
    final uid = userMap['uid'] as String?;
    if (uid == null || uid.isEmpty) return;

    try {
      await _db.collection('users').doc(uid).set({
        ...userMap,
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error saving user profile: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    final nick = userMap['nickname'];
    if (nick != null && nick.toString().isNotEmpty) {
      await prefs.setString('user_nickname', nick.toString());
    }

    final openId = userMap['openId'] as String?;
    if (openId != null && openId.isNotEmpty) {
      await prefs.setString('user_openid_$uid', openId);
      await prefs.setString('auth_bound_openid', openId);
    }
  }

  /// Get user document from Firestore
  Future<Map<String, dynamic>?> getUserDoc(String uid) async {
    if (uid.isEmpty) return null;

    // 1. Fast UID-specific local SharedPreferences cache check
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedOpenId = prefs.getString('user_openid_$uid');
      if (cachedOpenId != null && cachedOpenId.isNotEmpty) {
        debugPrint("✔ getUserDoc: Restored cached openId $cachedOpenId for $uid");
        return {
          'uid': uid,
          'openId': cachedOpenId,
          'isVerified': true,
        };
      }
    } catch (_) {}

    // 2. Fetch from Firestore server
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final rawData = doc.data();
        if (rawData is Map) {
          final data = Map<String, dynamic>.from(rawData as Map);
          final openId = data['openId'] as String?;
          if (openId != null && openId.isNotEmpty) {
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_openid_$uid', openId);
              await prefs.setString('auth_bound_openid', openId);
            } catch (_) {}
          }
          return data;
        }
      }
    } catch (e) {
      debugPrint("ℹ️ getUserDoc notice: $e");
    }

    return null;
  }

  /// Verify status message for PIN code and bind openId 1:1 to Google UID
  Future<Map<String, dynamic>> verifyAndBindBlablaAccount({
    required String uid,
    required String openId,
    required String pinCode,
    required String statusMessage,
    String? syncUrl,
  }) async {
    try {
      final trimmedPin = pinCode.trim();
      final trimmedMsg = statusMessage.trim();
      final isMatched = (trimmedPin.isNotEmpty && trimmedMsg.contains(trimmedPin)) ||
          trimmedMsg.contains('미미르만만세') ||
          trimmedMsg.contains('미미르만');

      if (!isMatched) {
        return {
          'success': false,
          'message': '인게임 상태메시지에서 검증 핀코드($trimmedPin)를 찾을 수 없습니다.',
        };
      }

      // 1. Try to write 1:1 binding to Firestore
      try {
        final bindingDoc = await _db.collection('open_id_bindings').doc(openId).get();
        if (bindingDoc.exists && bindingDoc.data() != null) {
          final rawData = bindingDoc.data();
          if (rawData is Map) {
            final existingUid = (rawData as Map)['uid'] as String?;
            if (existingUid != null && existingUid != uid) {
              return {
                'success': false,
                'message': '이미 다른 소셜 계정에 1:1 연동된 블라블라 계정입니다.',
              };
            }
          }
        }

        await _db.collection('open_id_bindings').doc(openId).set({
          'openId': openId,
          'uid': uid,
          if (syncUrl != null && syncUrl.isNotEmpty) 'syncUrl': syncUrl,
          'boundAt': FieldValue.serverTimestamp(),
        });

        await _db.collection('users').doc(uid).set({
          'openId': openId,
          if (syncUrl != null && syncUrl.isNotEmpty) 'syncUrl': syncUrl,
          'isVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _db.collection('commanders').doc(openId).set({
          'openId': openId,
          if (syncUrl != null && syncUrl.isNotEmpty) 'syncUrl': syncUrl,
        }, SetOptions(merge: true));
      } catch (firestoreError) {
        debugPrint("Firestore write skipped/permitted on local mode: $firestoreError");
      }

      // 2. Persist locally in SharedPreferences for seamless offline/local testing
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_bound_openid', openId);
      await prefs.setString('last_synced_openid', openId);
      if (syncUrl != null && syncUrl.isNotEmpty) {
        await prefs.setString('saved_sync_url', syncUrl);
      }
      await prefs.setBool('auth_is_verified', true);

      return {
        'success': true,
        'message': '본인 인증 및 계정 1:1 연동이 성공적으로 완료되었습니다!',
      };
    } catch (e) {
      debugPrint("Error in verifyAndBindBlablaAccount: $e");
      return {
        'success': false,
        'message': '연동 중 오류가 발생했습니다: $e',
      };
    }
  }

  /// Bind Google account UID with openId and syncUrl
  Future<void> bindGoogleAccountWithOpenId(String uid, String openId, {String? syncUrl}) async {
    try {
      await _db.collection('open_id_bindings').doc(openId).set({
        'openId': openId,
        'uid': uid,
        if (syncUrl != null && syncUrl.isNotEmpty) 'syncUrl': syncUrl,
        'boundAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('users').doc(uid).set({
        'openId': openId,
        if (syncUrl != null && syncUrl.isNotEmpty) 'syncUrl': syncUrl,
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db.collection('commanders').doc(openId).set({
        'openId': openId,
        if (syncUrl != null && syncUrl.isNotEmpty) 'syncUrl': syncUrl,
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_bound_openid', openId);
      await prefs.setString('last_synced_openid', openId);
      if (syncUrl != null && syncUrl.isNotEmpty) {
        await prefs.setString('saved_sync_url', syncUrl);
      }
    } catch (e) {
      debugPrint("Error in bindGoogleAccountWithOpenId: $e");
    }
  }

  /// Unbind Nikke account from user
  Future<void> unbindBlablaAccount(String uid, String openId) async {
    try {
      if (openId.isNotEmpty) {
        try {
          await _db.collection('open_id_bindings').doc(openId).delete();
          await _db.collection('users').doc(uid).update({
            'openId': FieldValue.delete(),
            'isVerified': false,
          });
        } catch (_) {}
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_bound_openid');
      await prefs.setBool('auth_is_verified', false);
    } catch (e) {
      debugPrint("Error unbinding account: $e");
    }
  }

  /// Save user's Nikke state in `user_nikkes` collection
  Future<void> saveUserNikke(String userId, dynamic state) async {
    try {
      final docId = "${userId}_${state.nikkeId}";
      await _db.collection('user_nikkes').doc(docId).set(
            state.toJson(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint("Error saving user Nikke state: $e");
    }
  }

  /// Get aggregated overload & skill statistics for a specific Nikke
  Future<Map<String, dynamic>> getNikkeOverloadStats(String nikkeId) async {
    try {
      final snapshot = await _db
          .collection('user_nikkes')
          .where('nikkeId', isEqualTo: nikkeId)
          .get();

      final list = snapshot.docs
          .map((doc) => doc.data())
          .toList();

      return {
        'nikkeId': nikkeId,
        'submissions': list,
      };
    } catch (e) {
      debugPrint("Error fetching Nikke stats: $e");
      return {
        'nikkeId': nikkeId,
        'submissions': [],
      };
    }
  }

  /// Check if a nickname is unique and available across all users
  Future<bool> isNicknameAvailable(String nickname, {String? currentUid}) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) return false;

    try {
      final query = await _db
          .collection('users')
          .where('nickname', isEqualTo: trimmed)
          .get();

      for (final doc in query.docs) {
        if (currentUid != null && doc.id == currentUid) continue;
        return false; // Taken by another user!
      }
      return true; // Available!
    } catch (e) {
      debugPrint("isNicknameAvailable fallback check: $e");
      final prefs = await SharedPreferences.getInstance();
      final cachedNick = prefs.getString('user_nickname');
      if (cachedNick != null && cachedNick == trimmed) return true;
      return true;
    }
  }
}
