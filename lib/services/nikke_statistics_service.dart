import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/nikke_statistics.dart';

class NikkeStatisticsService {
  static const _endpoint =
      'https://us-central1-nikke-mimir.cloudfunctions.net/getNikkeStatistics';
  static const _refreshEndpoint =
      'https://us-central1-nikke-mimir.cloudfunctions.net/refreshNikkeStatisticsNow';

  Future<NikkeStatistics> getStatistics({
    required String openId,
    required int nameCode,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('로그인 인증 토큰을 발급할 수 없습니다.');
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'openId': openId, 'nameCode': nameCode}),
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        response.statusCode != 200 ||
        decoded['success'] != true) {
      final message = decoded is Map ? decoded['error']?.toString() : null;
      throw StateError(message ?? '통계를 불러오지 못했습니다.');
    }
    return NikkeStatistics.fromJson(
      Map<String, dynamic>.from(decoded['data'] as Map),
    );
  }

  Future<void> refreshAllStatistics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('로그인 인증 토큰을 발급할 수 없습니다.');
    }

    final response = await http.post(
      Uri.parse(_refreshEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        response.statusCode != 200 ||
        decoded['success'] != true) {
      final message = decoded is Map ? decoded['error']?.toString() : null;
      throw StateError(message ?? '통계를 갱신하지 못했습니다.');
    }
  }
}
