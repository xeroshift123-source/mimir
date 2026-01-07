import 'enums.dart';

class Nikke {
  final String id; // 니케 고유 ID (내부 식별용)
  final String name; // 니케 이름
  final String imageUrl; // 이미지 주소
  final BurstType burst; // 버스트 단계 (burst0~3)
  final ElementType element; // 속성
  final WeaponType weaponType; // 무기 타입
  final Company company; // 소속 회사
  final int coolTime; // 버스트 쿨타임

  /// ✅ enum 제거 → 문자열 키워드 리스트로
  final List<String> ability;

  final Rank rank;
  int squadNum; // 배치된 스쿼드 번호 (0: 미배치, 1~5)

  Nikke({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.burst,
    required this.element,
    required this.weaponType,
    required this.company,
    required this.coolTime,
    required this.ability, // ✅ 여기
    this.squadNum = 0,
    required this.rank,
  });

  /// JSON → Nikke
  factory Nikke.fromJson(Map<String, dynamic> json) {
    // 1) burst: "1"/"2"/"3" or "burst1" → BurstType
    final burstStr = json['burst']?.toString() ?? '0';
    final burstNum = burstStr.startsWith('burst')
        ? int.tryParse(burstStr.replaceFirst('burst', '')) ?? 0
        : int.tryParse(burstStr) ?? 0;
    final burst = _burstFromNumber(burstNum);

    // 2) element / weaponType / company : 문자열 → enum
    final element = _enumFromString<ElementType>(
      ElementType.values,
      json['element']?.toString() ?? '',
      defaultValue: ElementType.Fire,
    );

    final weaponType = _enumFromString<WeaponType>(
      WeaponType.values,
      json['weaponType']?.toString() ?? '',
      defaultValue: WeaponType.MG,
    );

    final company = _enumFromString<Company>(
      Company.values,
      json['company']?.toString() ?? '',
      defaultValue: Company.Elysion,
    );

    // ✅ 3) ability : ["버스트 쿨타임 감소", "버쿨감", "막탄"] 같은 문자열 리스트
    final ability = (json['ability'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    return Nikke(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String,
      burst: burst,
      element: element,
      weaponType: weaponType,
      company: company,
      coolTime: json['coolTime'] as int? ?? 0,
      ability: ability,
      squadNum: json['squadNum'] as int? ?? 0,
      rank: Rank.values.byName(json['rank'] as String),
    );
  }

  /// Nikke → JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'burst': _burstToNumber(burst), // 0/1/2/3 숫자로 저장
      'element': element.name,
      'weaponType': weaponType.name,
      'company': company.name,

      // ✅ 문자열 리스트는 그대로 저장
      'ability': ability,

      'coolTime': coolTime,
      'squadNum': squadNum,
      'rank': rank.name, // ✅ enum은 name으로 저장하는 게 안전
    };
  }

  // ---------------------------------------------------------------------------
  // 내부 헬퍼
  // ---------------------------------------------------------------------------

  static BurstType _burstFromNumber(int num) {
    switch (num) {
      case 1:
        return BurstType.burst1;
      case 2:
        return BurstType.burst2;
      case 3:
        return BurstType.burst3;
      default:
        return BurstType.burst0;
    }
  }

  static int _burstToNumber(BurstType burst) {
    switch (burst) {
      case BurstType.burst0:
        return 0;
      case BurstType.burst1:
        return 1;
      case BurstType.burst2:
        return 2;
      case BurstType.burst3:
        return 3;
    }
  }

  static T _enumFromString<T extends Enum>(
    List<T> values,
    String name, {
    required T defaultValue,
  }) {
    if (name.isEmpty) return defaultValue;
    try {
      return values.firstWhere(
        (e) => e.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return defaultValue;
    }
  }
}
