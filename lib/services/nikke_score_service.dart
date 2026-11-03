import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../data/nikke_score_targets.dart';

class NikkeScoreResult {
  const NikkeScoreResult(
      {required this.score,
      required this.damage,
      required this.calcVersion,
      required this.sampleCount,
      this.topPercent,
      this.canRefreshStatistics = false,
      this.generatedAt,
      this.teamNames = const []});
  final double score;
  final int damage;
  final String calcVersion;
  final int sampleCount;
  final double? topPercent;
  final bool canRefreshStatistics;
  final DateTime? generatedAt;
  final List<String> teamNames;

  factory NikkeScoreResult.fromJson(Map<String, dynamic> json) {
    final score = json['score'];
    final damage = json['damage'];
    final top = json['topPercent'];
    final count = json['sampleCount'];
    final version = json['calcVersion'];
    if (score is! num ||
        !score.isFinite ||
        score < 0 ||
        damage is! int ||
        damage < 0 ||
        count is! int ||
        count < 0 ||
        version is! String ||
        version.isEmpty ||
        (top != null &&
            (top is! num || !top.isFinite || top < 0 || top > 100))) {
      throw const FormatException('스코어 응답 형식이 올바르지 않습니다.');
    }
    return NikkeScoreResult(
        score: score.toDouble(),
        damage: damage,
        calcVersion: version,
        sampleCount: count,
        topPercent: (top as num?)?.toDouble(),
        canRefreshStatistics: json['canRefreshStatistics'] == true,
        generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
        teamNames: json['team'] is List
            ? (json['team'] as List).whereType<String>().toList()
            : const []);
  }
}

class NikkeScoreException implements Exception {
  const NikkeScoreException(this.message, {this.retryAfterSeconds});
  final String message;
  final int? retryAfterSeconds;
  @override
  String toString() => message;
}

class StoredNikkeScores {
  StoredNikkeScores.fromJson(Map<String, dynamic> json)
      : status = json['status'] as String? ?? 'not_saved',
        results = Map<String, dynamic>.from(json['results'] as Map? ?? {}),
        canRefreshStatistics = json['canRefreshStatistics'] == true,
        elements = (json['elements'] as List? ?? [])
            .whereType<Map>()
            .map((item) => ElementScoreStatistic.fromJson(item))
            .toList();
  final bool canRefreshStatistics;
  final List<ElementScoreStatistic> elements;
  final String status;
  final Map<String, dynamic> results;

  NikkeScoreResult resultFor(String profileKey) {
    final item = results[profileKey];
    if (item is! Map) {
      throw NikkeScoreException(['pending', 'running'].contains(status)
          ? '동기화 후 스코어를 저장 중입니다. 잠시 후 프로필을 다시 열어 주세요.'
          : '저장된 스코어가 없습니다. 프로필을 동기화하면 계산 후 저장됩니다.');
    }
    if (item['status'] != 'complete') {
      throw NikkeScoreException(item['error']?.toString() ?? '저장된 스코어가 없습니다.');
    }
    return NikkeScoreResult.fromJson(Map<String, dynamic>.from(item));
  }
}

class ElementScoreStatistic {
  ElementScoreStatistic.fromJson(Map json)
      : key = json['key'] as String,
        name = json['name'] as String,
        score = (json['score'] as num?)?.toDouble(),
        average = (json['average'] as num?)?.toDouble(),
        topPercent = (json['topPercent'] as num?)?.toDouble(),
        sampleCount = (json['sampleCount'] as num?)?.toInt() ?? 0;
  final String key, name;
  final double? score, average, topPercent;
  final int sampleCount;
}

class NikkeScoreService {
  static Iterable<NikkeScoreProfile> profilesFor(int nameCode) =>
      nikkeScoreProfiles.values
          .where((profile) => profile.nameCode == nameCode);
  static bool supports(int nameCode) => profilesFor(nameCode).isNotEmpty;
  static const _endpoint =
      'https://us-central1-nikke-mimir.cloudfunctions.net/getNikkeScores';

  static Future<String?> _idToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const NikkeScoreException('로그인 후 조회해 주세요.');
    return user.getIdToken();
  }

  static Future<StoredNikkeScores> loadStoredScores(
      {required String openId,
      http.Client? client,
      Future<String?> Function()? readToken}) async {
    final token = await (readToken ?? _idToken)();
    if (token == null || token.isEmpty) {
      throw const NikkeScoreException('로그인 인증이 만료되었습니다. 다시 로그인해 주세요.');
    }
    late http.Response response;
    try {
      response = await (client?.post ?? http.post)(Uri.parse(_endpoint),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'openId': openId}))
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const NikkeScoreException('저장된 스코어 조회가 지연되고 있습니다. 프로필을 다시 열어 주세요.');
    } on http.ClientException {
      throw const NikkeScoreException('저장된 스코어를 불러오지 못했습니다. 프로필을 다시 열어 주세요.');
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const NikkeScoreException('저장된 스코어 응답을 확인할 수 없습니다.');
    }
    if (decoded is! Map<String, dynamic> ||
        response.statusCode != 200 ||
        decoded['success'] != true) {
      throw NikkeScoreException(
          decoded is Map
              ? decoded['error']?.toString() ?? '스코어를 불러오지 못했습니다.'
              : '스코어를 불러오지 못했습니다.',
          retryAfterSeconds: decoded is Map
              ? (decoded['retryAfterSeconds'] as num?)?.toInt()
              : null);
    }
    return StoredNikkeScores.fromJson(
        Map<String, dynamic>.from(decoded['data'] as Map));
  }
}
