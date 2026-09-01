import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/achievement_badge.dart';

class AchievementService {
  static const _baseUrl = 'https://us-central1-nikke-mimir.cloudfunctions.net';

  Future<AchievementBadgeState> evaluate() async {
    final response = await _post('evaluateAchievementBadges');
    return AchievementBadgeState.fromJson(response);
  }

  Future<List<String>> updateDisplayedBadges(List<String> badgeIds) async {
    final response = await _post(
      'updateDisplayedBadges',
      body: {'badgeIds': badgeIds},
    );
    return (response['displayedBadgeIds'] as List? ?? const [])
        .map((value) => value.toString())
        .toList();
  }

  Future<Map<String, dynamic>> _post(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('로그인 인증 토큰을 발급할 수 없습니다.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/$functionName'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw StateError('서버 응답 형식이 올바르지 않습니다.');
    final result = Map<String, dynamic>.from(decoded);
    if (response.statusCode != 200 || result['success'] != true) {
      throw StateError(result['error']?.toString() ?? '뱃지 정보를 처리하지 못했습니다.');
    }
    return result;
  }
}
