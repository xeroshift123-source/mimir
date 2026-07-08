// lib/models/raid_info.dart

enum RaidType { solo, union }

class UnionBossInfo {
  final String element;
  final String name;
  final List<String>? keyword;

  const UnionBossInfo({
    required this.element,
    required this.name,
    this.keyword,
  });
}

class RaidInfo {
  final RaidType type;
  final String seasonName;
  final String period;
  final String imagePath;

  // Solo Raid specific
  final String? bossName;
  final String? bossElement;
  final String? weakness;

  // Union Raid specific
  final List<UnionBossInfo>? unionBosses;
  final List<String>? keyword;

  const RaidInfo({
    required this.type,
    required this.seasonName,
    required this.period,
    required this.imagePath,
    this.bossName,
    this.bossElement,
    this.weakness,
    this.unionBosses,
    this.keyword,
  });

  String get typeLabel {
    return switch (type) {
      RaidType.solo => '솔로 레이드',
      RaidType.union => '유니온 레이드',
    };
  }
}
