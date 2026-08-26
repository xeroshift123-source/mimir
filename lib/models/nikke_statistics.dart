class NikkeOverloadStatistic {
  const NikkeOverloadStatistic({
    required this.name,
    required this.userCount,
    required this.adoptionRate,
    required this.averageTotalPercent,
    required this.averageLineCount,
    required this.myTotalPercent,
    required this.myLineCount,
    required this.topPercent,
  });

  factory NikkeOverloadStatistic.fromJson(Map<String, dynamic> json) {
    return NikkeOverloadStatistic(
      name: json['name']?.toString() ?? '알 수 없는 옵션',
      userCount: (json['userCount'] as num?)?.toInt() ?? 0,
      adoptionRate: (json['adoptionRate'] as num?)?.toDouble() ?? 0,
      averageTotalPercent:
          (json['averageTotalPercent'] as num?)?.toDouble() ?? 0,
      averageLineCount: (json['averageLineCount'] as num?)?.toDouble() ?? 0,
      myTotalPercent: (json['myTotalPercent'] as num?)?.toDouble(),
      myLineCount: (json['myLineCount'] as num?)?.toInt() ?? 0,
      topPercent: (json['topPercent'] as num?)?.toDouble(),
    );
  }

  final String name;
  final int userCount;
  final double adoptionRate;
  final double averageTotalPercent;
  final double averageLineCount;
  final double? myTotalPercent;
  final int myLineCount;
  final double? topPercent;
}

class NikkeSkillPresetStatistic {
  const NikkeSkillPresetStatistic({
    required this.preset,
    required this.count,
    required this.ratio,
  });

  factory NikkeSkillPresetStatistic.fromJson(Map<String, dynamic> json) {
    return NikkeSkillPresetStatistic(
      preset: json['preset']?.toString() ?? '-/-/-',
      count: (json['count'] as num?)?.toInt() ?? 0,
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0,
    );
  }

  final String preset;
  final int count;
  final double ratio;
}

class NikkeEquipmentPresetStatistic {
  const NikkeEquipmentPresetStatistic({
    required this.preset,
    required this.count,
    required this.ratio,
  });

  factory NikkeEquipmentPresetStatistic.fromJson(Map<String, dynamic> json) {
    return NikkeEquipmentPresetStatistic(
      preset: json['preset']?.toString() ?? 'X/X/X/X',
      count: (json['count'] as num?)?.toInt() ?? 0,
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0,
    );
  }

  final String preset;
  final int count;
  final double ratio;
}

class NikkeStatistics {
  const NikkeStatistics({
    required this.server,
    required this.sampleCount,
    required this.minimumSample,
    required this.isSufficient,
    required this.freshnessDays,
    required this.generatedAt,
    required this.canRefreshStatistics,
    required this.mySkillPreset,
    required this.myEquipmentPreset,
    required this.overload,
    required this.skillPresets,
    required this.equipmentPresets,
  });

  factory NikkeStatistics.fromJson(Map<String, dynamic> json) {
    final overloadJson = json['overload'] as List<dynamic>? ?? const [];
    final skillJson = json['skillPresets'] as List<dynamic>? ?? const [];
    final equipmentJson =
        json['equipmentPresets'] as List<dynamic>? ?? const [];
    return NikkeStatistics(
      server: json['server']?.toString() ?? '알 수 없음',
      sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
      minimumSample: (json['minimumSample'] as num?)?.toInt() ?? 20,
      isSufficient: json['isSufficient'] == true,
      freshnessDays: (json['freshnessDays'] as num?)?.toInt() ?? 30,
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      canRefreshStatistics: json['canRefreshStatistics'] == true,
      mySkillPreset: json['mySkillPreset']?.toString() ?? '-/-/-',
      myEquipmentPreset: json['myEquipmentPreset']?.toString() ?? 'X/X/X/X',
      overload: overloadJson
          .whereType<Map>()
          .map((item) =>
              NikkeOverloadStatistic.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      skillPresets: skillJson
          .whereType<Map>()
          .map((item) => NikkeSkillPresetStatistic.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      equipmentPresets: equipmentJson
          .whereType<Map>()
          .map((item) => NikkeEquipmentPresetStatistic.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  final String server;
  final int sampleCount;
  final int minimumSample;
  final bool isSufficient;
  final int freshnessDays;
  final DateTime? generatedAt;
  final bool canRefreshStatistics;
  final String mySkillPreset;
  final String myEquipmentPreset;
  final List<NikkeOverloadStatistic> overload;
  final List<NikkeSkillPresetStatistic> skillPresets;
  final List<NikkeEquipmentPresetStatistic> equipmentPresets;
}
