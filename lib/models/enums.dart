// lib/models/enums.dart

// ignore_for_file: constant_identifier_names

// 니케 속성
enum ElementType {
  Iron, // 물리/철갑
  Water, // 수냉
  Electric, // 전격
  Fire, // 작열
  Wind, // 풍압
}

enum WeaponType {
  MG, // 머신건
  SG, // 샷건
  SMG, // SMG
  RL, // 런처
  AR, // 돌격소총
  SR, // 저격소총
}

enum Company {
  Elysion, // 엘리시온
  Missilis, // 샷건
  Tetra, // SMG
  Pilgrim, // 런처
  Abnormal, // 돌격소총
}

// 버스트 단계
enum BurstType {
  burst0,
  burst1,
  burst2,
  burst3,
}

// 특성 타입 (원하면 여기로 옮겨도 됨)
enum AbilityType {
  Heal,
  BurstCooldown,
  BurstReentry,
  AtkBoost,
  CritBoost,
  Shield,
  ReloadSpeed,
}

// 니케 등급
enum Rank {
  SSR,
  SR,
  R,
}

extension RankExt on Rank {
  String get label => switch (this) {
        Rank.SSR => 'SSR',
        Rank.SR => 'SR',
        Rank.R => 'R',
      };

  /// 정렬용 숫자 (값이 작을수록 위로 오게)
  int get sortValue => switch (this) {
        Rank.SSR => 0, // 제일 위
        Rank.SR => 1,
        Rank.R => 2,
      };
}
