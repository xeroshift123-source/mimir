import 'dart:convert';

class DeckCodeData {
  final String type; // 'solo' or 'union'
  final List<List<String?>> squads;
  final List<String>? elements;

  DeckCodeData({
    required this.type,
    required this.squads,
    this.elements,
  });
}

/// 유저용 덱 코드를 생성하고 파싱하는 유틸리티 클래스
class DeckCodeUtils {
  /// 덱 데이터를 Base64 URL-safe 코드 문자열로 인코딩합니다.
  static String encodeDeck({
    required String type,
    required List<List<String?>> squads,
    List<String>? elements,
  }) {
    try {
      final data = {
        'type': type,
        'squads': squads,
        if (elements != null) 'elements': elements,
      };
      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);
      return base64Url.encode(bytes);
    } catch (e) {
      return '';
    }
  }

  /// Base64 코드 문자열을 파싱하여 덱 배열로 복원합니다.
  /// 파싱 실패 시 null을 반환합니다.
  static DeckCodeData? decodeDeck(String code) {
    try {
      final String cleanCode = code.trim();
      if (cleanCode.isEmpty) return null;

      final bytes = base64Url.decode(cleanCode);
      final jsonString = utf8.decode(bytes);
      
      final dynamic decoded = jsonDecode(jsonString);
      
      // 구버전(단순 배열) 호환성 유지
      if (decoded is List) {
        final List<List<String?>> result = _parseSquads(decoded);
        return DeckCodeData(type: 'solo', squads: result);
      } 
      // 신규 버전(Map 객체)
      else if (decoded is Map<String, dynamic>) {
        final type = decoded['type'] as String? ?? 'solo';
        
        List<String>? elements;
        if (decoded['elements'] is List) {
          elements = (decoded['elements'] as List).map((e) => e?.toString() ?? '').toList();
        }

        final List<List<String?>> result = _parseSquads(decoded['squads'] as List? ?? []);
        
        return DeckCodeData(
          type: type,
          squads: result,
          elements: elements,
        );
      }
    } catch (e) {
      // 파싱 오류
    }
    return null;
  }

  static List<List<String?>> _parseSquads(List rawSquads) {
    final List<List<String?>> result = [];
    for (var squad in rawSquads) {
      if (squad is List) {
        final List<String?> parsedSquad = [];
        for (var item in squad) {
          if (item == null || item is String) {
            parsedSquad.add(item as String?);
          } else {
            parsedSquad.add(null);
          }
        }
        while (parsedSquad.length < 5) {
          parsedSquad.add(null);
        }
        result.add(parsedSquad.sublist(0, 5));
      }
    }
    return result;
  }
}
